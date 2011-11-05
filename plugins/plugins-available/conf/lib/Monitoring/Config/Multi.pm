package Monitoring::Config::Multi;

use strict;
use warnings;
use Monitoring::Config;

=head1 NAME

Monitoring::Config::Multi - Manage Multiple Object Configurations

=head1 DESCRIPTION

Manage Multiple Object Configurations

=head1 METHODS

=cut


##########################################################

=head2 new

return objects object

=cut
sub new {
    my $class = shift;

    my $self = {
        'configs' => {},
        'parsing' => {},
    };

    bless $self, $class;

    return $self;
}


##########################################################

=head2 init

initialize configs

=cut
sub init {
    my $self   = shift;
    my $key    = shift;
    my $config = shift;
    my $data   = shift;

    if(defined $data) {
        $self->{'configs'}->{$key} = $data;
        $self->{'configs'}->{$key}->{'cached'} = 1;
        return $self->{'configs'}->{$key};
    }

    if(defined $self->{'configs'}->{$key}) {
        $self->{'configs'}->{$key}->{'cached'} = 1;
        return $self->{'configs'}->{$key};
    }

    $self->{'configs'}->{$key} = Monitoring::Config->new(@_);
    $self->{'configs'}->{$key}->init($config);

    return $self->{'configs'}->{$key};
}


##########################################################

=head2 cache_exists

returns true if this object already exists

=cut
sub cache_exists {
    my $self   = shift;
    my $key    = shift;

    if(defined $self->{'configs'}->{$key}) {
        return 1;
    }

    return;
}


##########################################################

=head2 currently_parsing

returns job id if config is currently beeing parsed

=cut
sub currently_parsing {
    my $self   = shift;
    my $key    = shift;
    my $id     = shift;

    $self->{'parsing'}->{$key} = $id if defined $id;

    return $self->{'parsing'}->{$key};
}


##########################################################

=head2 get_object_by_key

return config obj for key

=cut
sub get_object_by_key {
    my $self = shift;
    my $key  = shift;
    return $self->{'configs'}->{$key};
}


##########################################################

=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
