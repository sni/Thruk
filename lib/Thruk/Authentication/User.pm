package Thruk::Authentication::User;

use warnings;
use strict;
use Carp qw/confess/;
use Cpanel::JSON::XS ();

use Thruk::Utils ();
use Thruk::Utils::Auth ();
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::Authentication::User - Authenticate a remote user configured using a cgi.cfg

=head1 DESCRIPTION

This module allows you to authenticate the users.

=head1 METHODS

=head2 new

create a new C<Thruk::Authentication::User> object.

 Thruk::Authentication::User->new();

=cut

sub new {
    my($class, $c, $username, $sessiondata, $superuser, $internal) = @_;
    my $self = {};
    bless $self, $class;

    confess("no username") unless defined $username;

    $self->{'username'}          = $username;
    $self->{'roles'}             = [];
    $self->{'groups'}            = [];
    $self->{'alias'}             = undef;
    $self->{'roles_from_groups'} = {};
    $self->{'superuser'}         = $superuser ? 1 : 0;
    $self->{'internal'}          = $internal  ? 1 : 0;

    # add roles from cgi_conf
    for my $role (@{$Thruk::Constants::possible_roles}) {
        next unless defined $c->config->{$role};
        for my $member (@{$c->config->{$role}}) {
            if(Thruk::Base::wildcard_match($username, $member)) {
                push @{$self->{'roles'}}, $role;
                last;
            }
        }
    }
    $self->{'roles_from_cgi_cfg'} = Thruk::Base::array2hash($self->{'roles'});

    $self->{'roles_from_session'} = {};
    if($sessiondata && $sessiondata->{'roles'}) {
        push @{$self->{'roles'}}, @{$sessiondata->{'roles'}};
        $self->{'roles_from_session'} = Thruk::Base::array2hash($sessiondata->{'roles'});
    }

    $self->{'roles'} = Thruk::Base::array_uniq($self->{'roles'});

    # Is this user internal or an admin user?
    if($self->{'internal'} || $self->check_user_roles('admin')) {
        $self->grant('admin');
        $self->{'can_submit_commands'}     = 1;
        $self->{'can_submit_commands_src'} = "admin role";
    }

    # ex.: user settings from var/users/<name>
    $self->{settings} = $self->{'internal'} ? {} : Thruk::Utils::get_user_data($c, $username);

    if($self->{'internal'} && !$self->{'timestamp'}) {
        $self->{'timestamp'}        = time();
        $self->{'contact_src_peer'} = [];
    }

    return $self;
}

########################################

=head2 set_dynamic_attributes

  set_dynamic_attributes($c, [$skip_db_access], [$roles])

sets attributes based on livestatus data

