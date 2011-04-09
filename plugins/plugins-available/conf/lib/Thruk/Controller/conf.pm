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

    return $c->detach('/error/index/8') unless $c->check_user_roles( "authorized_for_configuration_information" );
    return $c->detach('/error/index/8') unless $c->check_user_roles( "authorized_for_system_commands" );

    my $type = $c->{'request'}->{'parameters'}->{'type'} || '';
    $c->stash->{type} = $type;

    my $action = $c->{'request'}->{'parameters'}->{'action'} || 'show';
    $c->stash->{action} = $action;

    # which file to change
    my($file, $defaults, $update_in_conf);
    if($type eq 'cgi') {
        $file           = $c->config->{'cgi.cfg'};
        $defaults       = Thruk::Utils::Conf::Defaults->get_cgi_cfg();
    }
    elsif($type eq 'thruk') {
        $file           = 'thruk_local.conf';
        $defaults       = Thruk::Utils::Conf::Defaults->get_thruk_cfg($c);
        $update_in_conf = $c;
    }
    elsif($type eq 'users') {
        $file           = $c->config->{'cgi.cfg'};
        $defaults       = Thruk::Utils::Conf::Defaults->get_cgi_cfg();
    }

    # save changes
    if(defined $file and $c->stash->{action} eq 'store') {
        my $old_md5 = $c->{'request'}->{'parameters'}->{'md5'} || '';
        my $new_dat = Thruk::Utils::Conf::get_data_from_param($c->{'request'}->{'parameters'}, $defaults);
        $c->log->debug("saving config changes to ".$file);
        my $res     = Thruk::Utils::Conf::update_conf($file, $new_dat, $old_md5, $defaults, $update_in_conf);
        if(defined $res) {
            Thruk::Utils::set_message( $c, 'fail_message', $res );
        } else {
            Thruk::Utils::set_message( $c, 'success_message', 'Saved successfully' );
        }
        return $c->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/conf.cgi?type=".$type);
    }

    # show settings page
    if($type eq 'cgi') {
        $self->_process_cgi_page($c, $file, $defaults);
    }
    elsif($type eq 'thruk') {
        $self->_process_thruk_page($c, $file, $defaults);
    }
    elsif($type eq 'users') {
        $self->_process_users_page($c, $file, $defaults);
    }

    return 1;
}

##########################################################
# create the cgi.cfg config page
sub _process_cgi_page {
    my( $self, $c, $file, $defaults ) = @_;

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
    my( $self, $c, $file, $defaults ) = @_;

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
    my( $self, $c, $file, $defaults ) = @_;

    $c->stash->{'show_user'}  = 0;
    $c->stash->{'user_name'}  = '';

    my $action = $c->{'request'}->{'parameters'}->{'action'}        || '';
    my $user   = $c->{'request'}->{'parameters'}->{'data.username'} || '';
    if($action eq 'change' and $user ne '') {
        my($content, $data, $md5) = Thruk::Utils::Conf::read_conf($file, $defaults);
        $c->stash->{'show_user'}  = 1;
        my($name, $alias)         = split(/\ \-\ /mx,$user, 2);
        $c->stash->{'user_name'}  = $name;
        $c->stash->{'md5'}        = $md5;
        $c->stash->{'roles'}      = {
                        authorized_for_all_services                 => 0,
                        authorized_for_all_hosts                    => 0,
                        authorized_for_all_service_commands         => 0,
                        authorized_for_all_host_commands            => 0,
                        authorized_for_system_information           => 0,
                        authorized_for_system_commands              => 0,
                        authorized_for_configuration_information    => 0,
        };
        for my $role (keys %{$c->stash->{'roles'}}) {
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

=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
