use strict;
use warnings;

use Test::More tests => 1;
use Perl;

my $P = Perl->new;
my $Q = Perl->new;

my $x = $P->eval(q{"foo"});
my $y = $Q->eval(q{"bar"});

is "$x $y", "foo bar", "multiple Perls";

# vi: set syn=perl :
