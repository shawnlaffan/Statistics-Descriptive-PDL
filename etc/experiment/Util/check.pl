use 5.010;
use strict;
use warnings;

use blib;
use Statistics::Descriptive::PDL::Util;
use PDL;

my $d = pdl [1..10];
my $w = pdl [1,1,1,2,2,2,3,3,3,4];
say qq{$w $d};
my ($t) = sum_a_by_contiguous_b ($d, $w);

say "OUTPUT: $t";

$d = pdl ([1..10], [1..10]);
$w = pdl ([1,1,1,2,2,2,3,3,3,4],
             [1,1,1,2,2,2,3,3,3,4]);
say qq{$w $d};
my ($t) = sum_a_by_contiguous_b ($d, $w);

say "OUTPUT: $t";
