package Thruk::Controller::conf;

use strict;
use warnings;
use Thruk::Utils::Menu;
use Thruk::Utils::Conf::Defaults;
use Thruk::Utils::Conf;
use Carp;
use Data::Dumper;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::conf - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

######################################
# add new menu item, but only if user has all of the
# requested roles
Thruk::Utils::Menu::insert_item('System', {
                                    'href'  => '/thruk/cgi-bin/conf.cgi',
                                    'name'  => 'Config Tool',
                                    'roles' => [qw/authorized_for_configuration_information
                                                   authorized_for_system_commands/],
                         });

######################################

=head2 conf_cgi

page: /thruk/cgi-bin/conf.cgi

=cut
sub conf_cgi : Regex('thruk\/cgi\-bin\/conf\.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/conf/index');
}


##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{title}            = 'Config Tool';
    $c->stash->{page}             = 'config';
    $c->stash->{template}         = 'conf.tt';
    $c->stash->{subtitle}         = 'Config Tool';
    $c->stash->{infoBoxTitle}     = 'Config Tool';

    Thruk::Utils::ssi_include($c);

    # check permissions
    return $c->detach('/error/index/8') unless $c->check_user_roles( "authorized_for_configuration_information" );
    return $c->detach('/error/index/8') unless $c->check_user_roles( "authorized_for_system_commands" );

    # check if we have at least one file configured
    if(   !defined $c->config->{'Thruk::Plugin::ConfigTool'}
       or ref($c->config->{'Thruk::Plugin::ConfigTool'}) ne 'HASH'
       or scalar keys %{$c->config->{'Thruk::Plugin::ConfigTool'}} == 0
    ) {
        $c->stash->{conf_config} = {};
        Thruk::Utils::set_message( $c, 'fail_message', 'Config Tool is disabled.<br>Please have a look at the <a href="'.$c->stash->{'url_prefix'}.'thruk/documentation.html#_config_tool">config tool setup instructions</a>.' );
    }

    my $type                 = $c->{'request'}->{'parameters'}->{'type'}   || '';
    my $action               = $c->{'request'}->{'parameters'}->{'action'} || 'show';
    $c->stash->{type}        = $type;
    $c->stash->{action}      = $action;
    $c->stash->{conf_config} = $c->config->{'Thruk::Plugin::ConfigTool'};

    # show settings page
    if($type eq 'cgi') {
        $self->_process_cgi_page($c);
    }
    elsif($type eq 'thruk') {
        $self->_process_thruk_page($c);
    }
    elsif($type eq 'users') {
        $self->_process_users_page($c);
    }

    return 1;
}

##########################################################
# create the cgi.cfg config page
sub _process_cgi_page {
    my( $self, $c ) = @_;

    my $file     = $c->config->{'Thruk::Plugin::ConfigTool'}->{'cgi.cfg'};
    return unless defined $file;
    my $defaults = Thruk::Utils::Conf::Defaults->get_cgi_cfg();

    # save changes
    if($c->stash->{action} eq 'store') {
        my $data = Thruk::Utils::Conf::get_data_from_param($c->{'request'}->{'parameters'}, $defaults);
        # check for empty multi selects
        for my $key (keys %{$defaults}) {
            next if $key !~ m/^authorized_for_/;
            $data->{$key} = [] unless defined $data->{$key};
        }
        $self->_store_changes($c, $file, $data, $defaults);
        return $c->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/conf.cgi?type=cgi");
    }

    my($content, $data, $md5) = Thruk::Utils::Conf::read_conf($file, $defaults);

    my $extra_user = [];
    for my $key (keys %{$data}) {
        next unless $key =~ m/^authorized_for_/mx;
        push @{$extra_user}, @{$data->{$key}->[1]};
    }

    # get list of cgi users
    my $cgi_contacts = Thruk::Utils::Conf::get_cgi_user_list($c, $extra_user);

    for my $key (keys %{$data}) {
        next unless $key =~ m/^authorized_for_/mx;
        $data->{$key}->[2] = $cgi_contacts;
    }

    my $keys = [
        [ 'CGI Settings', [qw/
                        show_context_help
                        use_pending_states
                        refresh_rate
                        escape_html_tags
                        action_url_target
                        notes_url_target
                    /]
        ],
        [ 'Authorization', [qw/
                        use_authentication
                        use_ssl_authentication
                        default_user_name
                        lock_author_names
                        authorized_for_all_services
                        authorized_for_all_hosts
                        authorized_for_all_service_commands
                        authorized_for_all_host_commands
                        authorized_for_system_information
                        authorized_for_system_commands
                        authorized_for_configuration_information
                    /]
        ],
    ];

    $c->stash->{'keys'}     = $keys;
    $c->stash->{'data'}     = $data;
    $c->stash->{'md5'}      = $md5;
    $c->stash->{'subtitle'} = "CGI &amp; Access Configuration";
    $c->stash->{'template'} = 'conf_data.tt';

    return 1;
}