=cut
sub set_dynamic_attributes {
    my($self, $c, $skip_db_access,$roles) = @_;
    $c->stats->profile(begin => "User::set_dynamic_attributes");

    my $username = $self->{'username'};
    confess("no username") unless defined $username;

    # internal technical users do not have any dynamic attributes
    if($self->{'internal'}) {
        $self->clean_roles($roles);
        $c->stats->profile(end => "User::set_dynamic_attributes");
        return $self;
    }

    my $data;
    if($skip_db_access) {
        _debug("using cached user data") if Thruk::Base->verbose;
        $data = $c->cache->get->{'users'}->{$username} || {};
        if($data->{'contactgroups'} && ref $data->{'contactgroups'} eq 'HASH') {
            $data->{'contactgroups'} = [sort keys %{$data->{'contactgroups'}}];
        }
    } else {
        _debug("fetching user data from livestatus") if Thruk::Base->verbose;
        my($alias, $email, $can_submit_commands, $groups,$src_peers) = $self->_fetch_user_data($c);
        $data->{'alias'}                   = $alias               if defined $alias;
        $data->{'email'}                   = $email               if defined $email;
        $data->{'can_submit_commands'}     = $can_submit_commands if defined $can_submit_commands;
        $data->{'can_submit_commands_src'} = "set as contact attribute" if defined $can_submit_commands;
        $data->{'contact_src_peer'}        = $src_peers;
        $data->{'contactgroups'}           = $groups              if defined $groups;
        $data->{'timestamp'}               = time();
    }

    $self->_apply_user_data($c, $data);

    $self->{'alias'}                   = $data->{'alias'} // $self->{'alias'};
    $self->{'email'}                   = $data->{'email'} // $self->{'email'};
    $self->{'roles_from_groups'}       = $data->{'roles_by_group'};
    $self->{'groups'}                  = $data->{'contactgroups'} || [];
    $self->{'can_submit_commands'}     = $data->{'can_submit_commands'};
    $self->{'can_submit_commands_src'} = $data->{'can_submit_commands_src'};
    $self->{'contact_src_peer'}        = $data->{'contact_src_peer'} // [];
    $self->{'timestamp'}               = $data->{'timestamp'};
    for my $role (@{$data->{'roles'}}) {
        push @{$self->{'roles'}}, $role;
    }

    $self->clean_roles($roles);

    if($self->check_user_roles('admin')) {
        $self->grant('admin');
    }

    $self->{'roles'} = Thruk::Base::array_uniq($self->{'roles'});

    if(!$skip_db_access) {
        $c->cache->set('users', $username, $data);
    }

    $c->stats->profile(end => "User::set_dynamic_attributes");
    return $self;
}

########################################

=head2 clean_roles

  clean_roles($roles)

limit roles to given list (using the intersection of user roles and list)

=cut
sub clean_roles {
    my($self, $roles) = @_;
    return($self->{'roles'}) unless defined $roles;

    my $readonly;
    if($self->check_user_roles('authorized_for_read_only')) {
        $readonly = 1;
        push @{$roles}, 'authorized_for_read_only';
    }

    my $cleaned_roles = [];
    for my $r (@{$roles}) {
        if($self->check_role_permissions($r)) {
            push @{$cleaned_roles}, $r;
        }
    }
    $self->{'roles'} = Thruk::Base::array_uniq($cleaned_roles);

    # update read-only flag
    if($readonly || $self->check_user_roles('authorized_for_read_only')) {
        $self->{'can_submit_commands'}     = 0;
        $self->{'can_submit_commands_src'} = "read_only role";
    }

    # clean role origins
    my $roles_hash = Thruk::Base::array2hash($cleaned_roles);
    for my $key (qw/roles_from_cgi_cfg roles_from_session/) {
        next unless $self->{$key};
        for my $k2 (sort keys %{$self->{$key}}) {
            delete $self->{$key}->{$k2} unless $roles_hash->{$k2};
        }
    }

    return($self->{'roles'});
}

########################################
sub _fetch_user_data {
    my($self, $c) = @_;

    # is the contact allowed to send commands?
    my($can_submit_commands,$alias,$email);
    my $src_peers = [];
    confess("no db") unless $c->db();
    my $data = $c->db->get_can_submit_commands($self->{'username'});
    if(defined $data) {
        for my $dat (@{$data}) {
            $alias = $dat->{'alias'} if defined $dat->{'alias'};
            $email = $dat->{'email'} if defined $dat->{'email'};
            if(defined $dat->{'can_submit_commands'} && (!defined $can_submit_commands || $dat->{'can_submit_commands'} == 0)) {
                $can_submit_commands = $dat->{'can_submit_commands'};
                push @{$src_peers} , $dat->{'peer_key'};
            }
        }
    }

    # add roles from groups in cgi.cfg
    my $groups = [sort keys %{$c->db->get_contactgroups_by_contact($self->{'username'})}];

    return($alias, $email, $can_submit_commands, $groups, $src_peers);
}

