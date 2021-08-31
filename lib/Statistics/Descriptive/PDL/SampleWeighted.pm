package Statistics::Descriptive::PDL::SampleWeighted;

use 5.010;
use strict;
use warnings;

#  avoid loading too much, especially into our name space
use PDL::Lite '2.012';
#use PDL;
use PDL::NiceSlice;

#  this is otherwise not loaded due to oddities with multiple loading of PDL::Lite
#*pdl = \&PDL::Core::pdl;

#  We could inherit from PDL::Objects, but in this case we want
#  to hide the piddle from the caller to avoid arbitrary changes
#  being applied to it. 

our $VERSION = '0.02';

use parent 'Statistics::Descriptive::PDL::Weighted';

sub _wt_type{PDL::long()}


sub standard_deviation {
    my $self = shift;

    my $data = $self->_get_data_piddle
      // return undef;
    my $sd;
    
    my $wts = $self->_get_weights_piddle;
    my $n = $wts->sum->sclr;

    return 0 if $n == 1;

    my $var = ((($data ** 2) * $wts)->sum - $n * $self->mean ** 2)->sclr;

    $sd = $var > 0 ? sqrt ($var / ($n - 1)) : 0;

    return $sd;
}


sub median {
    my $self = shift;
    my $piddle = $self->_get_data_piddle
      // return undef;
    return undef if $piddle->isempty;

    $piddle = $self->_sort_piddle;
    my $cumsum = $self->_get_cumsum_weight_vector;

    my $target_wt = $self->sum_weights * 0.5;
    #  vsearch should be faster since it uses a binary search
    my $idx = PDL->pdl($target_wt)->vsearch_insert_leftmost($cumsum->reshape);

    return ($piddle($idx) + $piddle($idx+1))->sclr / 2;
}


sub skewness {
    my $self = shift;
    my $data = $self->_get_data_piddle
      // return undef;

    return undef if $data->isempty;

    #  long winded approach
    my $mean = $self->mean;
    my $sd   = $self->standard_deviation;
    my $wts  = $self->_get_weights_piddle;
    my $sumpow3 = ($wts * ((($data - $mean) / $sd) ** 3))->sum;
    my $skew = $sumpow3 / $self->sum_weights;
    return $skew;
}

sub kurtosis {
    my $self = shift;
    my $data = $self->_get_data_piddle
      // return undef;
    return undef if $data->isempty;

    #  long winded approach
    my $mean = $self->mean;
    my $sd   = $self->standard_deviation;
    my $wts  = $self->_get_weights_piddle;
    my $n = $wts->sum->sclr;

    my $sumpow4 = ($wts * ((($data - $mean) / $sd) ** 4))->sum;

    my $correction1 = ( $n * ($n+1) ) / ( ($n-1) * ($n-2) * ($n-3) );
    my $correction2 = ( 3  * ($n-1) ** 2) / ( ($n-2) * ($n-3) );

    my $kurt = ( $correction1 * $sumpow4 ) - $correction2;

    return $kurt;
}


#  Uses same basic algorithm as PDL::pctl.
sub percentile {
    my ($self, $p) = @_;
    my $piddle = $self->_get_data_piddle
      // return undef;

    return undef if $piddle->isempty;

    $piddle = $self->_deduplicate_piddle;

    my $wt_piddle = $self->_get_weights_piddle;
    #if ($multiplier) {
    #    $wt_piddle = $wt_piddle * $multiplier;
    #}
    my $cumsum = $wt_piddle->cumusumover->reshape;
    my $wt_sum = $wt_piddle->sum;

    use POSIX qw /floor/;

    my $target_wt = ($p / 100) * ($wt_sum - 1) + 1;
    my $k = floor $target_wt;
    my $d = $target_wt - $k;

    my $idx = PDL->pdl($k)->vsearch_insert_leftmost($cumsum)->sclr;

    #  we need to interpolate if our target weight falls between two sets of weights
    #  e.g. target is 1.3, but the cumulative weights are [1,2] or [1,5]
    my $fraction = ($target_wt - $cumsum($idx))->sclr;
    if ($fraction < 1) {
        my $lower_val = $piddle($idx)->sclr;
        my $upper_val = $piddle($idx+1)->sclr;
        my $val = $lower_val + $d * ($upper_val - $lower_val);
        return $val;
    }

    return $piddle($idx)->sclr;
}

#sub median {
#    return $_[0]->percentile (50, $_[1]);
#}

#  place holders
sub quantile {undef}
sub trimmed_mean {undef}
sub least_squares_fit {undef}


1;

__END__


=head1 NAME

Statistics::Descriptive::PDL::SampleWeighted - A close to drop-in replacement for
Statistics::Descriptive::Weighted using PDL as the back-end

=head1 VERSION

Version 0.02

=cut

=head1 SYNOPSIS


    use Statistics::Descriptive::PDL::SampleWeighted;

    my $stats = Statistics::Descriptive::PDL::SampleWeighted->new;
    $stats->add_data([1,2,3,4], [1,3,5,6]);  #  values then weights
    my $mean = $stat->mean;
    my $var  = $stat->variance;
    
    #  or you can add data using a hash ref
    my %data = (1 => 1, 2 => 3, 3 => 5, 4 => 6);
    $stats->add_data(\%data);
    
    #  if you want equal weights then you need to supply them yourself
    my $data = [1,2,3,4];
    $stats->add_data($data, [(1) x scalar @$data]);
    
    
=head1 DESCRIPTION

This module provides basic functions used in descriptive statistics
using weighted values.  Inherits from S::D::PDL::Weighted, with the
key difference that the weights are forced to be integers.
Variance, skewness and kurtosis all use the unbiased calculations.  
The median and percentiles are then calculated using interpolation,
analogous to the unweighted case where values are repeated by the weights.  


=head1 METHODS

=item new

Create a new statistics object.  Takes no arguments.  

=item add_data (\%data)

=item add_data ([1,2,3,4], [0.5,1,0.1,2)

Add data to the stats object.  Appends to any existing data.

If a hash reference is passed then the keys are treated as the numeric data values,
with the hash values the weights.

Unlike Statistics::Descriptive::PDL, you cannot pass a flat array
since odd things might happen if we convert it to a hash and the values
are multidimensional.

Multidimensional data are flattened into a singe dimensional array.

Since we use the pdl function to process the data and weights you should be able to
specify anything pdl accepts as valid, but take care that the number of
weights matches the values.



=head1 AUTHOR

Shawn Laffan, C<< <shawnlaffan at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<https://github.com/shawnlaffan/Statistics-Descriptive-PDL/issues>.



=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2015 Shawn Laffan.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

