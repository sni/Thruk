package Thruk::Authentication::User;

=head1 NAME

Thruk::Authentication::User - Authenticate a remote user configured using a cgi.cfg

=head1 SYNOPSIS

use Thruk::Authentication::User

=head1 DESCRIPTION

This module allows you to authenticate the users.

=cut

use strict;
use warnings;
use File::Slurp qw/read_file/;

=head1 METHODS

=head2 new

create a new C<Thruk::Authentication::User> object.

 Thruk::Authentication::User->new();

=cut

sub new {
    my($class, $c, $username) = @_;
    my $self = {};
    bless $self, $class;

    my $env = $c->env;

    # authenticated by ssl
    if(defined $username) {
    }

    # authenticate by secret.key from http header
    elsif($c->req->header('X-Thruk-Auth-Key')) {
        my $secret_file = $c->config->{'var_path'}.'/secret.key';
        $c->config->{'secret_key'}  = read_file($secret_file) if -s $secret_file;
        chomp($c->config->{'secret_key'});
        if($c->req->header('X-Thruk-Auth-Key') ne $c->config->{'secret_key'}) {
            $c->error("wrong authentication key");
            return;
        }
        $username = $c->req->header('X-Thruk-Auth-User') || $c->config->{'cgi_cfg'}->{'default_user_name'};
    }

    elsif(defined $c->config->{'cgi_cfg'}->{'use_ssl_authentication'} and $c->config->{'cgi_cfg'}->{'use_ssl_authentication'} >= 1
        and defined $env->{'SSL_CLIENT_S_DN_CN'}) {
            $username = $env->{'SSL_CLIENT_S_DN_CN'};
    }
    # from cli
    elsif(defined $c->stash->{'remote_user'} and $c->stash->{'remote_user'} ne '?') {
        $username = $c->stash->{'remote_user'};
    }
    # basic authentication
    elsif(defined $env->{'REMOTE_USER'} and $env->{'REMOTE_USER'} ne '' ) {
        $username = $env->{'REMOTE_USER'};
    }
    elsif(defined $ENV{'REMOTE_USER'}and $ENV{'REMOTE_USER'} ne '' ) {
        $username = $ENV{'REMOTE_USER'};
    }

    # default_user_name?
    elsif(defined $c->config->{'cgi_cfg'}->{'default_user_name'}) {
        $username = $c->config->{'cgi_cfg'}->{'default_user_name'};
    }

    elsif(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'CLI') {
        $username = $c->config->{'default_cli_user_name'};
    }

    if(!defined $username || $username eq '') {
        return;
    }

    # transform username upper/lower case?
    $username = transform_username($c->config, $username, $c);

    $self->{'username'}      = $username;
    $self->{'roles'}         = [];
    $self->{'alias'}         = undef;

    # add roles from cgi_conf
    my $possible_roles = [
                      'authorized_for_all_host_commands',
                      'authorized_for_all_hosts',
                      'authorized_for_all_service_commands',
                      'authorized_for_all_services',
                      'authorized_for_configuration_information',
                      'authorized_for_system_commands',
                      'authorized_for_system_information',
                      'authorized_for_read_only',
                    ];
    for my $role (@{$possible_roles}) {
        if(defined $c->config->{'cgi_cfg'}->{$role}) {
            my %contacts = map { $_ => 1 } split/\s*,\s*/mx, $c->config->{'cgi_cfg'}->{$role};
            push @{$self->{'roles'}}, $role if ( defined $contacts{$username} or defined $contacts{'*'} );
        }
    }
    $self->{'roles'} = Thruk::Utils::array_uniq($self->{'roles'});

    if($username eq '(cron)' || $username eq '(cli)') {
        $self->grant('admin');
    }

    return $self;
}

=head2 get

get user attribute

 get($attribute)

=cut

sub get {
    my($self, $attr) = @_;
    return($self->{$attr});
}

=head2 check_user_roles

 check_user_roles(<$role>)

 for example:
 $c->user->check_user_roles('authorized_for_all_services')
 $c->user->check_user_roles(['authorized_for_system_commands', 'authorized_for_configuration_information'])

=cut

sub check_user_roles {
    my($self, $role) = @_;
    if(ref $role eq 'ARRAY') {
        for my $r (@{$role}) {
            if(!$self->check_user_roles($r)) {
                return(0);
            }
        }
        return(1);
    }
    if($role eq 'admin') {
        if($self->check_user_roles('authorized_for_system_commands') && $self->check_user_roles('authorized_for_configuration_information')) {
            return(1);
        }
        return(0);
    }
    my @found = grep(/^\Q$role\E$/mx, @{$self->{'roles'}});
    return(scalar @found);
}

=head2 check_permissions

 check_permissions('host', $hostname)
 check_permissions('service', $servicename, $hostname)
 check_permissions('hostgroup', $hostgroupname)
 check_permissions('servicegroup', $servicegroupname)

 for example:
 $c->check_permissions('service', $service, $host)

=cut

sub check_permissions {
    my($self, $c, $type, $value, $value2, $value3) = @_;

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
    my($self, $c, $type, $value, $value2) = @_;

    $type   = '' unless defined $type;
    $value  = '' unless defined $value;
    $value2 = '' unless defined $value2;

    return 0 if $c->check_user_roles('authorized_for_read_only');

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

=head2 transform_username

run transformation rules for username

 transform_username($config, $username, [$c])

=cut

sub transform_username {
    my($config, $username, $c) = @_;

    # change case?
    $username = lc($username) if $config->{'make_auth_user_lowercase'};
    $username = uc($username) if $config->{'make_auth_user_uppercase'};

    # regex replace?
    if($config->{'make_auth_replace_regex'}) {
        $c->log->debug("authentication regex replace before: ".$username) if $c;
        ## no critic
        eval('$username =~ '.$config->{'make_auth_replace_regex'});
        ## use critic
        $c->log->error("authentication regex replace error: ".$@) if ($c && $@);
        $c->log->debug("authentication regex replace after : ".$username) if $c;
    }
    return($username);
}

=head2 grant

    grant('role')

grant role to user

=cut

sub grant {
    my($self, $role) = @_;
    if($role eq 'admin') {
        $self->{'roles'} = [qw/authorized_for_all_hosts
                               authorized_for_all_host_commands
                               authorized_for_all_services
                               authorized_for_all_service_commands
                               authorized_for_configuration_information
                               authorized_for_system_commands
                               authorized_for_system_information
                           /];
    } else {
        confess('role '.$role.' not implemented');
    }
    return;
}

1;
