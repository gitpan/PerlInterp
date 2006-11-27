use strict;
use warnings;

use Test::More tests => 9;
use Perl;

sub slurp {
    my ($file) = @_;
    local $/;
    open my $F, "<$file" or return $!;
    my $contents = <$F>;
    close $F;
    unlink $file;
    return $contents;
}

{
    my $P = Perl->new(ARGV => [-e => <<'PERL']);
open my $O, '>2run.out';
print $O 'Hello world!';
PERL

    $P->run;
    my $x = slurp '2run.out';
    is $x, 'Hello world!', '-e script';
}

{
    my $P = Perl->new(ARGV => [-le => <<'PERL']);
open my $O, '>2run.out';
print $O 'Hello world!';
PERL

    $P->run;
    my $x = slurp '2run.out';
    is $x, "Hello world!\n", '-le script';
}

{
    my $P = Perl->new(ARGV => [-e => <<'PERL']);
END {
    open my $O, '>2run.out';
    print $O 'Hello world!';
}
PERL

    $P->run;
    my $x = slurp '2run.out';
    is $x, 'Hello world!', '-e with END block';
}

{
    my $P = Perl->new(ARGV => [-e => <<'PERL']);
package Foo;

sub DESTROY {
    open my $O, '>2run.out';
    print $O 'DESTROYed';
}

package main;

my $f = bless [], 'Foo';
PERL

    $P->run;
    my $x = slurp '2run.out';
    is $x, 'DESTROYed', '-e with DESTROY';
}

{
    local *S_ERR;
    open S_ERR,  '>&STDERR';
    open STDERR, '>2run.err';
    
    my $P = Perl->new(ARGV => [-e => '%']);
    
    open STDERR, '>&S_ERR';
    close S_ERR;

    ok !defined($P), 'perl_parse died on invalid syntax';

    my $err = slurp '2run.err';
    like $err, qr/syntax error/, 'correct error for invalid syntax';
}

{
    local *S_ERR;
    open S_ERR,  '>&STDERR';
    open STDERR, '>2run.err';

    my $P = Perl->new(ARGV => [-e => '*$foo']);
    isa_ok $P, 'Perl', 'Perl object created on runtime error';

    my $st = $P->run;
    open STDERR, '>&S_ERR';
    close S_ERR;

    is $st, 255, 'perl_run died on runtime error';

    my $err = slurp '2run.err';
    like $err, qr/Can't use an undefined value as a symbol reference/,
        'correct runtime error';
}

# vi: set syn=perl :
