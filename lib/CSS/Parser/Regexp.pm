use strict;
use warnings;
package CSS::Parser::Regexp;

# ABSTRACT: Regexp-based CSS parser with at-rules support

use Text::Balanced qw/extract_bracketed extract_codeblock/;
use List::Util qw/reduce/;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = bless {}, ref $class || $class;
    return @_ ? $self->parse(@_) : $self;
}

sub parse {
    my $self = shift;
    $self->rules(process_rules(shift()));
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
    #---------------------------------------------------------
    # this collects all the nested at-rules
    # that precede the currect one by going back and out
    # until reaching level 1 - the first
    #---------------------------------------------------------
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
    # fix newlines
    $css =~ s/\r/\n/g;
    $css =~ s/\f/\n/g;
    # strip comments
    $css =~ s/\/\*(?:(?!\*\/).)*\*\/\n?//sg;
    return $css;
}

sub parse_style {
    my $t = shift;
    # parses string of the type "id : value"
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
    #------------------------------------------
    # separates the at-rule or the selector
    # from the content
    #------------------------------------------

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

    no warnings 'recursion';

    $css = strip_comments($css);

    return $cum unless $css =~ /\w/;

    my $type = block_type($css);

    my ($sel, $style, $rest) = separate($css);

    $rest = trim($rest);

    push @$cum, { sel => $sel, style => $style, rest => $rest, depth => $depth, type => $type };

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

    #-------------------------------------------------------------------------------
    # this needs to match all at-rules that have inner content that looks like rules
    # it is probably the most critical failure spot
    # it needs to be kept in synch with the list of nested rules at
    # https://developer.mozilla.org/en-US/docs/Web/CSS/At-rule
    #-------------------------------------------------------------------------------

    my $conditionals = qr/\@media\b|\@font\-feature|\@supports\b|\@document\b|\@.*keyframes/;

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
	#--------------------------------------
	# this could be removed for debugging
	# it just removes newlines
	#--------------------------------------
	s/\n/ /g;
	s/ +/ /g;
    }
    $t
}

sub block_type {
    my $t = shift;
    #---------------------------------------
    # identifies the block type
    #---------------------------------------
    for ($t) {
	# begins with @ is an at-rule
	/^\s*\@[\-\w]+/   && return 'at';
	# begins with something followed by a bracket
	# is a selector + style
	/\s*[^\{]+\s*(?<!\")\{/  && return 'sel';
    }
    return 'style';
}

#----------------------------------------------
# stringification functions
#----------------------------------------------

sub pointer_to_element {
    return reduce(sub { \($$a->{$b}) }, \shift(), @_);
}

sub rules_to_tree {
    # ----------------------------------------------------------------------
    # Transforms the rules into a tree - a hash-of-hashes, where the leaves,
    # that contain the style specification are arrayrefs - see t/05_tree.t.
    # This way definitions at different points of the CSS can be handled ok
    # ----------------------------------------------------------------------
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

sub sortkeys {
    #--------------------------------------------------------------------------------
    # sortkeys ensures that the rule tree keys are sorted as per css specs.
    # Regular at-rules go first.
    # The rest is sorted:
    # - normal selector rules first, in alphabetical order
    # - then at-rules, also alphabetically
    #--------------------------------------------------------------------------------
    my @keys = @_;

    # these are the at-rules that go in a specific order at the top
    my %h; @h{map { '@' . $_ } qw/charset import namespace font-face counter-style/} = (1..5);

    my $i = 0;

    #--------------------------------------------
    # schwartzian transform with forced sorting
    #--------------------------------------------
    @keys =
	map { $_->[2] }
	sort { $a->[0] <=> $b->[0] || $a->[2] cmp $b->[2] || $a->[1] <=> $b->[1] }
	map {
	    my $k = ref $_ ? (join ' ', @$_) : $_;
	    # first forced order at-rules then all selectors, then other at-rules
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

    my $indent_a = ' ' x ($l * 4);
    my $indent_b = ' ' x (($l + 1) * 4);

    my %repeat; @repeat{map { '@' . $_ } qw/font-face counter-style/} = qw/1 1/;
    my %single; @single{map { '@' . $_ } qw/namespace import charset/} = qw/1 1 1/;

    my $s;

    # regular at-rules: namespace import charset
    if ($single{$k}) {
	for my $r (@$v) {
	    $s .= "$k " . (join '', (map {
		$r->{$_} ? sprintf ("$indent_b%s:%s;", $_, $r->{$_})
		    : sprintf ("$indent_b%s;", $_)
		} sort keys %$r)) . "\n";
	}
    # at-rules that can be repeated, but should not be merged: font-face counter-style
    } elsif ($repeat{$k}) {
	for my $r (@$v) {
	    $s .= "$indent_a$k {";
	    $s = $s . "\n" . (join "\n", map { sprintf "$indent_b%s : %s;", $_, $r->{$_} } sort keys %$r);
	    $s .= "\n$indent_a}\n";
	}
    # all the rest
    } else {
	$s = "$indent_a$k {";
	for my $r (@$v) {
	    $s = $s . "\n" . (join "\n", map { sprintf "$indent_b%s : %s;", $_, $r->{$_} } sort keys %$r);
	}
	$s .= "\n$indent_a}\n";
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

	my $indent_a = ' ' x ($level * 4);

	for (sortkeys(keys %$tree)) {
	    my $ref = ref $tree->{$_};
	    if ($ref eq 'HASH') {
		print $fh "$indent_a$_ {";
		__SUB__->($tree->{$_}, $_, $level+1);
		print $fh "$indent_a}\n";
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
