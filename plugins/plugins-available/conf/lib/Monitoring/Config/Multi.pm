package Monitoring::Config::Multi;

use strict;
use warnings;
use Module::Load qw/load/;

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
    my($self, $key, $config, $data, $stats, $remotepeer) = @_;

    $stats->profile(begin => "M::C::M::init()") if defined $stats;

    if(defined $data) {
        $self->{'configs'}->{$key} = $data;
        $self->{'configs'}->{$key}->{'cached'} = 1;
        return $self->{'configs'}->{$key};
    }

    load Monitoring::Config;
    if(defined $self->{'configs'}->{$key}) {
        $self->{'configs'}->{$key}->{'cached'} = 1;
        $self->{'configs'}->{$key}->init($config, $stats) if defined $config;
        $stats->profile(end => "M::C::M::init()") if defined $stats;
        return $self->{'configs'}->{$key};
    }

    $self->{'configs'}->{$key} = Monitoring::Config->new(@_);
    $self->{'configs'}->{$key}->init($config, $stats, $remotepeer);

    $stats->profile(end => "M::C::M::init()") if defined $stats;
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

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
