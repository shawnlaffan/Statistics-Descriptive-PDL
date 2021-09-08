use 5.010;
use strict;
use warnings;

use Benchmark qw/cmpthese/;

use rlib '../lib';
use Statistics::Descriptive::PDL::SampleWeighted;
use Statistics::Descriptive;

use constant FEEDBACK => 0;


my $n_iters   = 1000;
my $data_size = 1;

my (@data, @wts, @flat_data);

for my $i (0..$data_size) {
    my $d = int (rand() * 100);
    my $w = 1 + int (rand() * 10);
    push @data, $d;
    push @wts, $w;
    push @flat_data, ($d) x $w;
}

my $stats_pdl = Statistics::Descriptive::PDL::SampleWeighted->new;
$stats_pdl->add_data (\@data, \@wts);
my $stats_desc = Statistics::Descriptive::Full->new;
$stats_desc->add_data (\@flat_data);

my @methods = qw /mean standard_deviation skewness kurtosis median mode/;

stats_pdl();
stats_desc();

say "Running with data size $data_size, calling stats $n_iters times"; 
cmpthese (-2, {
    stats_pdl  => \&stats_pdl,
    stats_desc => \&stats_desc,
});


sub stats_pdl {
    my $stats_pdl = Statistics::Descriptive::PDL::SampleWeighted->new;
    $stats_pdl->add_data (\@data, \@wts);
    my %results;
    for my $i (0..$n_iters) {
        foreach my $method (@methods) {
            $results{$method} = $stats_pdl->$method;
        }
    }
    if (FEEDBACK) {
        say 'Stats PDL';
        say join ' ', @results{@methods};
    }
}

sub stats_desc {
    my %results;
    my $stats_desc = Statistics::Descriptive::Full->new;
    my @flat_data = map {($data[$_]) x $wts[$_]} (0..$#wts);

    $stats_desc->add_data (\@flat_data);
    for my $i (0..$n_iters) {
        foreach my $method (@methods) {
            $results{$method} = $stats_desc->$method;
        }
    }
    if (FEEDBACK) {
        say 'Stats Desc';
        say join ' ', @results{@methods};
    }
}

