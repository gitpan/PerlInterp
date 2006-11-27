#
# Perl - Perl within Perl
#

package Perl;

use 5.006;
use warnings;
use strict;

=head1 NAME

Perl - embed a perl interpreter in a Perl program

=head1 SYNOPSIS

    use Perl;

    my $p = Perl->new;
    print $p->eval(q/"Hello" . " " . "world" . "\n"/);

=head1 DESCRIPTION

A C<Perl> object represents a separate perl interpreter that you can 
manipulate from within Perl. This allows you to run other scripts without
affecting your current interpreter, and then examine the results.

=head1 METHODS

=cut

BEGIN {
    require DynaLoader;
    our @ISA = 'DynaLoader';

    our $VERSION = "0.04"; 
    bootstrap Perl;

    if ($ENV{PERL_PERLPM_DEBUG}) {
        _set_debug(1);
        *DEBUG = sub () { 1 };
    }
    else {
        *DEBUG = sub () { 0 };
    }
}

use Carp;
use Data::Dumper;

our ($Deparse, $Eval);

=head2 Perl->new(PARAMS) 

This creates and initialises a new perl interpreter, and returns an object 
through which you can manipulate it. Paramaters are

=over 4

=item ARGV => I<ARRAYREF>

This sets the arguments for the perl interpreter, as passed to 
L<perlembed/perl_parse>. An initial argv[0] of C<"perl"> will be added
automatically, so don't try and include one. If no arguments are passed,
a single argument of C<-e0> will be used.

=item USE => I<ARRAYREF>

This will add appropriate C<-M> arguments to the argv of the new
interpreter. These will be added B<before> any args given with C<ARGV>.

=item INC I<[>=> I<ARRAYREF]>

This will pass appropriate C<-I> arguments to the interpreter, before those
from either C<ARGV> or C<USE>. If the
I<C<ARRAYREF>> is not specified, it will pass in the current C<@INC>, omitting
entries that are references.

=back

If the creation fails, it returns C<undef>.

=cut

sub new {
    my $c = shift;
    my $p = $c->_new or return;

    my %args;
    while(@_) {
        my $k = shift;
        my $v = ref $_[0] ? shift : undef;
        $args{$k} = $v;
    }

    if(exists $args{INC}) {
        $p->_add_argv( 
            ref $args{INC}               ? 
            map { "-I$_" } @{$args{INC}} :
            map { ref $_ ? () : "-I$_" } @INC
        );
    }
    if($args{USE}) {
        $p->_add_argv(map { "-M$_" } @{$args{USE}});
    }

    $p->_add_argv(
        $args{ARGV}    ?
        @{$args{ARGV}} :
        "-e0"
    );

    $p->_parse and return;

    return $p;
}

=head2 $perl->run

This invokes L<perlembed/perl_run> on the interpreter, which will run the
program given on the command line in C<< Perl->new >>, if any. END blocks will
be run at the end of this, so if you install any you must make sure to
call this.

=head2 $perl->_eval(q/EXPR/)

This C<eval>s EXPR in the other interpreter, and returns the string
value of the result.

=head2 $perl->eval(q/EXPR/)

This returns the result of evaluating EXPR in the other interpreter.
Results are passed back using L<Data::Dumper|Data::Dumper>, and if
anything is returned that cannot be frozen an exception will be thrown.
Any exceptions thrown will be caught in C<$@> and undef returned, as
with normal eval.

The EXPR will be evaluated in the same context (list, scalar, void) as
eval is called in.

This will croak if L<Data::Dumper|Data::Dumper> cannot be required in the 
sub-interpreter.

Note that you may wish to use _eval instead for more control over the
other interpreter.

=cut

our $V;

