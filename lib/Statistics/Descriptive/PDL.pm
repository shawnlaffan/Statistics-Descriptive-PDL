package Statistics::Descriptive::PDL;

use 5.010;
use strict;
use warnings;

#  avoid loading too much, especially into our name space
use PDL::Lite '2.012';
#  try to keep running if PDL::Stats is not installed
eval 'require PDL::Stats::Basic';
my $has_PDL_stats_basic = $@ ? undef : 1;
#$has_PDL_stats_basic = 0;

#  We could inherit from PDL::Objects, but in this case we want
#  to hide the piddle from the caller to avoid arbitrary changes
#  being applied to it.

our $VERSION = '0.02';

our $Tolerance = 0.0;  #  for compatibility with Stats::Descr, but not used here

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = {piddle => undef};
    bless $self, $class;

    return $self;
}


sub add_data {
    my $self = shift;
    my $data;

    if (ref $_[0] eq 'ARRAY') {
        $data = $_[0];
    }
    else {
        $data = \@_;
    }

    return if !scalar @$data;

    my $piddle;
    my $has_existing_data = $self->count;

    # Take care of appending to an existing data set
    if ($has_existing_data) {
        $piddle = $self->_get_piddle;
        $piddle = $piddle->append (PDL->pdl ($data)->flat);
        $self->_set_piddle ($piddle);
    }
    else {
        $self->_set_piddle (PDL->pdl($data)->flat);
    }

    return $self->count;
}

#  flatten $data if multidimensional
sub _set_piddle {
    my ($self, $data) = @_;
    $self->{piddle} = PDL->pdl ($data);
}

sub _get_piddle {
    my $self = shift;
    return $self->{piddle};
}

sub count {
    my $self = shift;
    my $piddle = $self->_get_piddle
      // return 0;
    return $piddle->nelem;
}

sub sum {
    my $self = shift;
    my $piddle = $self->_get_piddle
      // return undef;
    return $piddle->nelem ? $piddle->sum : undef;
}


sub min {
    my $self = shift;
    my $piddle = $self->_get_piddle
      // return undef;
    return $piddle->nelem ? $piddle->min : undef;
}

sub max {
    my $self = shift;
    my $piddle = $self->_get_piddle
      // return undef;
    return $piddle->nelem ? $piddle->max : undef;
}

sub mean {
    my $self = shift;
    my $piddle = $self->_get_piddle
      // return undef;
    return $piddle->nelem ? $piddle->average : undef;
}


sub standard_deviation {
    my $self = shift;

    my $piddle = $self->_get_piddle
      // return undef;
    my $sd;
    my $n = $piddle->nelem;
    if ($n > 1) {
        if ($has_PDL_stats_basic) {
            $sd = $piddle->stdv_unbiased->sclr;
        }
        else {
            my $var = (($piddle ** 2)->sum - $n * $self->mean ** 2)->sclr;
            $sd = $var > 0 ? sqrt ($var / ($n - 1)) : 0;
        }
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
    my $piddle = $self->_get_piddle
      // return undef;
    return $piddle->nelem ? $piddle->median : undef;
}


sub skewness {
    my $self = shift;
    my $piddle = $self->_get_piddle
      // return undef;

    my $n = $piddle->nelem;

    return undef if $n < 3;

    return $piddle->skew_unbiased
      if $has_PDL_stats_basic;

    #  do it ourselves
    my $mean = $self->mean;
    my $sd   = $self->standard_deviation;
    my $sumpow3 = ((($piddle - $mean) / $sd) ** 3)->sum;
    my $correction = $n / ( ($n-1) * ($n-2) );
    my $skew = $correction * $sumpow3;

    return $skew;
}

sub kurtosis {
    my $self = shift;
    my $piddle = $self->_get_piddle
      // return undef;

    my $n = $piddle->nelem;

    return undef if $n < 4;

    return $piddle->kurt_unbiased->sclr 
      if $has_PDL_stats_basic;

    #  do it ourselves
    my $mean = $self->mean;
    my $sd   = $self->standard_deviation;
    my $sumpow4 = ((($piddle - $mean) / $sd) ** 4)->sum;

    my $correction1 = ( $n * ($n+1) ) / ( ($n-1) * ($n-2) * ($n-3) );
    my $correction2 = ( 3  * ($n-1) ** 2) / ( ($n-2) * ($n-3) );

    my $kurt = ( $correction1 * $sumpow4 ) - $correction2;
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
    my $piddle = $self->_get_piddle
      // return undef;

    return undef if $piddle->which->nelem != $piddle->nelem;

    my $hs = (1 / $piddle)->sum;

    return $hs ? $self->count / $hs : undef;
}

sub geometric_mean {
    my $self = shift;
    my $piddle = $self->_get_piddle
      // return undef;

    my $count = $self->count;

    return undef if !$count;
    return undef if $piddle->where($piddle < 0)->nelem;

    my $exponent = 1 / $self->count();
    my $powered = $piddle ** $exponent;

    my $gm = $powered->dprodover;
}

sub mode {
    my $self = shift;
    my $piddle = $self->_get_piddle
      // return undef;

    return undef if $piddle->isempty;
    
    my $count  = $piddle->nelem;
    my $unique = $piddle->uniq;

    return undef if $unique->nelem == $count or $unique->nelem == 1;

    #if (!($count % $unique->nelem)) {
    #    #  might have equal numbers of each value
    #    #  need to check for this, but for now return undef
    #    return undef;
    #}

    my $mode = $piddle->mode;
    
    #  bodge to handle odd values
    return undef if !$piddle->in($mode)->max;
    
    return $mode;
}

#  need to convert $p to fraction, or perhaps die if it is betwen 0 and 1
sub percentile {
    my ($self, $p) = @_;
    my $piddle = $self->_get_piddle
      // return undef;

    my $count = $piddle->nelem;
    
    return undef if !$count;
    return $piddle->pct($p / 100);
}

1;

__END__


=head1 NAME

Statistics::Descriptive::PDL - A close to drop-in replacement for
Statistics::Descriptive using PDL as the back-end

=head1 VERSION

Version 0.02

=cut

=head1 SYNOPSIS


    use Statistics::Descriptive::PDL;

    my $stats = Statistics::Descriptive::PDL->new();
    $stats->add_data(1,2,3,4);
    my $mean = $stat->mean;
    my $var  = $stat->variance();

=head1 DESCRIPTION

This module provides basic functions used in descriptive statistics.


=head1 METHODS

=item new

Create a new statistics object.  Takes no arguments.

=item add_data (@data)

=item add_data (\@data)

Add data to the stats object.  Passed through to the underlying PDL object.
Appends to any existing data.

Multidimensional data are flattened into a singe dimensional array.

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

Number of data items that have been added.


=item skewness

=item kurtosis

Skewness and kurtosis to match that of MS Excel.
If you are used to R then these are the same as type=2
in e1071::skewness and e1071::kurtosis.


=item percentile (10)

=item percentile (45)

The percentile calculation differs from Statistics::Descriptive in that it uses
linear interpolation to determine the values, and does not
return the exact same values as the input data.

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

