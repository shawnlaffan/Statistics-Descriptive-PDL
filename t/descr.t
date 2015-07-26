#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use rlib;
use lib 't/lib';
use Utils qw/is_between compare_hash_by_ranges/;

use Statistics::Descriptive::PDL;
use Statistics::Descriptive;

my $stats_class = 'Statistics::Descriptive::PDL';
my $tolerance = 1E-13;

use Devel::Symdump;
my $obj = Devel::Symdump->rnew(__PACKAGE__); 
my @subs = grep {$_ =~ 'main::test_'} $obj->functions();

exit main( @ARGV );


sub main {
    my @args  = @_;

    if (@args) {
        for my $name (@args) {
            die "No test method test_$name\n"
                if not my $func = (__PACKAGE__->can( 'test_' . $name ) || __PACKAGE__->can( $name ));
            $func->();
        }
        done_testing;
        return 0;
    }

    foreach my $sub (sort @subs) {
        no strict 'refs';
        $sub->();
    }
    
    done_testing;
    return 0;
}


sub test_same_as_stats_descr_full {
    my $object_pdl = $stats_class->new;
    my $object_sdf = Statistics::Descriptive::Full->new;

    my @data = (1..100, 5, 5);
    $object_pdl->add_data(@data);
    $object_sdf->add_data(@data);

    my @methods = qw /
        mean standard_deviation median
        skewness kurtosis
        min max
        sample_range
        harmonic_mean
        geometric_mean
        mode
    /;

    my $test_name
      = 'Methods match between Statistics::Descriptive::PDL and '
      . 'Statistics::Descriptive::Full';
    subtest $test_name => sub {
        foreach my $method (@methods) {
            my $got = $object_pdl->$method;
            my $exp = $object_sdf->$method;
            is_between (
                $got,
                $exp - $tolerance,
                $exp + $tolerance,
                $method,
            );
        }
    };
}


sub test_least_squares {
    local $TODO = 'least squares not implemented yet, and possibly won\'t be';
    ok (0, $TODO);
    return;

    # test #1
    my $stat = $stats_class->new();
    my @results = $stat->least_squares_fit();
    # TEST
    ok (!scalar(@results), "Least-squares results on a non-filled object are empty.");

    # test #2
    # data are y = 2*x - 1

    $stat->add_data( 1, 3, 5, 7 );
    @results = $stat->least_squares_fit();
    # TEST
    is_deeply (
        [@results[0..1]],
        [-1, 2],
        "least_squares_fit returns the correct result."
    );
}

sub test_harmonic_mean {
    # test #3
    # test error condition on harmonic mean : one element zero
    my $stat = $stats_class->new();
    $stat->add_data( 1.1, 2.9, 4.9, 0.0 );
    my $single_result = $stat->harmonic_mean();
    # TEST
    ok (!defined($single_result),
        "harmonic_mean is undefined if there's a 0 datum."
    );

    # test #4
    # test error condition on harmonic mean : sum of elements zero
    $stat = $stats_class->new();
    $stat->add_data( 1.0, -1.0 );
    $single_result = $stat->harmonic_mean();
    # TEST
    ok (!defined($single_result),
        "harmonic_mean is undefined if the sum of the reciprocals is zero."
    );

    # test #5
    # test error condition on harmonic mean : sum of elements near zero
    #$stat = $stats_class->new();
    #local $Statistics::Descriptive::PDL::Tolerance = 0.1;
    #$stat->add_data( 1.01, -1.0 );
    #$single_result = $stat->harmonic_mean();
    ## TEST
    #ok (! defined( $single_result ),
    #    "test error condition on harmonic mean : sum of elements near zero"
    #);

    # test #6
    # test normal function of harmonic mean
    $stat = $stats_class->new();
    $stat->add_data( 1,2,3 );
    $single_result = $stat->harmonic_mean();
    # TEST
    ok (scalar(abs( $single_result - 1.6363 ) < 0.001),
        "test normal function of harmonic mean",
    );
}

