#
# Perl - Perl within Perl
#

package Perl;

use 5.005;
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

use base qw/DynaLoader/;

use Carp;
#use Data::Dump qw/dump/;
use Storable;
use MIME::Base64;

our $VERSION = "0.03"; 

our ($Deparse, $Eval);

bootstrap Perl;

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
        _add_argv $p 
          ref $args{INC}               ? 
          map { "-I$_" } @{$args{INC}} :
          map { ref $_ ? () : "-I$_" } @INC;
    }
    if($args{USE}) {
        _add_argv $p map { "-M$_" } @{$args{USE}};
    }

    _add_argv $p 
      $args{ARGV}    ?
      @{$args{ARGV}} :
      "-e0";

    $p->_parse and return;

    return $p;
}

=head2 $perl->run

This invokes L<perlembed/perl_run> on the interpreter, which will run the
program given on the command line in C<< Perl->new >>, if any. END blocks will
be run at the end of this, so if you install any you must make sure to
call this.

=head2 $perl->eval(q/EXPR/)

This returns the result of evaluating EXPR in the other interpreter. Results
are passed back using L<Storable|Storable>, and if anything is returned that
cannot be frozen an exception will be thrown. Any exceptions thrown will be 
caught in C<$@> and undef returned, as with normal eval. Exception objects
which cannot be frozen will be returned as C<"Unfreezable exception: ">
followed by their stringification.

The EXPR will be evaluated in the same context (list, scalar, void) as
eval is called in.

This will croak if L<Storable|Storable> cannot be required in the 
sub-interpreter.

=cut

sub eval {
    my $p = shift;
    my $s = shift;

    $p->_eval("eval { require Storable } and exists &Storable::freeze")
        or croak "can't load Storable into sub-perl";
    
    $s = defined wantarray              ?
         wantarray                      ?
	 "[ do { $s } ] "               :
	 "\\scalar do { $s }" :
	 "( do { $s }, undef )";
    $s = quotemeta $s;
    
    $Deparse = $Deparse ? "1" : "0";
    
    # This code MUST NOT throw any exceptions
    # We get segfaults if it does
    my $to_eval = <<PERL;
\$@ = undef;

# eval "" to catch syntax errors
my \$rv = eval "$s";

local \$Storable::Deparse = $Deparse;
# eval {} to catch unfreezable values
\$rv = eval { Storable::freeze(\$rv) } unless \$@ or not \$rv;

my \$x = \$@; 
\$@ and \$rv = eval { Storable::freeze(bless \\\$x, q/Perl::X/) };
if(\$@) {
    # strings can always be frozen
    \$x = "Unfreezable exception: \$x";
    \$rv = Storable::freeze(bless \\\$x, q/Perl::X/);
}
\$rv;
PERL
    $ENV{PERL_PERLPM_DEBUG} and warn $to_eval;
    my $rv = $p->_eval($to_eval);

    $rv or (defined wantarray ? (croak "Perl->eval failed") : return);
    $@ = undef;
    local $Storable::Eval = $Eval;
    $rv = eval { Storable::thaw $rv };
    
    if( UNIVERSAL::isa $rv, q/Perl::X/ ) {
        $$rv =~ s/ at \(eval \d+\) line \d+\.?\n$//; 
        eval { croak $$rv };
    }
    $@ ? return : return wantarray ? @$rv : $$rv;
}

=head1 FUNCTIONS

=head2 make_expr(EXPR)

This will construct an expression that evaluates to a deep clone of EXPR, 
suitable for interpolating into a
string to pass to C<< $perl->eval >>. This will croak if
L<MIME::Base64|MIME::Base64> cannot be required in the sub-perl.

EXPR will be evaluated in scalar context.

This will croak if EXPR cannot be frozen. If MIME::Base64
cannot be required in the sub-perl, the expression will die when evaluated.
(If Storable cannot be required, $perl->eval would have croaked already.)

The value of $Perl::Eval (see below) at the time of the call will be stored
inside the expression. If it is a coderef, it will be treated as though it is
false (for obvious reasons).

=cut

sub make_expr ($) {
    my $ex  = shift;

    local $Storable::Deparse = $Deparse;
    local @Storable::CARP_NOT = @Storable::CARP_NOT;
    push @Storable::CARP_NOT, __PACKAGE__;
    
    my $b64 = MIME::Base64::encode_base64(Storable::freeze(\$ex), "");

    my $eval = ($Eval and not ref $Eval) ? "1" : "0";
    return <<PERL
do {
    require MIME::Base64;
    local \$Storable::Eval = $eval;
    \${ Storable::thaw(MIME::Base64::decode_base64("$b64")) };
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

=head2 $Perl::Deparse, $Perl::Eval

These are used to set the values of $Storable::Deparse and $Storable::Eval 
(L<Storable/CODE REFERENCES>) while passing values to and from the
sub-interpreter.

=head1 ENVIRONMENT

=head2 PERL_PERLPM_DEBUG

If this variable is set in the environment, copious amount of debugging info
will be produced on STDERR. This is almost certainly of no use to anyone but
me.

=cut

exists $ENV{PERL_PERLPM_DEBUG} and _set_debug(1);

=head1 BUGS AND IRRITATIONS

Anything that can't be Stored, in particular filehandles, can't be passed 
between interpreters. It should be possible to pass data back and forth
using the L<threads::shared|threads::shared> mechanism rather than Storable,
but that's a whole new can of worms.

More tests are needed, particularly of threaded stuff. I don't know enough
about threads to know what needs testing.

=head1 AUTHOR

Gurusamy Sarathy <gsar@umich.edu>

Modified and updated for 5.8 by Ben Morrow <ben@morrow.me.uk>

=head1 COPYRIGHT

This program is distributed under the same terms as perl itself.

=cut

1;


