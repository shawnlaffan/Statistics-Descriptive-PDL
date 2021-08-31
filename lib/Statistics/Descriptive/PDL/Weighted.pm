package Statistics::Descriptive::PDL::Weighted;

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

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = {piddle => undef};
    bless $self, $class;

    return $self;
}


sub _wt_type{PDL::double()}

sub add_data {
    my ($self, $data, $weights) = @_;

    my ($data_piddle, $weights_piddle);

    if (ref $data eq 'HASH') {
        $data_piddle    = PDL->pdl ([keys %$data])->flat;
        $weights_piddle = PDL->pdl ($self->_wt_type, [values %$data])->flat;
    }
    else {
        die "data and weight vectors not of same length"
          if scalar @$data != scalar @$weights;
        $data_piddle    = PDL->pdl ($data)->flat;
        $weights_piddle = PDL->pdl ($self->_wt_type, $weights)->flat;
    }

    return if !$data_piddle->nelem;

    my $has_existing_data = $self->count;

    # Take care of appending to an existing data set
    if ($has_existing_data) {
        my $d_piddle = $self->_get_data_piddle;
        $d_piddle    = $d_piddle->append ($data_piddle);
        $self->_set_data_piddle ($d_piddle);
        my $w_piddle = $self->_get_weights_piddle;
        $w_piddle    = $w_piddle->append ($weights_piddle);
        $self->_set_weights_piddle ($w_piddle);
        
        delete $self->{cumsum_weight_vector};
        delete $self->{sorted};
    }
    else {
        $self->_set_data_piddle ($data_piddle);
        $self->_set_weights_piddle ($weights_piddle);
    }

    return $self->count;
}

sub _set_data_piddle {
    my ($self, $data) = @_;
    $self->{data_piddle} = PDL->pdl ($data);
}

sub _get_data_piddle {
    my $self = shift;
    return $self->{data_piddle};
}

sub _set_weights_piddle {
    my ($self, $data) = @_;
    $self->{weights_piddle} = PDL->pdl ($data);
}

sub _get_weights_piddle {
    my $self = shift;
    return $self->{weights_piddle};
}

sub count {
    my $self = shift;
    my $piddle = $self->_get_weights_piddle
      // return 0;
    return $piddle->sum;
}

sub sum {
    my $self = shift;
    my $data = $self->_get_data_piddle
      // return undef;
    return undef if $data->isempty;
    return ($data * $self->_get_weights_piddle)->sum;
}

sub sum_weights {
    my $self = shift;
    my $piddle = $self->_get_weights_piddle
      // return undef;
    return undef if $piddle->isempty;
    return $piddle->sum;
}

sub min {
    my $self = shift;
    my $piddle = $self->_get_data_piddle
      // return undef;
    return undef if $piddle->isempty;
    return $piddle->min;
}

sub max {
    my $self = shift;
    my $piddle = $self->_get_data_piddle
      // return undef;
    return undef if $piddle->isempty;
    return $piddle->max;
}

sub min_weight {
    my $self = shift;
    my $piddle = $self->_get_weights_piddle
      // return undef;
    return undef if $piddle->isempty;
    return $piddle->min;
}


sub mean {
    my $self = shift;
    my $data = $self->_get_data_piddle
      // return undef;

    return undef if $data->isempty;
    # should cache the sum of wts
    my $wts = $self->_get_weights_piddle;
    return ($data * $wts)->sum / $wts->sum;
}


sub standard_deviation {
    my $self = shift;

    my $data = $self->_get_data_piddle
      // return undef;
    my $sd;
    my $n = $data->nelem;
    if ($n > 1) {
        #  long winded approach
        my $wts  = $self->_get_weights_piddle;
        my $mean = $self->mean;
        my $sumsqr = ($wts * (($data - $mean) ** 2))->sum;
        my $var = $sumsqr / $self->sum_weights;
        $sd = sqrt $var;
    }
    elsif ($n == 1){
        $sd = 0;
    }
    return $sd;
}

sub variance {
    my $self = shift;
    my $sd = $self->standard_deviation;
    return defined $sd ? $sd ** 2 : undef;
}

sub median {
    my $self = shift;
    my $data = $self->_get_data_piddle
      // return undef;
    return undef if $data->isempty;

    $data = $self->_sort_piddle;
    my $cumsum = $self->_get_cumsum_weight_vector;

    my $target_wt = $self->sum_weights * 0.5;
    #  vsearch should be faster since it uses a binary search
    my $idx = PDL->pdl($target_wt)->vsearch_insert_leftmost($cumsum->reshape);

    return $data($idx)->sclr;
}

sub _sort_piddle {
    my $self = shift;
    my $data = $self->_get_data_piddle
      // return undef;

    return $data if $self->{sorted};

    my $wts = $self->_get_weights_piddle;
    my $s = $data->qsorti->reshape;
    my $sorted_data = $data($s);
    my $sorted_wts  = $wts($s);

    $self->_set_data_piddle($sorted_data);
    $self->_set_weights_piddle($sorted_wts);

    $self->{sorted} = 1;
    $self->{cumsum_weight_vector}
      = $sorted_wts->cumusumover->reshape;  #  need to cache this

    return $sorted_data;
}

