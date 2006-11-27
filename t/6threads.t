use strict;
use warnings;

use Config;

BEGIN {
    if ($] >= 5.008 and $Config{useithreads}) {
        require threads;
        import threads;
        
        require Test::More;
        import  Test::More tests => 7;
    }
    else {
        print "1..0 # skip: no threads.pm\n";
        exit 0;
    }
}

use Perl;

{
    my $y = async {
        my $x = Perl->new->eval('"hello"');
        
        is $x, 'hello', 'Perl inside async';

        return "$x world";
    }->join;

    is $y, 'hello world', 'got back to the main thread';
}

{
    my $P = eval { Perl->new(USE => ['threads']) };
    isa_ok $P, 'Perl', 'threaded Perl';
}
    
{
    my $P = Perl->new(USE => ['threads']);
    $P->run;
    my $x = $P->eval(<<'PERL');
        my $y = async {
            return 'foo';
        }->join;

        defined $y or warn "async failed: $@";
        "$y bar";
PERL

    defined $x or warn "eval failed: $@: " . $P->eval('$@');
    is $x, 'foo bar', 'async inside Perl';
}
{
    my $y = async {
        my $x = Perl->new(USE => ['threads'])->eval(q{
            my $x = async {
                return 'one';
            }->join;

            "$x two";
        });

        defined $x or warn "# eval failed: $@";
        
        is $x, 'one two', 'async inside Perl';

        return "$x three";
    }->join;

    defined $y or warn "# async failed: $@";

    is $y, 'one two three', 'async inside Perl inside async';
}

{
    my $T = async {
        my $x = Perl->new->eval(q{
            "foo";
        });
        sleep 1;
        return "$x bar";
    }

    my $y = Perl->new->eval(q{
        "baz";
    });

    my $z = $T->join;
    is "$z $y", "foo bar baz", 'Perls in two threads';
}

# vi: set syn=perl :

# vi:set syn=perl :