sub eval {
    my $p = shift;
    my $s = shift;

    $p->_eval(q{
        local $@;
        $Perl::DD or eval {
            require Data::Dumper;
            $Perl::DD = Data::Dumper->new([]);
        }; 
    }) or croak "can't load Data::Dumper into sub-perl";
    DEBUG and warn "sub-perl's D:D is v" . $p->_eval('$Perl::DD->VERSION');
    
    $s = defined wantarray              ?
         wantarray                      ?
	 "[ do { $s } ] "               :
	 "\\scalar do { $s }" :
	 "( do { $s }, undef )";
    $s = quotemeta $s;
    
    $Deparse = $Deparse ? "1" : "0";
    
    # This code MUST NOT throw any exceptions
    # We get segfaults if it does
    my $to_eval = q{
        do {
            my $expr = "#EXPR#";
            #DEBUG# and warn "sub-perl: got q{$expr} to eval"; #"
            
            $rv = eval $expr;
            #DEBUG# and warn "sub-perl: eval returned q{$rv}";
            
            if (my $X = $@) {
                #DEBUG# and warn "sub-perl: eval failed: $X";
                $Perl::DD->Values([$X]);
                $Perl::DD->Names (['Perl::X']);
            }
            else {
                $Perl::DD->Values([$rv]);
                $Perl::DD->Names(['Perl::V']);
            }

            $Perl::DD->Purity(1);
            $Perl::DD->Useqq(1);
            $Perl::DD->Indent(0);
            $Perl::DD->Deparse(#DEPARSE#)
                if $Perl::DD->can('Deparse');

            $Perl::DD->Dump;
        }
    };

    for ($to_eval) {
        s/#DEPARSE#/$Deparse/g;
        s/#DEBUG#/DEBUG/eg;
        s/#EXPR#/$s/g;
    }
    DEBUG and warn "main-perl: about to send q{$to_eval}";
    
    my $rv = $p->_eval($to_eval);

    $rv or croak "Perl->eval failed: $@"; 
    DEBUG and warn "main-perl: got q{$rv}";
    {
        local ($Perl::V, $Perl::X);
        {
            local $@;
            eval $rv;
            $@ and $Perl::X = $@;
        }
        $rv = $Perl::V;
        $@  = $Perl::X;
    }
    
    $@ and return;
    return 
        defined wantarray
            ? wantarray ? @$rv : $$rv
            : ();
}

=head1 FUNCTIONS

=head2 make_expr(EXPR)

This will construct an expression that evaluates to a deep clone of
EXPR, suitable for interpolating into a string to pass to C<<
$perl->eval >>.

EXPR will be evaluated in scalar context.

=cut

sub make_expr ($) {
    my $ex  = shift;

    my $DD = Data::Dumper->new([$ex], ['$Perl::V']);
    $DD->Purity(1)->Useqq(1)->Indent(0);
    $DD->can('Deparse') and $DD->Deparse($Deparse);
    my $dump = $DD->Dump;

    return <<PERL
do {
    local \$Perl::V;
    $dump;
    \$Perl::V;
}
PERL
}

sub import {
    shift;
    for (@_) {
    	no strict 'refs';
    	$_ eq 'make_expr'             ?
	*{caller() . "::$_"} = \&{$_} :
	croak "$_ isn't exported by " . __PACKAGE__;
    }
}

{{

package Perl::Expr;

sub TIEHASH {
    return bless \(my $o), shift;
}

sub FETCH ($$) {
    shift;
    return Perl::make_expr(shift);
}

{
    no strict 'refs';
    *{$_} = sub { return } for qw/STORE DELETE CLEAR FIRSTKEY NEXTKEY/;
}

sub EXISTS { return 1 };

}}

=head1 PUBLIC VARIABLES

=head2 %Perl::Expr

This is a tied hash which returns the result of calling Perl::make_expr on
the given key: it makes it easier to interpolate into strings.

=cut

tie our %Expr, 'Perl::Expr';

=head2 $Perl::Deparse

This is used to determine whether or not Data::Dumper should attempt to
deparse CODE refs. Note that you need a new enough version of
Data::Dumper for this to have any effect.

=head1 ENVIRONMENT

=head2 PERL_PERLPM_DEBUG

If this variable is set in the environment, copious amount of debugging info
will be produced on STDERR. This is almost certainly of no use to anyone but
me.

=head1 BUGS AND IRRITATIONS

Anything that can't be Dumped, in particular filehandles, can't be passed 
between interpreters.

There are crashes in t/6threads.t with both AS Perl and MinGW perl. I
don't fully understand why they occur, but I B<suspect> a bug in perl.

=head1 AUTHOR

Gurusamy Sarathy <gsar@umich.edu>

Modified and updated for 5.8 by Ben Morrow <ben@morrow.me.uk>

=head1 COPYRIGHT

This program is distributed under the same terms as perl itself.

=cut

1;


