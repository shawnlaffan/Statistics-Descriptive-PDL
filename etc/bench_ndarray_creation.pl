use 5.010;
use strict;
use warnings;

use PDL;

use Benchmark qw/cmpthese/;

my $n = 10000;

cmpthese (-1, {
    direct        => sub {my $x = pdl ( 5 ) for 0..$n},
    aref          => sub {my $x = pdl ([5]) for 0..$n},
    direct_typed  => sub {my $x = pdl (PDL::indx(),  5 ) for 0..$n},
    aref_typed    => sub {my $x = pdl (PDL::indx(), [5]) for 0..$n},
});