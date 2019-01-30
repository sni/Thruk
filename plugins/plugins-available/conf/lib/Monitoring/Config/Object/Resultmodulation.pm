package Monitoring::Config::Object::Resultmodulation;

use strict;
use warnings;
use parent 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Resultmodulation - Shinken resultmodulation Object Configuration

=head1 DESCRIPTION

Defaults for resultmodulation objects

=cut

##########################################################

$Monitoring::Config::Object::Resultmodulation::Defaults = {
    'name'                            => { type => 'STRING', cat => 'Extended' },
    'use'                             => { type => 'LIST', link => 'resultmodulation', cat => 'Basic' },
    'register'                        => { type => 'BOOL', cat => 'Extended' },

    'resultmodulation_name'           => { type => 'STRING', cat => 'Basic' },
    'exit_codes_match'                => { type => 'ENUM', values => [0,1,2,3,4], keys => ['OK','WARNING','CRITICAL','UNKNOWN','DEPENDENT'], cat => 'Basic' },
    'exit_code_modulation'            => { type => 'CHOOSE', values => [0,1,2,3,4], keys => ['OK','WARNING','CRITICAL','UNKNOWN','DEPENDENT'], cat => 'Basic' },
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
        'type'        => 'resultmodulation',
        'primary_key' => 'resultmodulation_name',
        'default'     => $Monitoring::Config::Object::Resultmodulation::Defaults,
        'standard'    => [ 'resultmodulation_name', 'exit_codes_match', 'exit_code_modulation', 'modulation_period' ],
    };
    bless $self, $class;
    return $self;
}

##########################################################

1;