##########################################################
# create the thruk config page
sub _process_thruk_page {
    my( $self, $c ) = @_;

    my $file     = $c->config->{'Thruk::Plugin::ConfigTool'}->{'thruk'};
    return unless defined $file;
    my $defaults = Thruk::Utils::Conf::Defaults->get_thruk_cfg($c);

    # save changes
    if($c->stash->{action} eq 'store') {
        my $data = Thruk::Utils::Conf::get_data_from_param($c->{'request'}->{'parameters'}, $defaults);
        $self->_store_changes($c, $file, $data, $defaults, $c);
        return $c->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/conf.cgi?type=thruk");
    }

    my($content, $data, $md5) = Thruk::Utils::Conf::read_conf($file, $defaults);

    my $keys = [
        [ 'General', [qw/
                        title_prefix
                        use_wait_feature
                        use_frames
                        use_timezone
                        use_strict_host_authorization
                        info_popup_event_type
                        info_popup_options
                        resource_file
                        can_submit_commands
                     /]
        ],
        [ 'Paths', [qw/
                        tmp_path
                        ssi_path
                        plugin_path
                        user_template_path
                    /]
        ],
        [ 'Menu', [qw/
                        start_page
                        documentation_link
                        all_problems_link
                        allowed_frame_links
                    /]
        ],
        [ 'Display', [qw/
                        default_theme
                        strict_passive_mode
                        show_notification_number
                        show_full_commandline
                        shown_inline_pnp
                        statusmap_default_type
                        statusmap_default_groupby
                        datetime_format
                        datetime_format_today
                        datetime_format_long
                        datetime_format_log
                        datetime_format_trends
                    /]
        ],
        [ 'Search', [qw/
                        use_new_search
                        use_ajax_search
                        ajax_search_hosts
                        ajax_search_hostgroups
                        ajax_search_services
                        ajax_search_servicegroups
                    /]
        ],
        [ 'Paging', [qw/
                        use_pager
                        paging_steps
                        group_paging_overview
                        group_paging_summary
                        group_paging_grid
                    /]
        ],
    ];

    $c->stash->{'keys'}     = $keys;
    $c->stash->{'data'}     = $data;
    $c->stash->{'md5'}      = $md5;
    $c->stash->{'subtitle'} = "Thruk Configuration";
    $c->stash->{'template'} = 'conf_data.tt';

    return 1;
}