########################################
sub _apply_user_data {
    my($self, $c, $data) = @_;

    my $can_submit_commands     = $data->{'can_submit_commands'};
    my $can_submit_commands_src = $data->{'can_submit_commands_src'};
    if(!defined $can_submit_commands) {
        $can_submit_commands     = $c->config->{'can_submit_commands'} || 0;
        $can_submit_commands_src = "config default";
    }

    my $roles  = [];
    my $roles_by_group = {};
    for my $key (@{$Thruk::Constants::possible_roles}) {
        my $role = $key;
        $role =~ s/^authorized_for_/authorized_contactgroup_for_/gmx;

        next unless defined $c->config->{$role};

        # make group=* work, even if contact does not have any group
        for my $testgroup (@{$c->config->{$role}}) {
            if($testgroup eq '*') {
                push @{$roles_by_group->{$key}}, '*';
                push @{$roles}, $key;
            }
        }

        # check groups against roles
        for my $contactgroup (@{$data->{'contactgroups'}}) {
            for my $testgroup (@{$c->config->{$role}}) {
                if(Thruk::Base::wildcard_match($contactgroup, $testgroup)) {
                    $roles_by_group->{$key} = [] unless defined $roles_by_group->{$key};
                    push @{$roles_by_group->{$key}}, $contactgroup;
                    push @{$roles}, $key;
                    last;
                }
            }
        }
    }

    # override can_submit_commands from cgi.cfg
    if(grep /authorized_for_all_host_commands/mx, @{$roles}) {
        $can_submit_commands     = 1;
        $can_submit_commands_src = "all_host_commands role";
    }
    elsif(grep /authorized_for_all_service_commands/mx, @{$roles}) {
        $can_submit_commands     = 1;
        $can_submit_commands_src = "all_service_commands role";
    }
    elsif(grep /authorized_for_system_commands/mx, @{$roles}) {
        $can_submit_commands     = 1;
        $can_submit_commands_src = "system_commands role";
    }
    elsif(grep /authorized_for_read_only/mx, @{$roles}) {
        # read_only role already supplied via cgi.cfg, enforce
        $can_submit_commands = 0;
        $can_submit_commands_src = "read only role";
    }

    _debug("can_submit_commands: $can_submit_commands");
    if($can_submit_commands != 1) {
        if(!grep /authorized_for_read_only/mx, @{$roles}) {
            push @{$roles}, 'authorized_for_read_only';
        }
    }

    $data->{'roles'}                   = Thruk::Base::array_uniq($roles);
    $data->{'can_submit_commands'}     = $can_submit_commands;
    $data->{'can_submit_commands_src'} = $can_submit_commands_src;
    $data->{'roles_by_group'}          = $roles_by_group;

    return;
}

=head2 get

get user attribute

 get($attribute)

=cut

sub get {
    my($self, $attr) = @_;
    return($self->{$attr});
}

=head2 is_locked

  is_locked()

returns true if user is locked

=cut

sub is_locked {
    my($self) = @_;
    if($self->{'settings'}->{'login'} && $self->{'settings'}->{'login'}->{'locked'}) {
        return(1);
    }
    return(0);
}

=head2 check_user_roles

 check_user_roles(<$role>)

 returns 1 if user has all given roles.

 for example:
  $c->user->check_user_roles('admin')
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
    my @found = grep(/^\Q$role\E$/mx, @{$self->{'roles'}});
    return 1 if scalar @found >= 1;

    if($role eq 'admin') {
        if($self->check_user_roles('authorized_for_admin')) {
            return(1);
        }
        if($self->check_user_roles('authorized_for_system_commands') && $self->check_user_roles('authorized_for_configuration_information')) {
            return(1);
        }
    }
    return(0);
}

