package Thruk::Utils::INC;

=head1 NAME

Thruk::Utils - INC Utility

=head1 DESCRIPTION

INC Utility

=cut

use strict;
use warnings;

##############################################
=head1 METHODS

=head2 clean

  clean()

clean @INC and remove duplicate and non-existand folders

=cut
sub clean {
    my $dups = {};
    my @new;
    for my $d (@INC) {
        next if $dups->{$d};
        next if !-d $d.'/.';
        $dups->{$d} = 1;
        push @new, $d;
    }
    @INC = @new;
    return;
}


##############################################

1;

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
