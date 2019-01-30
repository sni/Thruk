package Monitoring::Config::Object::Checkmodulation;

use strict;
use warnings;
use parent 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Checkmodulation - Shinken checkmodulation Object Configuration

=head1 DESCRIPTION

Defaults for checkmodulation objects

=cut

##########################################################

$Monitoring::Config::Object::Checkmodulation::Defaults = {
    'name'                            => { type => 'STRING', cat => 'Extended' },
    'use'                             => { type => 'LIST', link => 'checkmodulation', cat => 'Basic' },
    'register'                        => { type => 'BOOL', cat => 'Extended' },

    'checkmodulation_name'            => { type => 'STRING', cat => 'Basic' },
    'check_command'                   => { type => 'STRING', 'link' => 'command', cat => 'Basic' },
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
        'type'        => 'checkmodulation',
        'primary_key' => 'checkmodulation_name',
        'default'     => $Monitoring::Config::Object::Checkmodulation::Defaults,
        'standard'    => [ 'checkmodulation_name', 'check_command', 'modulation_period' ],
    };
    bless $self, $class;
    return $self;
}

##########################################################

1;