=head2 check_permissions

 check_permissions('host', $hostname)
 check_permissions('service', $servicename, $hostname)
 check_permissions('hostgroup', $hostgroupname)
 check_permissions('servicegroup', $servicegroupname)
 check_permissions(contact', $contactname)
 check_permissions(contactgroup', $contactgroupname)

 for example:
 $c->check_permissions('service', $service, $host)

=cut

sub check_permissions {
    my($self, $c, $type, $value, $value2, $value3) = @_;

    return 1 if $c->check_user_roles('authorized_for_admin');

    $type   = '' unless defined $type;
    $value  = '' unless defined $value;
    $value2 = '' unless defined $value2;

    my $count = 0;
    if($type eq 'host') {
        my $hosts = $c->db->get_host_names(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts', $value2), name => $value ]);
        $count = 1 if defined $hosts && scalar @{$hosts} > 0;
    }
    elsif($type eq 'service') {
        my $services = $c->db->get_service_names(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services', $value3), description => $value, host_name => $value2 ]);
        $count = 1 if defined $services && scalar @{$services} > 0;
    }
    elsif($type eq 'host_services') {
        my $services1 = $c->db->get_service_names(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services', $value2), host_name => $value ]);
        my $services2 = $c->db->get_service_names(filter => [                                                               host_name => $value ]);
        # authorization permitted when the amount of services is the same number as services with authorization
        $count = 1 if defined $services1 && defined $services2 && scalar @{$services1} == scalar @{$services2};
    }
    elsif($type eq 'hostgroup') {
        my $hosts1 = $c->db->get_host_names(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts', $value2), groups => { '>=' => $value } ]);
        my $hosts2 = $c->db->get_host_names(filter => [ groups => { '>=' => $value } ]);
        $count = 0;
        # authorization permitted when the amount of hosts is the same number as hosts with authorization
        if(defined $hosts1 && defined $hosts2 && scalar @{$hosts1} == scalar @{$hosts2} && scalar @{$hosts1} != 0) {
            $count = 1;
        }
    }
    elsif($type eq 'servicegroup') {
        my $services1 = $c->db->get_service_names(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services', $value3), groups => { '>=' => $value } ]);
        my $services2 = $c->db->get_service_names(filter => [ groups => { '>=' => $value } ]);
        $count = 0;
        # authorization permitted when the amount of services is the same number as services with authorization
        if(defined $services1 && defined $services2 && scalar @{$services1} == scalar @{$services2} && scalar @{$services1} != 0) {
            $count = 1;
        }
    }
    elsif($type eq 'contact') {
        if($value eq $c->user->{'username'}) {
            $count = 1;
        }
    }
    elsif($type eq 'contactgroup') {
        # admin privileges are checked already, so if we reach this point, the user is no admin
        # so simply deny access to contactgroups
        $count = 0;
    }
    else {
        $c->error("unknown auth role check: ".$type);
        return 0;
    }
    $count = 0 unless defined $count;
    _debug("count: ".$count);
    if($count > 0) {
        _debug("check_permissions('".$type."', '".$value."', '".$value2."') -> access granted");
        return 1;
    }
    _debug("check_permissions('".$type."', '".$value."', '".$value2."') -> access denied");
    return 0;
}

=head2 check_cmd_permissions

 check_cmd_permissions('system')
 check_cmd_permissions('host', $hostname)
 check_cmd_permissions('all_hosts')
 check_cmd_permissions('service', $servicename, $hostname)
 check_cmd_permissions('host_services', $hostname)
 check_cmd_permissions('all_services')
 check_cmd_permissions('hostgroup', $hostgroupname)
 check_cmd_permissions('servicegroup', $servicegroupname)
 check_cmd_permissions('contact', $contactname)
 check_cmd_permissions('contactgroup', $contactgroupname)

 for example:
 $c->check_cmd_permissions('service', $service, $host)

=cut

sub check_cmd_permissions {
    my($self, $c, $type, $value, $value2) = @_;

    $type   = '' unless defined $type;
    $value  = '' unless defined $value;
    $value2 = '' unless defined $value2;

    return 0 if $self->check_user_roles('authorized_for_read_only');
    return 0 if !$self->{'can_submit_commands'};
    return 1 if $self->check_user_roles('authorized_for_admin');

    if($type eq 'system') {
        return 1 if $self->check_user_roles('authorized_for_system_commands');
    }
    elsif($type eq 'host') {
        return 1 if $self->check_user_roles('authorized_for_all_host_commands');
        return 1 if $self->check_permissions($c, 'host', $value, 1);
    }
    elsif($type eq 'hostgroup') {
        return 1 if $self->check_user_roles('authorized_for_all_host_commands');
        return 1 if $self->check_permissions($c, 'hostgroup', $value, 1);
    }
    elsif($type eq 'all_hosts') {
        return 1 if $self->check_user_roles('authorized_for_all_host_commands');
    }
    elsif($type eq 'service') {
        return 1 if $self->check_user_roles('authorized_for_all_service_commands');
        return 1 if $self->check_permissions($c, 'service', $value, $value2, 1);
    }
    elsif($type eq 'host_services') {
        return 1 if $self->check_user_roles('authorized_for_all_service_commands');
        return 1 if $self->check_permissions($c, 'host_services', $value, 1);
    }
    elsif($type eq 'all_services') {
        return 1 if $self->check_user_roles('authorized_for_all_service_commands');
    }
    elsif($type eq 'servicegroup') {
        return 1 if $self->check_user_roles('authorized_for_all_service_commands');
        return 1 if $self->check_permissions($c, 'servicegroup', $value, 1);
    }
    elsif($type eq 'contact') {
        return 1 if $self->check_permissions($c, 'contact', $value, 1);
    }
    elsif($type eq 'contactgroup') {
        return 1 if $self->check_permissions($c, 'contactgroup', $value, 1);
    }
    else {
        $c->error("unknown cmd auth role check: ".$type);
        return 0;
    }
    return 0;
}

=head2 check_role_permissions

 check_role_permissions($role)

 returns 1 if user is allowed to use given role. Don't mix up with check_user_roles()

=cut

sub check_role_permissions {
    my($self, $role) = @_;
    return 1 if $role eq 'authorized_for_read_only';
    return 1 if $self->check_user_roles('admin');
    return 1 if $self->check_user_roles($role);
    return 0;
}

=head2 transform_username

run transformation rules for username

 transform_username($config, $username, [$c])

=cut

sub transform_username {
    my($config, $username, $c) = @_;

    return $username if(!defined $username || $username eq '');

    # change case?
    $username = lc($username) if $config->{'make_auth_user_lowercase'};
    $username = uc($username) if $config->{'make_auth_user_uppercase'};

    # regex replace?
    if($config->{'make_auth_replace_regex'}) {
        _debug("authentication regex replace before: ".$username) if $c;
        ## no critic
        eval('$username =~ '.$config->{'make_auth_replace_regex'});
        ## use critic
        _error("authentication regex replace error: ".$@) if ($c && $@);
        _debug("authentication regex replace after : ".$username) if $c;
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
        $self->{'roles'} = [@{$Thruk::Constants::possible_roles}];
        # remove read only role
        $self->{'roles'} = [ grep({ $_ ne 'authorized_for_read_only' } @{$self->{'roles'}}) ];
    } else {
        confess('role '.$role.' not implemented');
    }
    return;
}

=head2 has_group

 has_group(<$group>)

 returns 1 if user has all given groups.

 for example:
  $c->user->has_group('Admin')
  $c->user->has_group(['Admin', 'Location XY'])

=cut

sub has_group {
    my($self, $groups) = @_;
    my $groups_hash = Thruk::Base::array2hash($self->{'groups'});
    $groups = Thruk::Base::list($groups);
    for my $g (@{$groups}) {
        return(0) unless defined $groups_hash->{$g};
    }
    return(1);
}

=head2 js_data

 js_data()

 returns user data exposed to javascript

=cut

sub js_data {
    my($self) = @_;
    return({
        name                => $self->{'username'},
        groups              => $self->{'groups'},
        roles               => $self->{'roles'},
        can_submit_commands => $self->{'can_submit_commands'} ? Cpanel::JSON::XS::true  : Cpanel::JSON::XS::false,
        readonly            => $self->{'can_submit_commands'} ? Cpanel::JSON::XS::false : Cpanel::JSON::XS::true,
    });
}

1;
