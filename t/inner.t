use Perl;
use Config;
$ENV{PERL5LIB} = join $Config{'path_sep'}, @INC; 
Perl::->new('t/base.t')->run;