#  do we want this in S::D::PDL?
sub test_frequency_distribution {
    local $TODO = 'Frequency distribution not implemented yet';
    ok (0, $TODO);
    return;
    
    # test #7
    # test stringification of hash keys in frequency distribution
    my $stat = $stats_class->new();
    $stat->add_data(0.1,
                    0.15,
                    0.16,
                   1/3);
    my %f = $stat->frequency_distribution(2);

    # TEST
    compare_hash_by_ranges(
        \%f,
        [[0.216666,0.216667,3],[0.3333,0.3334,1]],
        "Test stringification of hash keys in frequency distribution",
    );

    # test #8
    ##Test memorization of last frequency distribution
    my %g = $stat->frequency_distribution();
    # TEST
    is_deeply(
        \%f,
        \%g,
        "memorization of last frequency distribution"
    );

    # test #9
    # test the frequency distribution with specified bins
    $stat = $stats_class->new();
    my @freq_bins=(20,40,60,80,100);
    $stat->add_data(23.92,
                    32.30,
                    15.27,
                    39.89,
                    8.96,
                    40.71,
                    16.20,
                    34.61,
                    27.98,
                    74.40);
    %f = $stat->frequency_distribution(\@freq_bins);

    # TEST
    is_deeply(
        \%f,
        {
            20 => 3,
            40 => 5,
            60 => 1,
            80 => 1,
            100 => 0,
        },
        "Test the frequency distribution with specified bins"
    );
    
     # test #9
    # test the frequency distribution with specified bins
    $stat = $stats_class->new();

    @freq_bins = (20,40,60,80,100);

    $stat->add_data(
        23.92,
        32.30,
        15.27,
        39.89,
        8.96,
        40.71,
        16.20,
        34.61,
        27.98,
        74.40,
    );

    my $f_d = $stat->frequency_distribution_ref(\@freq_bins);

    # TEST
    is_deeply(
        $f_d,
        {
            20 => 3,
            40 => 5,
            60 => 1,
            80 => 1,
            100 => 0,
        },
        "Test the frequency distribution returned as a scalar reference"
    );
}


#  here is where we deviate from S::D::F
sub test_percentiles {

    # test #10 and #11
    # Test the percentile function and caching
    my $stat = $stats_class->new();
    $stat->add_data(-5,-2,4,7,7,18);
    ##Check algorithm
    # TEST
    is ($stat->percentile(50),
        5.5,
        "percentile function and caching - 1",
    );
    # TEST
    is ($stat->percentile(25),
        -0.5,
        "percentile function and caching - 2",
    );
    $stat = $stats_class->new();
    $stat->add_data(0..100);
    ##Check algorithm
    # TEST
    is ($stat->percentile(50),
        50,
        "percentile function and caching - 50% of 0..100",
    );
    # TEST
    is ($stat->percentile(25),
        25,
        "percentile function and caching - 25% of 0..100",
    );
}

#  do we want this?
sub test_trimmed_mean {
    local $TODO = 'Not sure we want the trimmed mean';
    return;

    # tests #12 and #13
    # Check correct parsing of method parameters
    my $stat = $stats_class->new();
    $stat->add_data(1,2,3,4,5,6,7,8,9,10);
    # TEST
    is(
        $stat->trimmed_mean(0.1,0.1),
        $stat->trimmed_mean(0.1),
        "correct parsing of method parameters",
    );

    # TEST
    is ($stat->trimmed_mean(0.1,0),
        6,
        "correct parsing of method parameters - 2",
    );
}

#  relict from Stats::Descr - prob not needed
sub test_negative_variance {
    my $stat = $stats_class->new();

    $stat->add_data((0.001) x 6);

    # TEST
    is_between ($stat->variance(),
        0,
        0.00001,
        "Workaround to avoid rounding errors that yield negative variance."
    );

    # TEST
    is_between ($stat->standard_deviation(),
        0,
        0.00001,
        "Workaround to avoid rounding errors that yield negative std-dev."
    );
}

