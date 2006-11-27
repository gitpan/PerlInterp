use strict;
use warnings;

use Test::More tests => 7;
use Perl;

my @oldINC = @INC;
unshift @INC, 't';

{
    my $P = Perl->new;
    my $x = $P->_eval(q{ join "\0", @INC; });
    isnt substr($x, 0, 2), "t\0", 'Perl without INC gets standard @INC';
}

sub is_INC {
    my ($P, $test) = @_;

    my $getINC = <<'PERL';
        do {
            my %i;
            @i{@INC} = ();
            join "\0", sort keys %i;
        };
PERL
    
    my $x = $P->_eval($getINC);
    my $y = eval $getINC;

    is $x, $y, $test;
}

{
    my $P = Perl->new(INC =>);
    isa_ok $P, 'Perl', 'Perl->new accepts INC';

    is_INC $P,  'passing @INC into subperl';
}

{
    my $P = Perl->new(INC => ['t', @oldINC]);
    isa_ok $P, 'Perl', 'Perl->new accepts INC => []';

    is_INC $P, 'passing a custom @INC into subperl';
}

{
    my $P = Perl->new(INC => USE => ['Foo']);
    isa_ok $P, 'Perl', 'Perl->new accepts USE => []';

    my $x = $P->_eval(q{ Foo::foo; });
    is $x, 'foobar', 'Perl finds modules correctly';
}

# vi: set syn=perl :
