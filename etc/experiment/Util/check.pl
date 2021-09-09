use 5.010;
use strict;
use warnings;

use blib;
use Statistics::Descriptive::PDL::Util;
use PDL;

my $d = pdl [1..10];
my $w = pdl [1,1,1,2,2,2,3,3,3,4];
say qq{$w $d};
my ($t) = rle_sum_onesie ($d, $w);

say "OUTPUT: $t";

$d = pdl ([1..10], [10..19]);
$w = pdl ([1,1,1,2,2,2,3,3,3,4],
          [1,1,2,2,2,2,3,3,3,4]);
say qq{$w $d};
my ($t) = rle_sum_onesie ($d, $w);

say "OUTPUT: $t";