##########################################################
# create the users config page
sub _process_users_page {
    my( $self, $c ) = @_;

    my $file     = $c->config->{'Thruk::Plugin::ConfigTool'}->{'cgi.cfg'};
    return unless defined $file;
    my $defaults = Thruk::Utils::Conf::Defaults->get_cgi_cfg();

    # save changes to user
    my $user = $c->{'request'}->{'parameters'}->{'data.username'} || '';
    if($user ne '' and defined $file and $c->stash->{action} eq 'store') {
        my $redirect = $c->stash->{'url_prefix'}."thruk/cgi-bin/conf.cgi?action=change&type=users&data.username=".$user;
        my $msg      = $self->_update_password($c);
        if(defined $msg) {
            Thruk::Utils::set_message( $c, 'fail_message', $msg );
            return $c->redirect($redirect);
        }

        # save changes to cgi.cfg
        my($content, $data, $md5) = Thruk::Utils::Conf::read_conf($file, $defaults);
        my $new_data              = {};
        for my $key (keys %{$c->{'request'}->{'parameters'}}) {
            next unless $key =~ m/data\.authorized_for_/;
            $key =~ s/^data\.//gmx;
            my $users = {};
            for my $usr (@{$data->{$key}->[1]}) {
                $users->{$usr} = 1;
            }
            if($c->{'request'}->{'parameters'}->{'data.'.$key}) {
                $users->{$user} = 1;
            } else {
                delete $users->{$user};
            }
            @{$new_data->{$key}} = sort keys %{$users};
        }
        $self->_store_changes($c, $file, $new_data, $defaults);

        Thruk::Utils::set_message( $c, 'success_message', 'User saved successfully' );
        return $c->redirect($redirect);
    }

    $c->stash->{'show_user'}  = 0;
    $c->stash->{'user_name'}  = '';

    if($c->stash->{action} eq 'change' and $user ne '') {
        my($content, $data, $md5) = Thruk::Utils::Conf::read_conf($file, $defaults);
        $c->stash->{'show_user'}  = 1;
        my($name, $alias)         = split(/\ \-\ /mx,$user, 2);
        $c->stash->{'user_name'}  = $name;
        $c->stash->{'md5'}        = $md5;
        $c->stash->{'roles'}      = {};
        my $roles = [qw/authorized_for_all_services
                        authorized_for_all_hosts
                        authorized_for_all_service_commands
                        authorized_for_all_host_commands
                        authorized_for_system_information
                        authorized_for_system_commands
                        authorized_for_configuration_information
                    /];
        $c->stash->{'role_keys'}  = $roles;
        for my $role (@{$roles}) {
            $c->stash->{'roles'}->{$role} = 0;
            for my $tst (@{$data->{$role}->[1]}) {
                $c->stash->{'roles'}->{$role}++ if $tst eq $name;
            }
        }
    }

    $c->stash->{'subtitle'} = "User Configuration";
    $c->stash->{'template'} = 'conf_data_users.tt';

    return 1;
}


##########################################################
# update a users password
sub _update_password {
    my ( $self, $c ) = @_;

    my $user = $c->{'request'}->{'parameters'}->{'data.username'};
    if(defined $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'}) {
        my $pass1 = $c->{'request'}->{'parameters'}->{'data.password'}  || '';
        my $pass2 = $c->{'request'}->{'parameters'}->{'data.password2'} || '';
        if($pass1 ne '') {
            if($pass1 eq $pass2) {
                $pass1 =~ s/'/\'/gmx;
                $user  =~ s/'/\'/gmx;
                my $create = -s $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'} ? '' : '-c ';
                my $cmd    = sprintf("%s -b %s '%s' '%s' '%s' 2>&1",
                                        '$(which htpasswd2 2>/dev/null || which htpasswd 2>/dev/null)',
                                        $create,
                                        $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'},
                                        $user,
                                        $pass1
                                    );
                $c->log->debug( "running cmd: ". $cmd );
                my $output = qx( $cmd );
                my $rc     = $?>>8;
                if($rc != 0) {
                    $c->log->error( "cmd:    ". $cmd );
                    $c->log->error( "rc:     ". $rc );
                    $c->log->error( "output: ". $output );
                    return( 'failed to update password, check the logfile!' );
                }
                $c->log->debug( "rc:     ". $rc );
                $c->log->debug( "output: ". $output );
            } else {
                return( 'Passwords do not match' );
            }
        }
    }
    return;
}


##########################################################
# store changes to a file
sub _store_changes {
    my ( $self, $c, $file, $data, $defaults, $update_in_conf ) = @_;
    my $old_md5 = $c->{'request'}->{'parameters'}->{'md5'} || '';
    $c->log->debug("saving config changes to ".$file);
    my $res     = Thruk::Utils::Conf::update_conf($file, $data, $old_md5, $defaults, $update_in_conf);
    if(defined $res) {
        Thruk::Utils::set_message( $c, 'fail_message', $res );
    } else {
        Thruk::Utils::set_message( $c, 'success_message', 'Saved successfully' );
    }
    return;
}

=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
