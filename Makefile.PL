use ExtUtils::MakeMaker;
use ExtUtils::Embed;

WriteMakefile(
    'DISTNAME'	   => 'PerlInterp',
    'NAME'	   => 'Perl',
    'VERSION_FROM' => 'Perl.pm',
    OBJECT         => 'Perl.o xsinit.o',
    clean          => { FILES => 'xsinit.*' },
    PREREQ_PM      => { Storable => '0.0', 'MIME::Base64' => '0.0' }
);

xsinit "xsinit.c";
