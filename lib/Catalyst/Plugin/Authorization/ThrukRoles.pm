package Catalyst::Plugin::Authorization::ThrukRoles;

=head1 NAME

Catalyst::Plugin::Authorization::ThrukRoles - Authorization for monitoring objects like host/services...

=head1 SYNOPSIS

    use Catalyst qw/
        Authorization::ThrukRoles
    /;


=head1 DESCRIPTION

This authorization module provides authorization for monitoring objects like host/services.

=cut

use strict;
use warnings;

use base qw/Catalyst::Plugin::Authorization::Roles/;

=head1 METHODS

=head2 check_permissions

 check_permissions('host', $hostname)
 check_permissions('service', $servicename, $hostname)
 check_permissions('hostgroup', $hostgroupname)
 check_permissions('servicegroup', $servicegroupname)

 for example:
 $c->check_permissions('service', $service, $host)

=cut

sub check_permissions {
    my($c, $type, $value, $value2, $value3) = @_;

    $type   = '' unless defined $type;
    $value  = '' unless defined $value;
    $value2 = '' unless defined $value2;

    my $count = 0;
    if($type eq 'host') {
        my $hosts = $c->{'db'}->get_host_names(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts', $value2), name => $value ]);
        $count = 1 if defined $hosts and scalar @{$hosts} > 0;
    }
    elsif($type eq 'service') {
        my $services = $c->{'db'}->get_service_names(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services', $value3), description => $value, host_name => $value2 ]);
        $count = 1 if defined $services and scalar @{$services} > 0;
    }
    elsif($type eq 'hostgroup') {
        my $hosts1 = $c->{'db'}->get_host_names(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts', $value2), groups => { '>=' => $value } ]);
        my $hosts2 = $c->{'db'}->get_host_names(filter => [ groups => { '>=' => $value } ]);
        $count = 0;
        # authorization permitted when the amount of hosts is the same number as hosts with authorization
        if(defined $hosts1 and defined $hosts2 and scalar @{$hosts1} == scalar @{$hosts2} and scalar @{$hosts1} != 0) {
            $count = 1;
        }
    }
    elsif($type eq 'servicegroup') {
        my $services1 = $c->{'db'}->get_service_names(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services', $value3), groups => { '>=' => $value } ]);
        my $services2 = $c->{'db'}->get_service_names(filter => [ groups => { '>=' => $value } ]);
        $count = 0;
        # authorization permitted when the amount of services is the same number as services with authorization
        if(defined $services1 and defined $services2 and scalar @{$services1} == scalar @{$services2} and scalar @{$services1} != 0) {
            $count = 1;
        }
    }
    else {
        $c->error("unknown auth role check: ".$type);
        return 0;
    }
    $count = 0 unless defined $count;
    $c->log->debug("count: ".$count);
    if($count > 0) {
        $c->log->debug("check_permissions('".$type."', '".$value."', '".$value2."') -> access granted");
        return 1;
    }
    $c->log->debug("check_permissions('".$type."', '".$value."', '".$value2."') -> access denied");
    return 0;
}

=head2 check_cmd_permissions

 check_cmd_permissions('system')
 check_cmd_permissions('host', $hostname)
 check_cmd_permissions('service', $servicename, $hostname)
 check_cmd_permissions('hostgroup', $hostgroupname)
 check_cmd_permissions('servicegroup', $servicegroupname)

 for example:
 $c->check_cmd_permissions('service', $service, $host)

=cut

sub check_cmd_permissions {
    my($c, $type, $value, $value2) = @_;

    $type   = '' unless defined $type;
    $value  = '' unless defined $value;
    $value2 = '' unless defined $value2;

    return if $c->check_user_roles('is_authorized_for_read_only');

    if($type eq 'system') {
        return 1 if $c->check_user_roles('authorized_for_system_commands');
    }
    elsif($type eq 'host') {
        return 1 if $c->check_user_roles('authorized_for_all_host_commands');
        return 1 if $c->check_permissions('host', $value, 1);
    }
    elsif($type eq 'hostgroup') {
        return 1 if $c->check_user_roles('authorized_for_all_host_commands');
        return 1 if $c->check_permissions('hostgroup', $value, 1);
    }
    elsif($type eq 'service') {
        return 1 if $c->check_user_roles('authorized_for_all_service_commands');
        return 1 if $c->check_permissions('service', $value, $value2, 1);
    }
    elsif($type eq 'servicegroup') {
        return 1 if $c->check_user_roles('authorized_for_all_service_commands');
        return 1 if $c->check_permissions('servicegroup', $value, 1);
    }
    else {
        $c->error("unknown cmd auth role check: ".$type);
        return 0;
    }
    return 0;
}

1;
