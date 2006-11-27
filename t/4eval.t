use strict;
use warnings;

use Perl;
use Test::More tests => 2;

my $P = Perl->new();

my $x = $P->eval(q/ { a => [ b => 2 ] }; /);
is_deeply $x, { a => [ b => 2 ] }, 'eval returns complex structures';

$x = $P->eval("$Perl::Expr{ [ a => { b => 3 } ] };");
is_deeply $x, [ a => { b => 3 } ], '$Perl::Expr';

# vi: set syn=perl :