#  de-duplicate if needed, aggregating weights
#  there should be a sumover or which approach that will work better
sub _deduplicate_piddle {
    my $self = shift;
    my $piddle = $self->_get_data_piddle
      // return undef;

    my $unique = $piddle->uniq;

    return $self->_get_data_piddle
     if $unique->nelem == $piddle->nelem;
     
    my $wts_piddle = $self->_get_weights_piddle;

    $piddle = $self->_sort_piddle;

    my (@data, @wts);
    
    push @data, $piddle(0)->sclr;
    push @wts,  $wts_piddle(0)->sclr;
    my $last_val = $data[0];

    #  could use a map into a hash, but this avoids
    #  stringification and loss of precision
    #  (not that that should cause too many issues for most data)
    #  Should be able to use ->setops for this process to reduce looping
    #  when there are not many dups in large data sets
    foreach my $i (1..$piddle->nelem-1) {
        if ($piddle($i) == $last_val) {
            $wts[-1] += $wts_piddle($i)->sclr;
        }
        else {
            push @data, $piddle($i)->sclr;
            push @wts,  $wts_piddle($i)->sclr;
            $last_val = $data[-1];
        }
    }
    $self->_set_data_piddle(\@data);
    $self->_set_weights_piddle(\@wts);

    return $self->_get_data_piddle;
}

sub _get_cumsum_weight_vector {
    my $self = shift;
    return $self->{cumsum_weight_vector};
}

sub skewness {
    my $self = shift;
    my $data = $self->_get_data_piddle
      // return undef;

    return undef if $data->isempty;

    #  long winded approach
    my $mean = $self->mean;
    my $sd   = $self->standard_deviation;
    my $wts = $self->_get_weights_piddle;
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
    my $wts = $self->_get_weights_piddle;
    my $sumpow4 = ($wts * ((($data - $mean) / $sd) ** 4))->sum;
    my $kurt = $sumpow4 / $self->sum_weights - 3;
    return $kurt;
}

sub sample_range {
    my $self = shift;
    my $min = $self->min // return undef;
    my $max = $self->max // return undef;
    return $max - $min;
}


sub harmonic_mean {
    my $self = shift;
    my $data = $self->_get_data_piddle
      // return undef;

    return undef if $data->which->nelem != $data->nelem;

    my $wts = $self->_get_weights_piddle;
    
    my $hs = ((1 / $data) * $wts)->sum;

    return $hs ? $self->count / $hs : undef;
}

sub geometric_mean {
    my $self = shift;
    my $data = $self->_get_data_piddle
      // return undef;

    return undef if $data->isempty;
    #  should add a sorted status check, as we can use vsearch in such cases
    return undef if $data->where($data < 0)->nelem;

    my $wts = $self->_get_weights_piddle;

    my $exponent = 1 / $self->sum_weights;
    my $powered = $data * $wts;

    my $gm = $powered->dprodover ** $exponent;
    return $gm;
}

sub mode {
    my $self = shift;
    my $data = $self->_get_data_piddle
      // return undef;

    return undef if $data->isempty;

    #  de-duplicate and aggregate weights if needed
    $data = $self->_deduplicate_piddle;

    my $wts = $self->_get_weights_piddle;
    my $mode = $data($wts->maximum_ind)->sclr;
    if ($mode > $data->max) {
        #  PDL returns strange numbers when distributions are flat
        $mode = undef;
    }
    return $mode;
}

#  need to convert $p to fraction, or perhaps die if it is between 0 and 1
sub percentile {
    my ($self, $p) = @_;
    my $data = $self->_get_data_piddle
      // return undef;

    return undef if $data->isempty;

    $data = $self->_sort_piddle;
    my $cumsum = $self->_get_cumsum_weight_vector;

    my $target_wt = $self->sum_weights * ($p / 100);

    my $idx = PDL->pdl($target_wt)->vsearch_insert_leftmost($cumsum->reshape);  

    return $data($idx)->sclr;
}


1;

__END__


=head1 NAME

Statistics::Descriptive::PDL::Weighted - A close to drop-in replacement for
Statistics::Descriptive::Weighted using PDL as the back-end

=head1 VERSION

Version 0.02

=cut

=head1 SYNOPSIS


    use Statistics::Descriptive::PDL::Weighted;

    my $stats = Statistics::Descriptive::PDL::Weighted->new;
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
using weighted values.  


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

=item geometric_mean

=item harmonic_mean

=item max

=item mean

=item median

=item min

=item mode

=item sample_range

=item standard_deviation

=item sum

=item variance

The above should need no explanation, except that they
use the unbiased methods where appropriate, as per Statistics::Descriptive.

=item count

=item sum_wts

Sum of the weights vector.
 

=item skewness

=item kurtosis

Skewness and kurtosis to match that of MS Excel.
If you are used to R then these are the same as type=2
in e1071::skewness and e1071::kurtosis.


=item percentile (10)

=item percentile (45)

The percentile calculation differs from Statistics::Descriptive
and Statistics::Descriptive::PDL.

TODO:  Explain how it differs

=head2 Not yet implemented, and possibly won't be.

Any of the trimmed functions, frequency functions and some others.

=item least_squares_fit

=item trimmed_mean

=item quantile

=item mindex

=item maxdex

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

