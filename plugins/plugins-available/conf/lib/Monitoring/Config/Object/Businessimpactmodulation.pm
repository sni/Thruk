package Monitoring::Config::Object::Businessimpactmodulation;

use strict;
use warnings;
use parent 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Businessimpactmodulation - Shinken businessimpactmodulation Object Configuration

=head1 DESCRIPTION

Defaults for businessimpactmodulation objects

=cut

##########################################################

$Monitoring::Config::Object::Businessimpactmodulation::Defaults = {
    'name'                            => { type => 'STRING', cat => 'Extended' },
    'use'                             => { type => 'LIST', link => 'businessimpactmodulation', cat => 'Basic' },
    'register'                        => { type => 'BOOL', cat => 'Extended' },

    'business_impact_modulation_name' => { type => 'STRING', cat => 'Basic' },
    'business_impact'                 => { type => 'CHOOSE', values => [5,4,3,2,1,0], keys => Monitoring::Config::Object::Parent::_business_impact_keys(), cat => 'Basic' },
    'modulation_period'               => { type => 'STRING', 'link' => 'timeperiod', cat => 'Basic' },
};

##########################################################

=head1 METHODS

=head2 BUILD

return new object

=cut
sub BUILD {
    my $class    = shift || __PACKAGE__;
    my $coretype = shift;

    return unless($coretype eq 'any' or $coretype eq 'shinken');

    my $self = {
        'type'        => 'businessimpactmodulation',
        'primary_key' => 'business_impact_modulation_name',
        'default'     => $Monitoring::Config::Object::Businessimpactmodulation::Defaults,
        'standard'    => [ 'business_impact_modulation_name', 'business_impact', 'modulation_period' ],
    };
    bless $self, $class;
    return $self;
}

##########################################################

=head1 AUTHOR

Mathieu Parent, 2013, <math.parent@gmail.com>
Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
