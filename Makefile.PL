use 5.006;
use Config;
use ExtUtils::MakeMaker;
use ExtUtils::Embed;

$Config{usemultiplicity}
    or die "You must build perl with -Dusemultiplicity.\n";

xsinit 'xsinit.c';

# Work around ActiveState's broken Config.pm when gcc is present

my @EUFC;

if (
    $INC{'ActivePerl/Config.pm'} 
    and $Config{ld} eq 'gcc'
    and $Config{ldflags} =~ /-libpath:/
) {
    @EUFC = ( 'ExtUtils::FakeConfig' => '0.08' );
    eval { require Config_m; 1; };
}

WriteMakefile(
    'DISTNAME'	   => 'PerlInterp',
    'NAME'	   => 'Perl',
    'VERSION_FROM' => 'Perl.pm',
    OBJECT         => 'Perl.o xsinit.o',
    clean          => { FILES => 'xsinit.*' },
    PREREQ_PM      => { 
        'Data::Dumper' => '2.101',
        'Test::More'   => '0.18',
        @EUFC,
    },
    dynamic_lib    => {
        # these ldopts are required at least on Cygwin, otherwise the
        # link can't find DynaLoader.a

        # the extra space works around a bug on mingw

        OTHERLDFLAGS => ldopts(1) . ' ',
    },
);

