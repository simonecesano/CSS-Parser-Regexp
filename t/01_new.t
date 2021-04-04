use CSS::Parser::Regexp;
use Test::More tests => 1;

my $p = CSS::Parser::Regexp->new;

isa_ok($p, 'CSS::Parser::Regexp');

