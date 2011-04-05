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
# add new menu item
Thruk::Utils::Menu::insert_item('System', {
                           'href' => '/thruk/cgi-bin/conf.cgi',
                           'name' => 'Config Tool',
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

    my $type = $c->{'request'}->{'parameters'}->{'type'} || '';
    $c->stash->{type} = $type;

    my $action = $c->{'request'}->{'parameters'}->{'action'} || 'show';
    $c->stash->{action} = $action;

    # which file to change
    my($file, $defaults, $update_in_conf);
    if($type eq 'access') {
        $file           = $c->config->{'cgi.cfg'};
        $defaults       = Thruk::Utils::Conf::Defaults->get_cgi_cfg();
    }
    elsif($type eq 'cgi') {
        $file           = $c->config->{'cgi.cfg'};
        $defaults       = Thruk::Utils::Conf::Defaults->get_cgi_cfg();
    }
    elsif($type eq 'thruk') {
        $file           = 'thruk_local.conf';
        $defaults       = Thruk::Utils::Conf::Defaults->get_thruk_cfg($c);
        $update_in_conf = $c;
    }

    if(defined $file and $c->stash->{action} eq 'store') {
        my $old_md5 = $c->{'request'}->{'parameters'}->{'md5'} || '';
        my $new_dat = Thruk::Utils::Conf::get_data_from_param($c->{'request'}->{'parameters'}, $defaults);
        my $res     = Thruk::Utils::Conf::update_conf($file, $new_dat, $old_md5, $defaults, $update_in_conf);
        if(defined $res) {
            Thruk::Utils::set_message( $c, 'fail_message', $res );
        }
        Thruk::Utils::set_message( $c, 'success_message', 'Saved successfully' );
        return $c->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/conf.cgi?type=".$type);
    }

    # show settings page
    if($type eq 'access') {
        $self->_process_access_page($c, $file, $defaults);
    }
    elsif($type eq 'cgi') {
        $self->_process_cgi_page($c, $file, $defaults);
    }
    elsif($type eq 'thruk') {
        $self->_process_thruk_page($c, $file, $defaults);
    }

    return 1;
}

##########################################################
# create the access config page
sub _process_access_page {
    my( $self, $c, $file, $defaults ) = @_;

    my($content, $data, $md5) = Thruk::Utils::Conf::read_conf($file, $defaults);

    my $keys = [qw/
                use_authentication
                use_ssl_authentication
                default_user_name
                authorized_for_all_services
                authorized_for_all_hosts
                authorized_for_all_service_commands
                authorized_for_all_host_commands
                authorized_for_system_information
                authorized_for_system_commands
                authorized_for_configuration_information
                lock_author_names
               /];

    $c->stash->{'keys'}     = $keys;
    $c->stash->{'data'}     = $data;
    $c->stash->{'md5'}      = $md5;
    $c->stash->{'subtitle'} = "User &amp; Access Configuration";
    $c->stash->{'template'} = 'conf_data.tt';

    return 1;
}

##########################################################
# create the cgi config page
sub _process_cgi_page {
    my( $self, $c, $file, $defaults ) = @_;

    my($content, $data, $md5) = Thruk::Utils::Conf::read_conf($file, $defaults);

    my $keys = [qw/
                show_context_help
                use_pending_states
                refresh_rate
                escape_html_tags
                action_url_target
                notes_url_target
               /];

    $c->stash->{'keys'}     = $keys;
    $c->stash->{'data'}     = $data;
    $c->stash->{'md5'}      = $md5;
    $c->stash->{'subtitle'} = "CGI Configuration";
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
    $c->stash->{'template'} = 'conf_data_thruk.tt';

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
