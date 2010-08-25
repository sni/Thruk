package # Hide from pause
    Monitoring::Livestatus::Class::Abstract::Stats;

use Moose;
use Carp;
extends 'Monitoring::Livestatus::Class::Base::Abstract';

our $TRACE = $ENV{'MONITORING_LIVESTATUS_CLASS_TRACE'} || 0;

sub build_mode { return 'Stats'; };

sub build_compining_prefix { return 'Stats'; }

sub build_operators {
    my $self = shift;
    my $operators = $self->SUPER::build_operators();

    push @{ $operators }, {
        regexp  => qr/(groupby)/mix,
        handler => '_cond_op_groupby',
    };

    return $operators;
}

sub _cond_op_groupby {
    my $self    = shift;
    my $operator = shift;
    my $value = shift;
    my $combining_count = shift || 0;

    print STDERR "#IN  _cond_op_groupby $operator $value $combining_count\n" if $TRACE > 9;

    my ( @child_statment ) = $self->_dispatch_refkind($value, {
        SCALAR  => sub {
            return ( sprintf("%s: %s",$operator,$value) );
        },
    });

    print STDERR "#OUT _cond_op_groupby $operator $value $combining_count\n" if $TRACE > 9;
    return ( $combining_count, @child_statment );
}

sub _cond_hashpair_HASHREF {
    my $self            = shift;
    my $key             = shift || '';
    my $values          = shift || {};
    my $combining       = shift || undef;
    my $combining_count = shift || 0;
    my @statment;

    print STDERR "# _cond_hashpair_HASHREF $combining_count\n" if $TRACE > 9;

    my @operator   = keys(%{$values});
    my $firstkey   = shift @operator;

    if($firstkey ne '-stats') {
        return $self->SUPER::_cond_hashpair_HASHREF($key, $values, $combining, $combining_count);
    }

    ($combining_count, @statment) = $self->SUPER::_cond_ARRAYREF($values->{$firstkey}, $combining_count);

    if($#statment > 0) {
        push @statment, "StatsAnd: ".scalar @statment;
    }

    # set the column name
    $statment[$#statment] = $statment[$#statment]." as ".$key;

    return ( $combining_count, @statment );
}

sub _cond_HASHREF {
    my $self            = shift;
    my $cond            = shift;
    my $combining_count = shift || 0;

    print STDERR "# _cond_HASHREF\n" if $TRACE > 9 ;

    foreach my $key ( keys %{ $cond } ){
        if(!defined $cond->{$key}) {
            return(++$combining_count, sprintf("%s: %s",$self->mode,$key));
        }
    }

    return $self->SUPER::_cond_HASHREF($cond, $combining_count);
}

1;
__END__
=head1 NAME

Monitoring::Livestatus::Class::Abstract::Stats - Class to generate livestatus
stats

=head2 SYNOPSIS

=head1 ATTRIBUTES

=head1 METHODS

=head2 apply

please view in L<Monitoring::Livestatus::Class::Base::Abstract>

=head1 INTERNAL METHODS

=over 4

=item build_mode

=item build_compining_prefix

=item build_operators

=back

=head1 AUTHOR

See L<Monitoring::Livestatus::Class/AUTHOR> and L<Monitoring::Livestatus::Class/CONTRIBUTORS>.

=head1 COPYRIGHT & LICENSE

Copyright 2009 Robert Bohne.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
