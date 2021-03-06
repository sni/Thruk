package Monitoring::Config::Object::Scheduler;

use warnings;
use strict;

use parent 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Scheduler - Shinken Scheduler Object Configuration

=head1 DESCRIPTION

Defaults for scheduler objects

=cut

##########################################################

$Monitoring::Config::Object::Scheduler::Defaults = {
    'name'                            => { type => 'STRING', cat => 'Extended' },
    'use'                             => { type => 'LIST', link => 'scheduler', cat => 'Basic' },
    'register'                        => { type => 'BOOL', cat => 'Extended' },

    # From SatelliteLink:
    'address'                         => { type => 'STRING', cat => 'Basic' },
    'timeout'                         => { type => 'INT', cat => 'Extended' },
    'data_timeout'                    => { type => 'INT', cat => 'Extended' },
    'check_interval'                  => { type => 'INT', cat => 'Extended' },
    'max_check_attempts'              => { type => 'INT', cat => 'Extended' },
    'spare'                           => { type => 'BOOL', cat => 'Extended' },
    #'manage_sub_realms'               => { type => 'BOOL', cat => 'Extended' },
    #'manage_arbiters'                 => { type => 'BOOL', cat => 'Extended' },
    'modules'                         => { type => 'STRING', cat => 'Basic' },
    'polling_interval'                => { type => 'INT', cat => 'Extended' },
    'use_timezone'                    => { type => 'STRING', cat => 'Extended' },
    'realm'                           => { type => 'LIST', 'link' => 'realm', cat => 'Extended' },
    'satellitemap'                    => { type => 'STRING', cat => 'Extended' },
    'use_ssl'                         => { type => 'BOOL', cat => 'Extended' },

    # Specific
    'scheduler_name'                  => { type => 'STRING', cat => 'Basic' },
    'port'                            => { type => 'INT', cat => 'Basic' },
    'weight'                          => { type => 'INT', cat => 'Extended' },
    'skip_initial_broks'              => { type => 'BOOL', cat => 'Extended' },
    'hard_ssl_name_check'             => { type => 'BOOL', cat => 'Extended' },
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
        'type'        => 'scheduler',
        'primary_key' => 'scheduler_name',
        'default'     => $Monitoring::Config::Object::Scheduler::Defaults,
        'standard'    => [ 'scheduler_name', 'address', 'port', 'modules' ],
    };
    bless $self, $class;
    return $self;
}

##########################################################

1;
