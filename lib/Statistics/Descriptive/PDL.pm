package Statistics::Descriptive::PDL;

use 5.010;
use strict;
use warnings;

#  avoid loading too much, especially into our name space
use PDL::Lite '2.012';
use PDL::Stats::Basic;

our $VERSION = '0.01';

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
    my $count = $self->count;

    #  $count is modified lower down, but we need this flag after that
    my $has_existing_data = $count;

    # Take care of appending to an existing data set
    if ($has_existing_data) {
        $piddle = $self->_get_piddle;
        $piddle = $piddle->append (pdl ($data));
        $self->_set_piddle ($piddle);
    }
    else {
        $self->_set_piddle ($data);
        $piddle = $self->_get_piddle;
    }

    # probably inefficient, as we often only want some of these,
    #my ($mean, $prms, $median, $min, $max, $adev, $rms) = $self->_get_piddle->statsover;
    $self->{mean}   = $piddle->average->sclr;
    $self->{sum}    = $piddle->sum;
    $self->{sd}     = $self->standard_deviation;
    $self->{median} = $piddle->median;
    $self->{min}    = $piddle->min;
    $self->{max}    = $piddle->max;

    return $self->count;
}

#  need to croak if $data is multidimensional, or perhaps just flatten it out
sub _set_piddle {
    my ($self, $data) = @_;
    $self->{piddle} = pdl $data;
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
    return $self->{sum};
}

#  do we need to cache this?  Or even need it?
sub sumsq {
    my $self = shift;
    my $piddle = $self->_get_piddle
      // return;
    my $sq = $piddle ** 2;
    return $sq->sum;
}

sub min {
    my $self = shift;
    return $self->{min};
}

sub max {
    my $self = shift;
    return $self->{max};
}

sub mean {
    my $self = shift;
    return $self->{mean};
}

sub standard_deviation {
    my $self = shift;
    #return $self->{sd} if defined $self->{sd};  #  need to clear the cache before using this

    my $piddle = $self->_get_piddle
      // return undef;
    my $sd;
    my $n = $piddle->nelem;
    if ($n > 1) {
        $sd = $piddle->stdv_unbiased->sclr;
        #$sd *= ($n / ($n - 1));
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
    
    return $piddle->skew_unbiased;

    my $mean = $self->mean;
    my $sd   = $self->standard_deviation;

    my $pow3 = (($piddle - $mean) / $sd) ** 3;
    say $pow3;
    my $sum_pow3 = $pow3->sum;
    my $correction = $n / ( ($n-1) * ($n-2) );

    return $correction * $sum_pow3;
}

sub kurtosis {
    my $self = shift;
    my $piddle = $self->_get_piddle
      // return undef;
    return $piddle->nelem > 3 ? $piddle->kurt_unbiased->sclr : undef;
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

    my $count = $self->count;

    return undef if !$count;
    my $mode = $piddle->mode;
    if ($mode > $piddle->max) {
        #  PDL returns strange numbers when distributions are flat
        $mode = undef;
    }
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

#  place holders
sub quantile {undef}
sub trimmed_mean {undef}
sub least_squares_fit {undef}


1;

__END__


=head1 NAME

Statistics::Descriptive::PDL - The great new Statistics::Descriptive::PDL!

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Statistics::Descriptive::PDL;

    my $foo = Statistics::Descriptive::PDL->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 function1

=cut


=head2 function2

=cut


=head1 AUTHOR

Shawn Laffan, C<< <shawnlaffan at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-statistics-descriptive-pdl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Statistics-Descriptive-PDL>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Statistics::Descriptive::PDL


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Statistics-Descriptive-PDL>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Statistics-Descriptive-PDL>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Statistics-Descriptive-PDL>

=item * Search CPAN

L<http://search.cpan.org/dist/Statistics-Descriptive-PDL/>

=back


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

