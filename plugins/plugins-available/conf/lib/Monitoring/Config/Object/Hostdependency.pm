package Monitoring::Config::Object::Hostdependency;

use strict;
use warnings;
use parent 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Hostdependency - Hostdependency Object Configuration

=head1 DESCRIPTION

Defaults for hostdependency objects

=cut

##########################################################

$Monitoring::Config::Object::Hostdependency::Defaults = {
    'name'                          => { type => 'STRING', cat => 'Extended' },
    'use'                           => { type => 'LIST', link => 'hostdependency', cat => 'Basic' },
    'register'                      => { type => 'BOOL', cat => 'Extended' },

    'dependent_host_name'           => { type => 'LIST', 'link' => 'host' },
    'dependent_hostgroup_name'      => { type => 'LIST', 'link' => 'hostgroup' },
    'host_name'                     => { type => 'LIST', 'link' => 'host' },
    'hostgroup_name'                => { type => 'LIST', 'link' => 'hostgroup' },
    'inherits_parent'               => { type => 'BOOL' },
    'execution_failure_criteria'    => { type => 'ENUM', values => ['o','d','u','p','n'], keys => [ 'Ok', 'Down', 'Unreachable', 'Pending', 'None' ] },
    'notification_failure_criteria' => { type => 'ENUM', values => ['o','d','u','p','n'], keys => [ 'Ok', 'Down', 'Unreachable', 'Pending', 'None' ] },
    'dependency_period'             => { type => 'STRING', link => 'timeperiod' },

    'host'                          => { type => 'ALIAS', 'name' => 'host_name' },
    'master_host'                   => { type => 'ALIAS', 'name' => 'host_name' },
    'master_host_name'              => { type => 'ALIAS', 'name' => 'host_name' },
    'hostgroup'                     => { type => 'ALIAS', 'name' => 'hostgroup_name' },
    'hostgroups'                    => { type => 'ALIAS', 'name' => 'hostgroup_name' },
    'dependent_hostgroup'           => { type => 'ALIAS', 'name' => 'dependent_hostgroup_name' },
    'dependent_hostgroups'          => { type => 'ALIAS', 'name' => 'dependent_hostgroup_name' },
    'dependent_host'                => { type => 'ALIAS', 'name' => 'dependent_host_name' },
    'notification_failure_options'  => { type => 'ALIAS', 'name' => 'notification_failure_criteria' },
    'execution_failure_options'     => { type => 'ALIAS', 'name' => 'execution_failure_criteria' },
};

##########################################################

=head1 METHODS

=head2 BUILD

return new object

=cut
sub BUILD {
    my $class = shift || __PACKAGE__;
    my $self = {
        'type'        => 'hostdependency',
        'primary_key' => [ 'host_name', [ 'hostgroup_name' ] ],
        'default'     => $Monitoring::Config::Object::Hostdependency::Defaults,
    };
    bless $self, $class;
    return $self;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
