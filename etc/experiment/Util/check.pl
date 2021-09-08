use 5.010;
use strict;
use warnings;

use blib;
use Statistics::Descriptive::PDL::Util;
use PDL;

my $d = pdl [1..6];
my $w = pdl [1,1,1,2,2,2];
say qq{$w $d};
say sum_a_by_contiguous_b ($d, $w)
