use strict;
use warnings;

use Test::More tests => 4;

BEGIN { use_ok 'Perl'; }

my $P = Perl->new;
isa_ok $P, 'Perl';

my $x = $P->_eval(q/'Hello world!'/);
is $x, 'Hello world!', '_eval returns correct string';

$x = $P->_eval(q/"null\\0null"/);
is $x, "null\0null", '_eval returns string with null';

# vi: set syn=perl :
