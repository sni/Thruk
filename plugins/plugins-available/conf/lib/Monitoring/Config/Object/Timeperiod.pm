package Monitoring::Config::Object::Timeperiod;

use strict;
use warnings;
use Moose;
extends 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Timeperiod - Timeperiod Object Configuration

=head1 DESCRIPTION

Defaults for timeperiod objects

=cut

##########################################################

$Monitoring::Config::Object::Timeperiod::Defaults = {
    'name'              => { type => 'STRING', cat => 'Extended' },
    'use'               => { type => 'LIST', link => 'timeperiod', cat => 'Basic' },
    'register'          => { type => 'BOOL', cat => 'Extended' },

    'timeperiod_name'   => { type => 'STRING', cat => 'Basic' },
    'alias'             => { type => 'STRING', cat => 'Basic' },
    'monday'            => { type => 'STRING', cat => 'Weekdays', help => '[weekday]' },
    'tuesday'           => { type => 'STRING', cat => 'Weekdays', help => '[weekday]' },
    'wednesday'         => { type => 'STRING', cat => 'Weekdays', help => '[weekday]' },
    'thursday'          => { type => 'STRING', cat => 'Weekdays', help => '[weekday]' },
    'friday'            => { type => 'STRING', cat => 'Weekdays', help => '[weekday]' },
    'saturday'          => { type => 'STRING', cat => 'Weekdays', help => '[weekday]' },
    'sunday'            => { type => 'STRING', cat => 'Weekdays', help => '[weekday]' },
    'exception'         => { type => 'STRING', help => '[exception]' },
    'exclude'           => { type => 'LIST', 'link' => 'timeperiod' },
};

##########################################################

=head1 METHODS

=head2 new

return new object

=cut
sub new {
    my $class = shift || __PACKAGE__;
    my $self = {
        'type'        => 'timeperiod',
        'primary_key' => 'timeperiod_name',
        'default'     => $Monitoring::Config::Object::Timeperiod::Defaults,
        'standard'    => [ 'timeperiod_name', 'alias', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday' ],
    };
    bless $self, $class;
    return $self;
}


##########################################################

=head2 parse

parse the object config

=cut
sub parse {
    my $self = shift;
    return $self->SUPER::parse($self->{'default'});
}


=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
