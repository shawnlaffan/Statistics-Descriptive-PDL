use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Statistics::Descriptive::PDL',
    AUTHOR           => q{Shawn Laffan <shawnlaffan@gmail.com>},
    VERSION_FROM     => 'lib/Statistics/Descriptive/PDL.pm',
    ABSTRACT_FROM    => 'lib/Statistics/Descriptive/PDL.pm',
    LICENSE          => 'artistic_2',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.010,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
        'Statistics::Descriptive' => "3.06",
    },
    PREREQ_PM => {
        #  PDL:: versions should be able to go lower, but need to start somewhere
        "PDL"        => "2.012",
        #"PDL::Stats" => "0.6.5_2",  #  need to make this a recommended module as 0.6.5 has install issues
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Statistics-Descriptive-PDL-*' },
);
