use 5.010;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use PDL::Core::Dev;

my $package = ["util.pd", 'Util', 'Statistics::Descriptive::PDL::Util'];
my %hash = pdlpp_stdargs($package);
#my %hash;

#WriteMakefile( %hash );
use DDP;
p %hash;

my %params = (
    NAME             => 'Statistics::Descriptive::PDL',
    AUTHOR           => q{Shawn Laffan <shawnlaffan@gmail.com>},
    VERSION_FROM     => 'lib/Statistics/Descriptive/PDL.pm',
    ABSTRACT_FROM    => 'lib/Statistics/Descriptive/PDL.pm',
    LICENSE          => 'artistic_2',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.010,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
        'PDL::Core' => "2.008",
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
        'Statistics::Descriptive' => "3.06",
        'rlib' => "0",
        'Scalar::Util' => "0",
        "Devel::Symdump" => "0",
    },
    PREREQ_PM => {
        #  PDL:: versions should be able to go lower, but need to start somewhere
        "PDL"        => "2.012",
        "PDL::Stats" => "0.7",  #  0.6.5 had install issues
    },
    dist  => { PREOP    => '$(PERL) -MPDL::Core::Dev -e pdlpp_mkgen $(DISTVNAME)',
               COMPRESS => 'gzip -9f',
               SUFFIX   => 'gz', },
    clean => { FILES => 'Statistics-Descriptive-PDL-*' },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/shawnlaffan/Statistics-Descriptive-PDL',
            },
            bugtracker => {
                web => 'https://github.com/shawnlaffan/Statistics-Descriptive-PDL/issues/',
            },
        },
    },
);

my %no_merge = (NAME => 1, VERSION_FROM => 1, dist => 1);
foreach my $key (keys %params) {
    next if $no_merge{$key};
    if (0 && exists $hash{$key}) {
        say "XX $key";
        p $hash{$key};
        p $params{$key};
    }
    if (!exists $hash{$key}) {
        say "YY $key";
        p $hash{$key};
        p $params{$key};
    }
}

WriteMakefile(%params);

#p %params;

sub MY::postamble {pdlpp_postamble($package)};
