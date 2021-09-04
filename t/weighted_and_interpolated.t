use 5.010;
use strict;
use warnings;

use Test::More;

use rlib;
use lib 't/lib';


use Statistics::Descriptive::PDL;
use Statistics::Descriptive::PDL::SampleWeighted;

#use PDL::Lite;
#use PDL::NiceSlice;
#use PDL::Stats;
#eval 'use PDL::Stats';
#if ($@) {
#    plan skip_all => 'PDL::Stats not installed';
#}

use Scalar::Util qw /blessed/;


my $stats_class     = 'Statistics::Descriptive::PDL';
#my $stats_class_wtd = 'Statistics::Descriptive::PDL';
my $stats_class_wtd = 'Statistics::Descriptive::PDL::SampleWeighted';
my $tolerance = 1E-10;

#use Devel::Symdump;
#my $obj = Devel::Symdump->rnew(__PACKAGE__); 
#my @xsubs = sort grep {$_ =~ /pdl/i} $obj->functions();
#print join "\n", @xsubs;


test_wikipedia_percentile_example();
test_equal_weights();

done_testing();


sub test_wikipedia_percentile_example {
    my @data = (15, 20, 35, 40, 50);
    my @wts  = (1) x @data;
    my $unweighted = $stats_class->new;
    my $weighted   = $stats_class_wtd->new;
    $unweighted->add_data(\@data);
    $weighted->add_data(\@data, \@wts);

    is $unweighted->percentile(40), 29, 'interpolated pctl 40, unweighted';
    is $weighted->percentile(40),   29, 'interpolated pctl 40, weighted';
    is $weighted->percentile(50), $weighted->median, 'median same as 50th percentile';
    is $weighted->percentile(50), $unweighted->median, 'weighted and unweighted median';

    $weighted->add_data(\@data, \@wts);
    $unweighted->add_data(\@data);
    is $weighted->percentile(40), 29,                  'interpolated pctl 75, weighted, after doubling data' . join ' ', @data;
    is $weighted->percentile(50), $weighted->median,   "median same as 50th percentile, " . join ' ', @data;
    is $weighted->percentile(50), $unweighted->median, 'weighted and unweighted median';

    #  data from R
    my %exp = (
        20 => 19, 30 => 20, 40 => 29,
        50 => 35, 60 => 37, 70 => 40,
        80 => 42, 90 => 50,
        21 => 19.45,
    );

    for my $p (sort {$a <=> $b} keys %exp) {
        is $unweighted->percentile($p), $exp{$p}, "interpolated pctl $p, unweighted, doubled data";
        is $weighted->percentile($p),   $exp{$p}, "interpolated pctl $p, weighted, doubled data";
    
        #diag $p . ' ' . $weighted->percentile($p);
    }

#diag $weighted->median;
#diag $weighted->_get_weights_piddle;
#diag $weighted->_get_piddle;
#diag $unweighted->_get_piddle;
#diag $unweighted->median;

    @data = (1..4);
    $unweighted = $stats_class->new;
    $weighted   = $stats_class_wtd->new;
    $unweighted->add_data(\@data);
    $weighted->add_data(\@data, [(1) x scalar @data]);

    is ($unweighted->percentile(75), 3.25, 'interpolated pctl 75 of 1..4, unweighted');
    is ($weighted->percentile(75),   3.25, 'interpolated pctl 75 of 1..4, weighted');
    
    is $weighted->percentile(50), $weighted->median, 'median same as 50th percentile';

    @data = (15, 20, 25, 30, 35, 40);
    $unweighted = $stats_class->new;
    $weighted   = $stats_class_wtd->new;
    $unweighted->add_data(\@data);
    $weighted->add_data(\@data, [(1) x scalar @data]);

    is ($unweighted->percentile(75), 33.75, 'interpolated pctl 75, unweighted');
    is ($weighted->percentile(75),   33.75, 'interpolated pctl 75, weighted');
    is $weighted->percentile(50), 27.5, '50th percentile';
    is $weighted->percentile(50), $weighted->median, 'median same as 50th percentile';

}

sub test_equal_weights {
    my $unweighted = $stats_class->new;
    my $weighted   = $stats_class_wtd->new;
    #  "well behaved" data so median is not interpolated
    my @data = (1..100);
    $unweighted->add_data(\@data);
    $weighted->add_data(\@data, [(1) x scalar @data]);

    my @methods = qw /
        mean
        standard_deviation
        skewness
        kurtosis
        min
        max
        median
        percentile
    /;

    my %method_remap = (
        #mean     => 'avg',
        #skewness => 'skew',
        #kurtosis => 'kurt',
        #standard_deviation => 'standard_deviation',
        #median     => 'median_interpolated',
        #percentile => 'percentile_interpolated',
    );
    my %method_args = (
        percentile => [91.5],
        #median     => [50],
    );

    my $test_name
      = "Methods match between $stats_class and "
      . "$stats_class_wtd when weights are all 1, "
      . "and using interpolation for percentiles";
    subtest $test_name => sub {
        foreach my $method (@methods) {
            #diag "$method\n";
            my $wtd_method = $method_remap{$method} // $method;
            my $args_to_pass = $method_args{$method};

            #  allow for precision differences
            my $got = $weighted->$wtd_method (@$args_to_pass);
            my $exp = $unweighted->$method (@$args_to_pass);

            ok (
                abs ($got - $exp) < $tolerance,
                "$method got $got, expected $exp",
            );
        }
    };

}


1;
