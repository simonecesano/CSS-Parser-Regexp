use CSS::Parser::Regexp;
use Test::More;
use File::Find;

use strict;
use warnings;

my @files;

find(sub {
	 push @files, $File::Find::name if (-f && /\.css$/)
     }, 'css-tests');

my $p = CSS::Parser::Regexp->new;

for my $f (@files) {
    open my $fh, '<', $f or die "Can't open file $!";
    my $css = do { local $/; <$fh> };

    ok($p->parse($css), "parsing $f")
    # ok($p->stringify, "stringify $f")
}

done_testing(scalar @files);