sub test_basics {
    my $stat = $stats_class->new();

    $stat->add_data(1, 2, 3, 5);

    # TEST
    is ($stat->count(),
        4,
        "There are 4 elements."
    );

    # TEST
    is ($stat->sum(),
        11,
        "The sum is 11",
    );

    # TEST
    is ($stat->min(),
        1,
        "The minimum is 1."
    );

    # TEST
    is ($stat->max(),
        5,
        "The maximum is 5."
    );
}


sub test_geometric_mean {
    # test #9
    # test the frequency distribution with specified bins
    my $stat = $stats_class->new();

    $stat->add_data(2, 4, 8);

    # TEST
    is_between(
        $stat->geometric_mean(),
        (4-1e-4),
        (4+1e-4),
        "Geometric Mean Test #1",
    )
}

sub test_skew_kurt {
    my $stat = $stats_class->new();
    my ($expected, $got);

    $stat->add_data(1 .. 9, 100);

    # TEST
    $expected = 3.11889574523909;
    $got = $stat->skewness();
    is_between ($got,
        $expected - 1E-13,
        $expected + 1E-13,
        "Skewness of $expected +/- 1E-13"
    );

    # TEST
    $expected = 9.79924471616366;
    $got = $stat->kurtosis();
    is_between ($got,
        $expected - 1E-13,
        $expected + 1E-13,
        "Kurtosis of $expected +/- 1E-13"
    );

    $stat->add_data(100 .. 110);

    #  now check that cached skew and kurt values are recalculated

    # TEST
    $expected = -0.306705104889384;
    $got = $stat->skewness();
    is_between ($got,
        $expected - 1E-13,
        $expected + 1E-13,
        "Skewness of $expected +/- 1E-13"
    );

    # TEST
    $expected = -2.09839497356215;
    $got = $stat->kurtosis();
    is_between ($got,
        $expected - 1E-13,
        $expected + 1E-13,
        "Kurtosis of $expected +/- 1E-13"
    );

    #  reset
    $stat = $stats_class->new();

    $stat->add_data(1,2);
    my $def;

    # TEST
    $def = defined $stat->skewness() ? 1 : 0;
    is ($def,
        0,
        'Skewness is undef for 2 samples'
    );

    $stat->add_data (1);

    # TEST
    $def = defined $stat->kurtosis() ? 1 : 0;
    is ($def,
        0,
        'Kurtosis is undef for 3 samples'
    );

}

#  remnant from S::D::F - not convinced we need it here
sub test_percentile_does_not_die {
    # This is a fix for:
    # https://rt.cpan.org/Ticket/Display.html?id=72495
    # Thanks to Robert Messer
    my $stat = $stats_class->new();

    my $ret = $stat->percentile(100);

    # TEST
    ok (!defined($ret), 'Returns undef and does not die.');
}



#  test stats when no data have been added
sub test_stats_when_no_data_added {
    my $stat = $stats_class->new();
    my ($result, $str);

    #  An accessor method for _permitted would be handy,
    #  or one to get all the stats methods
    my @methods = qw {
        mean sum variance standard_deviation
        min max sample_range
        skewness kurtosis median
        harmonic_mean geometric_mean
        mode sum
    };
    #  percentile 
    # frequency_distribution least_squares_fit
    #  mindex maxdex
    #  least_squares_fit is handled in an earlier test, so is actually a duplicate here

    #diag 'Results are undef when no data added';
    #  need to update next line when new methods are tested here
    # TEST:$method_count=18
    foreach my $method (sort @methods) {
        $result = $stat->$method;
        # TEST*$method_count
        ok (!defined ($result), "$method is undef when object has no data.");
    }

    #  quantile and trimmed_mean require valid args, so don't test in the method loop
    {
        local $TODO = 'quantile and trimmed_mean not working yet';
        my $method = 'quantile';
        $result = $stat->$method(1);
        # TEST
        ok (!defined ($result), "$method is undef when object has no data.");
    
        $method = 'trimmed_mean';
        $result = $stat->$method(0.1);
        # TEST
        ok (!defined ($result), "$method is undef when object has no data.");
    }
}

