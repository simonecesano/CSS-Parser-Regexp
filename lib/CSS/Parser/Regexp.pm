use strict;
use warnings;
package CSS::Parser::Regexp;

# ABSTRACT: Regexp-based CSS parser with at-rules support

use Text::Balanced qw/extract_bracketed extract_codeblock/;
use List::Util;

use strict;
use warnings;

# use Mojo::Util qw/dumper/;

sub new {
    my $class = shift;
    my $self  = bless {}, ref $class || $class;
    return @_ ? $self->parse(@_) : $self;
}

sub parse {
    my $self = shift;
    $self->rules(process_rules(@_));
    return $self;
}

sub rules {
    my $self = shift;
    if (@_) { $self->{rules} = shift }
    return $self->{rules}
}

sub stringify {
    my $self = shift;
    my $h = $self->to_tree;
    return stringify_tree($h);
}

sub to_tree {
    my $self = shift;
    my $r = $self->rules;
    my $h = rules_to_tree($r);
    return $h;
}

#------------------------------
# subs from here on
#------------------------------
no warnings qw/uninitialized/;

sub process_ats {
    my $idx = shift;
    my @snippets = @_;

    my $level = $snippets[$idx]->{depth};

    return [] if $level == 1;
    return [] if $snippets[$idx]->{type} ne 'sel';

    my $ats;
    for (reverse 0..($idx-1)) {
	next if $snippets[$_]->{depth} >= $level;
	next if $snippets[$_]->{type} ne 'at';
	next if $ats->{$snippets[$_]->{depth}};

	$ats->{$snippets[$_]->{depth}} = $snippets[$_]->{sel};
	last if $snippets[$_]->{depth} == 1;
    }
    return [ map { $ats->{$_} } sort { $a <=> $b } keys %$ats ];
}

sub strip_comments {
    my $css = shift;
    $css =~ s/\r/\n/g;
    $css =~ s/\f/\n/g;
    $css =~ s/\/\*(?:(?!\*\/).)*\*\/\n?//sg;
    return $css;
}

sub parse_style {
    my $t = shift;

    for ($t) {
	s/\s*\{\s*//g;
	s/\s*\}\s*//g;
    }
    return { map {
	my ($k, $v) = split /\s*\:\s*/, $_;
	$v =~ s/\n/ /g;
	$v =~ s/\s+/ /g;
	($k, $v);
    } split /\s*\;\s*/, $t }
}


