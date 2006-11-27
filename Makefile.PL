use 5.006;
use Config;
use ExtUtils::MakeMaker;
use ExtUtils::Embed;

$Config{usemultiplicity}
    or die "You must build perl with -Dusemultiplicity.\n";

WriteMakefile(
    'DISTNAME'	   => 'PerlInterp',
    'NAME'	   => 'Perl',
    'VERSION_FROM' => 'Perl.pm',
    OBJECT         => 'Perl.o xsinit.o',
    clean          => { FILES => 'xsinit.*' },
    PREREQ_PM      => { 
        'Data::Dumper' => '2.101',
        'Test::More'   => '0.18',
    },
    dynamic_lib    => {
        OTHERLDFLAGS => ldopts(1) . ' ',
    },
);

xsinit "xsinit.c";