#  test SD when only one value added
sub test_sd_of_one_val_is_undef {
    my $stat = $stats_class->new();
    $stat->add_data( 1 );

    my $result = $stat->standard_deviation();
    # TEST
    is ($result, 0, "SD is zero when object has one record.");
}

# Test function returns undef in list context when no data have been added.
#  Avoids issues with callers in lists, e.g. method calls in hash construction.
#  e.g. my %h = (a => $x->median);
sub test_returns_undef_in_list_context {

    my $stat = $stats_class->new();

    # TEST
    is_deeply(
        [ $stat->median, ],
        [ undef ],
        "->median() Returns undef in list-context.",
    );

    # TEST
    is_deeply(
        [ $stat->standard_deviation, ],
        [ undef ],
        "->standard_deviation() Returns undef in list-context.",
    );
}

sub test_data_with_samples {
    local $TODO = 'Samples not handled yet';
    ok (0, $TODO);
    return;

    my $stats = $stats_class->new();

    $stats->add_data_with_samples([{1 => 10}, {2 => 20}, {3 => 30}, {4 => 40}, {5 => 50}]);

    # TEST
    is_deeply(
        $stats->_data(),
        [ 1, 2, 3, 4, 5 ],
        'add_data_with_samples: data set is correct',
    );

    # TEST
    is_deeply(
        $stats->_samples(),
        [ 10, 20, 30, 40, 50 ],
        'add_data_with_samples: samples are correct',
    );

}

#  Tests for mindex and maxdex on unsorted data,
#  including when new data are added which should not change the values
sub test_mindex_maxdex {
    local $TODO = 'mindex and maxdex not yet implemented, and might never be';
    return;

    my $stat1 = $stats_class->new();

    my @data1 = (20, 1 .. 3, 100, 1..5);
    my @data2 = (25, 30);

    my $e_maxdex = 4;
    my $e_mindex = 1;

    $stat1->add_data(@data1);     # initialise

    # TEST*2
    is ($stat1->mindex, $e_mindex, "initial mindex is correct");
    is ($stat1->maxdex, $e_maxdex, "initial maxdex is correct");

    # TEST*2
    $stat1->add_data(@data2);     #  add new data
    is ($stat1->mindex, $e_mindex, "mindex is correct after new data added");
    is ($stat1->maxdex, $e_maxdex, "maxdex is correct after new data added");

    # TEST*2
    {
        local $TODO = 'Sorting not implemented yet, so skip mindex/maxdex after median';
        $stat1->median;  #  trigger a sort
        $e_maxdex = scalar @data1 + scalar @data2 - 1;
        is ($stat1->mindex, 0, "mindex is correct after sorting");
        is ($stat1->maxdex, $e_maxdex, "maxdex is correct after sorting");
    }
}


#  what happens when we add new data?
#  Recycle the same data so mean, sd etc remain the same
sub test_add_new_data {
    my $stat1 = $stats_class->new();
    my $stat2 = $stats_class->new();

    my @data1 = (1 .. 9, 100);
    my @data2 = (100 .. 110);

    my (%obj1, %obj2);

    #  sample of methods
    my @methods = qw /mean standard_deviation count skewness kurtosis median/;

    $stat1->add_data(@data1);     # initialise
    foreach my $meth (@methods) { #  run some methods
        $stat1->$meth;
    }
    $stat1->add_data(@data2);     #  add new data
    foreach my $meth (@methods) { #  re-run some methods
        $obj1{$meth} = $stat1->$meth;
    }

    $stat2->add_data(@data1, @data2);  #  initialise with all data
    foreach my $meth (@methods) { #  run some methods
        $obj2{$meth} = $stat2->$meth;
    }

    # TEST
    is_deeply (\%obj2, \%obj1, 'stats consistent after adding new data');

}