sub separate {
    my $css = shift;
    my ($sel, $rest) = $css =~ /^\s*([^\{\;]+)\s*(.+)/ms;

    $sel =~ s/\n/ /g;
    $sel = trim($sel);

    if ($sel =~ /\@(charset|import|namespace)/) {
	my ($sel, $style) = split /\s+/, $sel, 2;
	$style = strip_brackets($style);
	$rest =~ s/^\s*;//;
	return $sel, $style, $rest;
    } else {
	my ($style, $rest) = extract_bracketed($rest, '{}');
	$style = strip_brackets($style);
	return $sel, $style, $rest;
    }
}

sub pre_process_rules {
    my $css = shift;
    my $cum = shift || [];
    my $depth = shift || 1;

    $css = strip_comments($css);

    return $cum unless $css =~ /\w/;

    my $type = block_type($css);

    my ($sel, $style, $rest) = separate($css);

    $rest = trim($rest);

    push @$cum, { sel => $sel, style => $style, rest => $rest, depth => $depth, type => $type };
    # [ $sel, $style, $rest, $depth, $type ];

    # print dumper $cum if $CSS::Parser::Regexp::DEBUG;

    $type = block_type($style);

    unless ($type eq 'style') {
	pre_process_rules($style, $cum, $depth + 1);
    } else {
	$cum->[-1]->{style} = parse_style($style);
    }
    pre_process_rules($rest, $cum, $depth);

    return $cum;
}

sub post_process_rules {
    my @rules = @{shift()};
    my $i;

    my $conditionals = qr/\@media\b|\@supports\b|\@document\b/;

    for (@rules) {
	$_->{seq} = $i++;
	$_->{at} = process_ats($_->{seq}, @rules);
	delete $_->{rest};
    }

    @rules = grep {
	$_->{sel} !~ $conditionals;
    } @rules;
    return \@rules;
}

sub process_rules {
    my $rules = pre_process_rules(shift());
    return post_process_rules($rules);
}

sub trim {
    my $t = shift;
    for ($t) {
	s/^\s+//;
	s/\s+$//;
    }
    $t;
}

sub strip_brackets {
    my $t = shift;
    for ($t) {
	s/^\s*\{\s*//;
	s/\s*\}\s*$//;
	s/\n/ /g;
	s/ +/ /g;
    }
    $t
}

sub block_type {
    my $t = shift;

    for ($t) {
	/^\s*\@\w+/   && return 'at';
	/\s*[^\{]+\s*(?<!\")\{/  && return 'sel';
    }
    return 'style';
}

#----------------------------------------------
# stringification functions
#----------------------------------------------

sub pointer_to_element {
  return List::Util::reduce(sub { \($$a->{$b}) }, \shift, @_);
}

sub rules_to_tree {
    my $rules = shift;

    my $h;
    for (@$rules) {
	my $k = [ @{$_->{at}}, $_->{sel} ];
	my $scalar_ref = pointer_to_element($h, @{$_->{at}}, $_->{sel});
	$$scalar_ref ||= [];
	push @{$$scalar_ref}, $_->{style}
    }
    return $h;
}

use Mojo::Util qw/dumper/;

sub sortkeys {
    my @keys = @_;

    my %h; @h{map { '@' . $_ } qw/charset import namespace font-face counter-style/} = (1..5);

    my $i = 0;

    @keys =
	map {
	    $_->[2]
	}
	sort {
	    $a->[0] <=> $b->[0] || $a->[2] cmp $b->[2]
	}
	map {
	    my $k = ref $_ ? (join ' ', @$_) : $_;
	    my $n = $h{$k =~ s/\s.+//r} || ($k =~ /^\@/ ? (6 + scalar @keys + $i) : (6 + $i));
	    my $r = [$n, $i, $_ ];
	    $i++;
	    $r;
	} sort @keys;

}


sub stringify_rule {
    my $k = shift;
    my $v = shift;
    my $l = shift;

    my $indenta = ' ' x ($l * 4);
    my $indentb = ' ' x (($l + 1) * 4);

    my %repeat; @repeat{map { '@' . $_ } qw/font-face counter-style/} = qw/1 1/;
    my %single; @single{map { '@' . $_ } qw/namespace import charset/} = qw/1 1 1/;

    my $s;

    if ($single{$k}) {
	for my $r (@$v) {
	    $s .= "$k " . (join '', (map {
		$r->{$_} ?
		    sprintf ("$indentb%s:%s;", $_, $r->{$_})
		    :
		    sprintf ("$indentb%s;", $_)
		} sort keys %$r)) . "\n";
	}
    } elsif ($repeat{$k}) {
	for my $r (@$v) {
	    $s .= "$indenta$k {";
	    $s = $s . "\n" . (join "\n", map { sprintf "$indentb%s : %s;", $_, $r->{$_} } sort keys %$r);
	    $s .= "\n$indenta}\n";
	}
    } else {
	$s = "$indenta$k {";
	for my $r (@$v) {
	    $s = $s . "\n" . (join "\n", map { sprintf "$indentb%s : %s;", $_, $r->{$_} } sort keys %$r);
	}
	$s .= "\n$indenta}\n";
    }
    return $s;
}

use feature 'current_sub';

sub stringify_tree {
    my $tree = shift;
    my $compact = shift;
    my $output;

    #-------------------------------------------------------
    # see https://perldoc.perl.org/functions/open
    # open FILEHANDLE,MODE,REFERENCE
    #-------------------------------------------------------
    open my $fh, '>', \$output or die "Can't open variable: $!";

    local $\ = "\n";
    my $indent_factor = 4;

    my $recurse = sub {
	my $tree = shift;
	my $key = shift;
	my $level = shift || 0;

	my $indenta = ' ' x ($level * 4);

	for (sortkeys(keys %$tree)) {
	    my $ref = ref $tree->{$_};
	    if ($ref eq 'HASH') {
		print $fh "$indenta$_ {";
		__SUB__->($tree->{$_}, $_, $level+1);
		print $fh "$indenta}\n";
	    } elsif ($ref eq 'ARRAY') {
		print $fh stringify_rule( $_ => $tree->{$_}, $level);
	    } else {
		# print STDERR 'WTF';
	    }
	}
    };
    $recurse->($tree);

    if ($compact) { for ($output) { s/\n/ /g; s/ +/ /g } }
    return $output;
}

1;
