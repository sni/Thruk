package Thruk::Controller::conf;

use strict;
use warnings;
use Thruk 1.1.1;
use Thruk::Utils::Menu;
use Thruk::Utils::Conf;
use Thruk::Utils::Conf::Defaults;
use Monitoring::Config;
use Carp;
use File::Copy;
use JSON::XS;
use parent 'Catalyst::Controller';
use Storable qw/dclone/;

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
    return if defined $c->{'canceled'};
    return $c->detach('/conf/index');
}


##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    # make private _ hash keys available
    $Template::Stash::PRIVATE = undef;

    $c->stash->{'no_auto_reload'}      = 1;
    $c->stash->{title}                 = 'Config Tool';
    $c->stash->{page}                  = 'config';
    $c->stash->{template}              = 'conf.tt';
    $c->stash->{subtitle}              = 'Config Tool';
    $c->stash->{infoBoxTitle}          = 'Config Tool';

    Thruk::Utils::ssi_include($c);

    # check permissions
    return $c->detach('/error/index/8') unless $c->check_user_roles( "authorized_for_configuration_information" );
    return $c->detach('/error/index/8') unless $c->check_user_roles( "authorized_for_system_commands" );

    # check if we have at least one file configured
    if(   !defined $c->config->{'Thruk::Plugin::ConfigTool'}
       or ref($c->config->{'Thruk::Plugin::ConfigTool'}) ne 'HASH'
       or scalar keys %{$c->config->{'Thruk::Plugin::ConfigTool'}} == 0
    ) {
        Thruk::Utils::set_message( $c, 'fail_message', 'Config Tool is disabled.<br>Please have a look at the <a href="'.$c->stash->{'url_prefix'}.'thruk/documentation.html#_component_thruk_plugin_configtool">config tool setup instructions</a>.' );
    }

    my $subcat                = $c->{'request'}->{'parameters'}->{'sub'} || '';
    my $action                = $c->{'request'}->{'parameters'}->{'action'}  || 'show';
    $c->stash->{sub}          = $subcat;
    $c->stash->{action}       = $action;
    $c->stash->{conf_config}  = $c->config->{'Thruk::Plugin::ConfigTool'} || {};
    $c->stash->{has_obj_conf} = scalar keys %{_get_backends_with_obj_config($c)};

    if($action eq 'cgi_contacts') {
        return $self->_process_cgiusers_page($c);
    }
    elsif($action eq 'json') {
        return $self->_process_json_page($c);
    }

    # show settings page
    if($subcat eq 'cgi') {
        $self->_process_cgi_page($c);
    }
    elsif($subcat eq 'thruk') {
        $self->_process_thruk_page($c);
    }
    elsif($subcat eq 'users') {
        $self->_process_users_page($c);
    }
    elsif($subcat eq 'objects') {
        $self->_process_objects_page($c);
    }

    return 1;
}


##########################################################
# return json list for ajax search
sub _process_json_page {
    my( $self, $c ) = @_;

    return unless $self->_update_objects_config($c);

    my $type = $c->{'request'}->{'parameters'}->{'type'} || 'hosts';
    $type    =~ s/s$//gmxo;

    # icons?
    if($type eq 'icon') {
        my $objects = [];
        my $themes_dir = $c->config->{'themes_path'} || $c->config->{'home'}."/themes";
        my $dir        = $c->config->{'physical_logo_path'} || $themes_dir."/themes-available/Thruk/images/logos";
        $dir =~ s/\/$//gmx;
        my $files = _find_files($c, $dir, '\.(png|gif|jpg)$');
        for my $file (@{$files}) {
            $file =~ s/$dir\///gmx;
            push @{$objects}, $file." - ".$c->stash->{'logo_path_prefix'}.$file;
        }
        my $json            = [ { 'name' => $type.'s', 'data' => $objects } ];
        $c->stash->{'json'} = $json;
        $c->forward('Thruk::View::JSON');
        return;
    }

    my $json;
    my $objects   = [];
    my $templates = [];
    my $filter    = $c->{'request'}->{'parameters'}->{'filter'};
    if(defined $filter) {
        my $types   = {};
        my $objects = $c->{'obj_db'}->get_objects_by_type($type,$filter);
        for my $subtype (keys %{$objects}) {
            for my $name (keys %{$objects->{$subtype}}) {
                $types->{$subtype}->{$name} = 1;
            }
        }
        for my $typ (sort keys %{$types}) {
            push @{$json}, {
                  'name' => $self->_translate_type($typ)."s",
                  'data' => [ sort keys %{$types->{$typ}} ],
            };
        }
    } else {
        for my $dat (@{$c->{'obj_db'}->get_objects_by_type($type)}) {
            push @{$objects}, $dat->get_long_name();
        }
        for my $dat (@{$c->{'obj_db'}->get_templates_by_type($type)}) {
            push @{$templates}, $dat->get_template_name();
        }
        $json = [ { 'name' => $type.'s',
                    'data' => [ sort @{Thruk::Utils::array_uniq($objects)} ],
                  },
                  { 'name' => 'templates',
                    'data' => [ sort @{Thruk::Utils::array_uniq($templates)} ],
                  }
                ];
    }
    $c->stash->{'json'} = $json;
    $c->forward('Thruk::View::JSON');
    return;
}


##########################################################
# create the cgi.cfg config page
sub _process_cgiusers_page {
    my( $self, $c ) = @_;

    my $contacts        = Thruk::Utils::Conf::get_cgi_user_list($c);
    delete $contacts->{'*'}; # we dont need this user here
    my $data            = [ values %{$contacts} ];
    my $json            = [ { 'name' => "contacts", 'data' => $data } ];
    $c->stash->{'json'} = $json;
    $c->forward('Thruk::View::JSON');
    return;
}


##########################################################
# create the cgi.cfg config page
sub _process_cgi_page {
    my( $self, $c ) = @_;

    my $file     = $c->config->{'Thruk::Plugin::ConfigTool'}->{'cgi.cfg'};
    return unless defined $file;

    # create a default config from the current used cgi.cfg
    if(!-e $file and $file ne $c->config->{'cgi.cfg_effective'}) {
        copy($c->config->{'cgi.cfg_effective'}, $file) or die('cannot copy '.$c->config->{'cgi.cfg_effective'}.' to '.$file.': '.$!);
    }

    my $defaults = Thruk::Utils::Conf::Defaults->get_cgi_cfg();

    # save changes
    if($c->stash->{action} eq 'store') {
        my $data = Thruk::Utils::Conf::get_data_from_param($c->{'request'}->{'parameters'}, $defaults);
        # check for empty multi selects
        for my $key (keys %{$defaults}) {
            next if $key !~ m/^authorized_for_/mx;
            $data->{$key} = [] unless defined $data->{$key};
        }
        $self->_store_changes($c, $file, $data, $defaults);
        return $c->response->redirect('conf.cgi?sub=cgi');
    }

    my($content, $data, $md5) = Thruk::Utils::Conf::read_conf($file, $defaults);

    # get list of cgi users
    my $cgi_contacts = Thruk::Utils::Conf::get_cgi_user_list($c);

    for my $key (keys %{$data}) {
        next unless $key =~ m/^authorized_for_/mx;
        $data->{$key}->[2] = $cgi_contacts;
    }

    # get list of cgi users
    my $cgi_groups = Thruk::Utils::Conf::get_cgi_group_list($c);
    for my $key (keys %{$data}) {
        next unless $key =~ m/^authorized_contactgroup_for_/mx;
        $data->{$key}->[2] = $cgi_groups;
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
                        authorized_for_read_only
                    /]
        ],
        [ 'Authorization Groups', [qw/
                      authorized_contactgroup_for_all_services
                      authorized_contactgroup_for_all_hosts
                      authorized_contactgroup_for_all_service_commands
                      authorized_contactgroup_for_all_host_commands
                      authorized_contactgroup_for_system_information
                      authorized_contactgroup_for_system_commands
                      authorized_contactgroup_for_configuration_information
                      authorized_contactgroup_for_read_only
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
        return $c->response->redirect('conf.cgi?sub=thruk');
    }

    my($content, $data, $md5) = Thruk::Utils::Conf::read_conf($file, $defaults);

    my $keys = [
        [ 'General', [qw/
                        title_prefix
                        use_wait_feature
                        wait_timeout
                        use_frames
                        use_timezone
                        use_strict_host_authorization
                        show_long_plugin_output
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
                        show_modified_attributes
                        statusmap_default_type
                        statusmap_default_groupby
                        datetime_format
                        datetime_format_today
                        datetime_format_long
                        datetime_format_log
                        datetime_format_trends
                        use_new_command_box
                        show_custom_vars
                    /]
        ],
        [ 'Search', [qw/
                        use_new_search
                        use_ajax_search
                        ajax_search_hosts
                        ajax_search_hostgroups
                        ajax_search_services
                        ajax_search_servicegroups
                        ajax_search_timeperiods
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
        my $redirect = 'conf.cgi?action=change&sub=users&data.username='.$user;
        my $msg      = $self->_update_password($c);
        if(defined $msg) {
            Thruk::Utils::set_message( $c, 'fail_message', $msg );
            return $c->response->redirect($redirect);
        }

        # save changes to cgi.cfg
        my($content, $data, $md5) = Thruk::Utils::Conf::read_conf($file, $defaults);
        my $new_data              = {};
        for my $key (keys %{$c->{'request'}->{'parameters'}}) {
            next unless $key =~ m/data\.authorized_for_/mx;
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
        return $c->response->redirect($redirect);
    }

    $c->stash->{'show_user'}  = 0;
    $c->stash->{'user_name'}  = '';

    if($c->stash->{action} eq 'change' and $user ne '') {
        my($content, $data, $md5) = Thruk::Utils::Conf::read_conf($file, $defaults);
        my($name, $alias)         = split(/\ \-\ /mx,$user, 2);
        $c->stash->{'show_user'}  = 1;
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

        $c->stash->{'has_htpasswd_entry'} = 0;
        if(defined $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'}) {
            my $htpasswd = Thruk::Utils::Conf::read_htpasswd($c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'});
            $c->stash->{'has_htpasswd_entry'} = 1 if defined $htpasswd->{$name};
        }

        $c->stash->{'has_contact'} = 0;
        my $contacts = $c->{'db'}->get_contacts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'contact' ), name => $name ] );
        if(defined $contacts and scalar @{$contacts} >= 1) {
            $c->stash->{'has_contact'} = 1;
        }

    }

    $c->stash->{'subtitle'} = "User Configuration";
    $c->stash->{'template'} = 'conf_data_users.tt';

    return 1;
}


##########################################################
# create the objects config page
sub _process_objects_page {
    my( $self, $c ) = @_;

    return unless $self->_update_objects_config($c);

    $c->stash->{'subtitle'}        = "Object Configuration";
    $c->stash->{'template'}        = 'conf_objects.tt';
    $c->stash->{'file_link'}       = "";

    # apply changes?
    if(defined $c->{'request'}->{'parameters'}->{'apply'}) {
        return $self->_apply_config_changes($c);
    }

    # get object from params
    my $obj = $self->_get_context_object($c);
    if(defined $obj) {

        # revert all changes from one file
        if($c->stash->{action} eq 'revert') {
            return if $self->_object_revert($c, $obj);
        }

        # save this object
        elsif($c->stash->{action} eq 'store') {
            return if $self->_object_save($c, $obj);
        }

        # delete this object
        elsif($c->stash->{action} eq 'delete') {
            return if $self->_object_delete($c, $obj);
        }

        # move objects
        elsif(   $c->stash->{action} eq 'move'
              or $c->stash->{action} eq 'movefile') {
            return if $self->_object_move($c, $obj);
        }

        # clone this object
        elsif($c->stash->{action} eq 'clone') {
            $obj = $self->_object_clone($c, $obj);
        }
    }

    # create new object
    if($c->stash->{action} eq 'new') {
        $obj = $self->_object_new($c);
    }

    # browse files
    elsif($c->stash->{action} eq 'browser') {
        return if $self->_file_browser($c);
    }

    # file editor
    elsif($c->stash->{action} eq 'editor') {
        return if $self->_file_editor($c);
    }

    # save changed files from editor
    elsif($c->stash->{action} eq 'savefile') {
        return if $self->_file_save($c);
    }

    # delete files/folders from browser
    elsif($c->stash->{action} eq 'deletefiles') {
        return if $self->_file_delete($c);
    }

    # undelete files/folders from browser
    elsif($c->stash->{action} eq 'undeletefiles') {
        return if $self->_file_undelete($c);
    }

    # set type and name of object
    if(defined $obj) {
        $c->stash->{'show_object'}    = 1;
        $c->stash->{'object'}         = $obj;
        $c->stash->{'data_name'}      = $obj->get_name();
        $c->stash->{'type'}           = $obj->get_type();
        $c->stash->{'used_templates'} = $obj->get_used_templates($c->{'obj_db'});
        $c->stash->{'file_link'}      = $obj->{'file'}->{'path'} if defined $obj->{'file'};
    }

    # set default type for start page
    if($c->stash->{action} eq 'show' and $c->stash->{type} eq '') {
        $c->stash->{type} = 'host';
    }

    $c->stash->{'needs_commit'}    = $c->{'obj_db'}->{'needs_commit'};
    $c->stash->{'needs_reload'}    = $c->{'obj_db'}->{'needs_reload'};
    return 1;
}


##########################################################
# apply config changes
sub _apply_config_changes {
    my ( $self, $c ) = @_;

    $c->stash->{'output'}        = '';
    $c->stash->{'changed_files'} = $c->{'obj_db'}->get_changed_files();

    # get diff of changed files
    if(defined $c->{'request'}->{'parameters'}->{'diff'}) {
        for my $file (@{$c->stash->{'changed_files'}}) {
            $c->stash->{'output'} .= "<hr><pre>\n";
            $c->stash->{'output'} .= Thruk::Utils::Filter::html_escape($file->diff());
            $c->stash->{'output'} .= "</pre><br>\n";
        }
    }

    # config check
    elsif(defined $c->{'request'}->{'parameters'}->{'check'}) {
        if(defined $c->stash->{'peer_conftool'}->{'obj_check_cmd'}) {
            if($self->_cmd($c, $c->stash->{'peer_conftool'}->{'obj_check_cmd'})) {
                Thruk::Utils::set_message( $c, 'success_message', "config check successfully" );
            } else {
                Thruk::Utils::set_message( $c, 'fail_message', "config check failed!" );
            }
        } else {
            Thruk::Utils::set_message( $c, 'fail_message', "please set 'obj_check_cmd' in your thruk_local.conf" );
        }
    }

    # config reload
    elsif(defined $c->{'request'}->{'parameters'}->{'reload'}) {
        if(defined $c->stash->{'peer_conftool'}->{'obj_reload_cmd'}) {
            if($self->_cmd($c, $c->stash->{'peer_conftool'}->{'obj_reload_cmd'})) {
                $c->{'obj_db'}->{'needs_reload'} = 0;
                Thruk::Utils::set_message( $c, 'success_message', "reload successfully" );
            } else {
                Thruk::Utils::set_message( $c, 'fail_message', "reload failed!" );
            }
        } else {
            Thruk::Utils::set_message( $c, 'fail_message', "please set 'obj_reload_cmd' in your thruk_local.conf" );
        }
    }

    # save changes to file
    elsif(defined $c->{'request'}->{'parameters'}->{'save'}) {
        $c->{'obj_db'}->commit();
        Thruk::Utils::set_message( $c, 'success_message', 'Changes saved to disk successfully' );
        return $c->response->redirect('conf.cgi?sub=objects&apply=yes');
    }

    # make nicer output
    if(   defined $c->{'request'}->{'parameters'}->{'check'}
       or defined $c->{'request'}->{'parameters'}->{'reload'}) {
        $c->{'stash'}->{'output'} =~ s/(Error:.*)$/<b><font color="red">$1<\/font><\/b>/gmx;
        $c->{'stash'}->{'output'} =~ s/(Warning:.*)$/<b><font color="#FFA500">$1<\/font><\/b>/gmx;
        $c->{'stash'}->{'output'} =~ s/(CONFIG\s+ERROR.*)$/<b><font color="red">$1<\/font><\/b>/gmx;
        $c->{'stash'}->{'output'} =~ s/(\(config\s+file\s+'(.*?)',\s+starting\s+on\s+line\s+(\d+)\))/<a href="conf.cgi?sub=objects&amp;file=$2&amp;line=$3">$1<\/a>/gmx;
        $c->{'stash'}->{'output'} =~ s/\s+in\s+file\s+'(.*?)'\s+on\s+line\s+(\d+)/ in file <a href="conf.cgi?sub=objects&amp;type=file&amp;file=$1&amp;line=$2">'$1' on line $2<\/a>/gmx;
        $c->{'stash'}->{'output'} =~ s/\s+in\s+(\w+)\s+'(.*?)'/ in $1 '<a href="conf.cgi?sub=objects&amp;type=$1&amp;data.name=$2">$2<\/a>'/gmx;
        $c->{'stash'}->{'output'} = "<pre>".$c->{'stash'}->{'output'}."</pre>";
    }
    elsif(defined $c->{'request'}->{'parameters'}->{'diff'}) {
        $c->{'stash'}->{'output'} =~ s/^\-\-\-(.*)$/<font color="#0776E8"><b>---$1<\/b><\/font>/gmx;
        $c->{'stash'}->{'output'} =~ s/^\+\+\+(.*)$//gmx;
        $c->{'stash'}->{'output'} =~ s/^\@\@(.*)$/<font color="#0776E8"><b>\@\@$1<\/b><\/font>/gmx;
        $c->{'stash'}->{'output'} =~ s/^\-(.*)$/<font color="red">-$1<\/font>/gmx;
        $c->{'stash'}->{'output'} =~ s/^\+(.*)$/<font color="green">+$1<\/font>/gmx;
    }

    $c->stash->{'needs_commit'}    = $c->{'obj_db'}->{'needs_commit'};
    $c->stash->{'needs_reload'}    = $c->{'obj_db'}->{'needs_reload'};
    $c->stash->{'files'}           = $c->{'obj_db'}->get_files();
    $c->stash->{'subtitle'}        = "Apply Config Changes";
    $c->stash->{'template'}        = 'conf_objects_apply.tt';
    return;
}

##########################################################
# update a users password
sub _update_password {
    my ( $self, $c ) = @_;

    my $user = $c->{'request'}->{'parameters'}->{'data.username'};
    my $send = $c->{'request'}->{'parameters'}->{'send'} || 'save';
    if(defined $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'}) {
        # remove password?
        if($send eq 'remove password') {
            my $cmd = sprintf("%s -D %s '%s' 2>&1",
                                 '$(which htpasswd2 2>/dev/null || which htpasswd 2>/dev/null)',
                                 $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'},
                                 $user
                             );
            if($self->_cmd($c, $cmd)) {
                $c->log->info("removed password for ".$user);
                return;
            }
            return( 'failed to remove password, check the logfile!' );
        }

        # change password?
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
                if($self->_cmd($c, $cmd)) {
                    $c->log->info("changed password for ".$user);
                    return;
                }
                return( 'failed to update password, check the logfile!' );
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

##########################################################
# execute cmd
sub _cmd {
    my ( $self, $c, $cmd ) = @_;

    local $SIG{CHLD}='';
    $c->log->debug( "running cmd: ". $cmd );
    my $rc = $?;
    my $output = `$cmd 2>&1`;
    if($? == -1) {
        $output .= "[".$!."]";
    } else {
        $rc = $?>>8;
    }
    $c->{'stash'}->{'output'} = $output;
    $c->log->debug( "rc:          ". $rc );
    $c->log->debug( "output:      ". $output );
    if($rc != 0) {
        return 0;
    }
    return 1;
}


##########################################################
sub _update_objects_config {
    my ( $self, $c ) = @_;

    return unless $c->stash->{has_obj_conf};

    my $refresh = $c->{'request'}->{'parameters'}->{'refresh'} || 0;

    $c->stats->profile(begin => "objects init");
    my $model                    = $c->model('Objects');
    my $peer_conftool            = $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'configtool'};
    $c->stash->{'peer_conftool'} = $peer_conftool;

    # already parsed?
    if($model->cache_exists($c->stash->{'param_backend'})) {
        $c->{'obj_db'} = $model->init($c->stash->{'param_backend'}, $peer_conftool);
    }
    # currently parsing
    elsif(my $id = $model->currently_parsing($c->stash->{'param_backend'})) {
        $c->response->redirect("job.cgi?job=".$id);
        return 0;
    } else {
        # need to parse complete objects
        if(scalar keys %{$c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'configtool'}} > 0) {
            my $id = Thruk::Utils::External::perl($c, { expr    => 'Thruk::Utils::Conf::read_objects($c)',
                                                        message => 'please stand by while reading the configuration files...',
                                                        forward => $c->request->uri()
                                                       }
                                                );
            $model->currently_parsing($c->stash->{'param_backend'}, $id);
            $c->response->redirect("job.cgi?job=".$id);
        }
        return 0;
    }
    $c->stats->profile(end => "objects init");


    if($c->{'obj_db'}->{'cached'}) {
        $c->stats->profile(begin => "checking objects");
        $c->{'obj_db'}->check_files_changed($refresh);
        $c->stats->profile(end => "checking objects");
    }

    if(scalar @{$c->{'obj_db'}->{'errors'}} > 0) {
        $c->{'obj_db'}->{'errors_displayed'} = 1;
        my $error = 'found '.(scalar @{$c->{'obj_db'}->{'errors'}}).' errors in object configuration!';
        if($c->{'obj_db'}->{'needs_update'}) {
            $error = 'Config has been changed externally. Need to <a href="'.Thruk::Utils::Filter::uri_with($c, { 'refresh' => 1 }).'">refresh</a> objects.';
        }
        Thruk::Utils::set_message( $c,
                                  'fail_message',
                                  $error,
                                  $c->{'obj_db'}->{'errors'}
                                );
    } elsif($refresh) {
        Thruk::Utils::set_message( $c, 'success_message', 'refresh successful');
    }

    return 1;
}


##########################################################
sub _find_files {
    my $c     = shift;
    my $dir   = shift;
    my $types = shift;
    my $files = $c->{'obj_db'}->_get_files_for_folder($dir, $types);
    return $files;
}


##########################################################
sub _get_backends_with_obj_config {
    my $c        = shift;
    my $backends = {};
    my $firstpeer;
    $c->stash->{'param_backend'} = '';
    for my $peer (@{$c->{'db'}->get_peers()}) {
        $c->stash->{'backend_detail'}->{$peer->{'key'}}->{'disabled'} = 6;
        if(scalar keys %{$peer->{'configtool'}} > 0) {
            $firstpeer = $peer->{'key'} unless defined $firstpeer;
            $backends->{$peer->{'key'}} = $peer->{'configtool'}
        } else {
            $c->stash->{'backend_detail'}->{$peer->{'key'}}->{'disabled'} = 5;
        }
    }
    if(defined $c->request->cookie('thruk_conf')) {
        for my $val (@{$c->request->cookie('thruk_conf')->{'value'}}) {
            next unless defined $c->stash->{'backend_detail'}->{$val};
            $c->stash->{'param_backend'} = $val;
        }
    }
    if($c->stash->{'param_backend'} eq '' and defined $firstpeer) {
        $c->stash->{'param_backend'} = $firstpeer;
    }
    if($c->stash->{'param_backend'} and defined $c->stash->{'backend_detail'}->{$c->stash->{'param_backend'}}) {
        $c->stash->{'backend_detail'}->{$c->stash->{'param_backend'}}->{'disabled'} = 7;
    }
    $c->stash->{'backend_chooser'} = 'switch';
    return $backends;
}


##########################################################
sub _get_context_object {
    my $self  = shift;
    my $c     = shift;
    my $obj;

    $c->stash->{'type'}          = $c->{'request'}->{'parameters'}->{'type'}       || '';
    $c->stash->{'subcat'}        = $c->{'request'}->{'parameters'}->{'subcat'}     || 'config';
    $c->stash->{'data_name'}     = $c->{'request'}->{'parameters'}->{'data.name'}  || '';
    $c->stash->{'data_name2'}    = $c->{'request'}->{'parameters'}->{'data.name2'} || '';
    $c->stash->{'data_id'}       = $c->{'request'}->{'parameters'}->{'data.id'}    || '';
    $c->stash->{'file_name'}     = $c->{'request'}->{'parameters'}->{'file'};
    $c->stash->{'file_line'}     = $c->{'request'}->{'parameters'}->{'line'};
    $c->stash->{'data_name'}     =~ s/^(.*)\ \-\ .*$/$1/gmx;
    $c->stash->{'show_object'}   = 0;
    $c->stash->{'show_secondary_select'} = 0;

    # new object
    if($c->stash->{'data_id'} and $c->stash->{'data_id'} eq 'new') {
        $obj = Monitoring::Config::Object->new( type => $c->stash->{'type'} );
        my $files_root = $self->_set_files_stash($c);
        my $new_file   = $c->{'request'}->{'parameters'}->{'data.file'} || '';
        $new_file      =~ s/^\///gmx;
        my $file       = $c->{'obj_db'}->get_file_by_path($files_root.$new_file);
        if(defined $file) {
            $obj->{'file'} = $file;
        } else {
            # new file
            my $file = Monitoring::Config::File->new($files_root.$new_file, $c->{'obj_db'}->{'config'}->{'obj_readonly'});
            if(defined $file and $file->{'readonly'}) {
                Thruk::Utils::set_message( $c, 'fail_message', 'Failed to create new file: file matches readonly pattern' );
                return $obj;
            }
            elsif(defined $file) {
                $file->{'is_new_file'} = 1;
                $file->{'changed'}     = 1;
                $obj->{'file'}         = $file;
                $c->{'obj_db'}->file_add($file);
            }
            else {
                Thruk::Utils::set_message( $c, 'fail_message', 'Failed to create new file: invalid path' );
                return $obj;
            }
        }
        $obj->set_uniq_id($c->{'obj_db'});
        return $obj;
    }

    # object by id
    if($c->stash->{'data_id'}) {
        $obj = $c->{'obj_db'}->get_object_by_id($c->stash->{'data_id'});
    }

    # link from file to an object?
    if(!defined $obj && defined $c->stash->{'file_name'} && defined $c->stash->{'file_line'}) {
        $obj = $c->{'obj_db'}->get_object_by_location($c->stash->{'file_name'}, $c->stash->{'file_line'});
        unless(defined $obj) {
            Thruk::Utils::set_message( $c, 'fail_message', 'No such object found in this file' );
        }
    }

    # object by name
    my @objs;
    if(!defined $obj && $c->stash->{'data_name'} ) {
        my $objs = $c->{'obj_db'}->get_objects_by_name($c->stash->{'type'}, $c->stash->{'data_name'}, 0, $c->stash->{'data_name2'});
        if(defined $objs->[1]) {
            @objs = @{$objs};
            $c->stash->{'show_secondary_select'} = 1;
        }
        elsif(defined $objs->[0]) {
            $obj = $objs->[0];
        }
    }

    return $obj;
}

##########################################################
sub _translate_type {
    my $self = shift;
    my $type = shift;
    my $tt   = {
        'host_name'      => 'host',
        'hostgroup_name' => 'hostgroup',
    };
    return $tt->{$type} if defined $type;
    return;
}

##########################################################
sub _files_to_path {
    my $self   = shift;
    my $c      = shift;
    my $files  = shift;
    my $folder = { 'dirs' => {}, 'files' => {}, 'path' => '', 'date' => '' };

    for my $file (@{$files}) {
        my @parts    = split(/\//mx, $file->{'path'});
        my $filename = pop @parts;
        my $subdir = $folder;
        for my $dir (@parts) {
            $dir = $dir."/";
            my @stat = stat($subdir->{'path'}.$dir);
            $subdir->{'dirs'}->{$dir} = {
                                         'dirs'  => {},
                                         'files' => {},
                                         'path'  => $subdir->{'path'}.$dir,
                                         'date'  => Thruk::Utils::Filter::date_format($c, $stat[9]),
                                        } unless defined $subdir->{'dirs'}->{$dir};
            $subdir = $subdir->{'dirs'}->{$dir};
        }
        $subdir->{'files'}->{$filename} = {
                                           'date'    => Thruk::Utils::Filter::date_format($c, $file->{'mtime'}),
                                           'deleted' => $file->{'deleted'},
                                        };
    }

    while(scalar keys %{$folder->{'files'}} == 0 && scalar keys %{$folder->{'dirs'}} == 1) {
        my @subdirs = keys %{$folder->{'dirs'}};
        my $dir = shift @subdirs;
        $folder = $folder->{'dirs'}->{$dir};
    }

    return($folder);
}

##########################################################
sub _set_files_stash {
    my $self = shift;
    my $c    = shift;

    my $all_files  = $c->{'obj_db'}->get_files();
    my $files_tree = $self->_files_to_path($c, $all_files);
    my $files_root = $files_tree->{'path'};
    my @filenames;
    for my $file (@{$all_files}) {
        my $filename = $file->{'path'};
        $filename    =~ s/^$files_root/\//gmx;
        push @filenames, $filename;
    }

    $c->stash->{'filenames_json'} = encode_json([{ name => 'files', data => [ sort @filenames ]}]);
    $c->stash->{'files_json'}     = encode_json($files_tree);
    return $files_root;
}

##########################################################
sub _object_revert {
    my $self = shift;
    my $c    = shift;
    my $obj  = shift;

    my $id = $obj->get_id();
    if(-e $obj->{'file'}->{'path'}) {
        my $oldobj;
        my $tmpfile = Monitoring::Config::File->new($obj->{'file'}->{'path'});
        $tmpfile->update_objects();
        for my $o (@{$tmpfile->{'objects'}}) {
            if($id eq $o->get_id()) {
                $oldobj = $o;
                last;
            }
        }
        if(defined $oldobj) {
            $c->{'obj_db'}->update_object($obj, dclone($oldobj->{'conf'}), join("\n", @{$oldobj->{'comments'}}));
            Thruk::Utils::set_message( $c, 'success_message', ucfirst($obj->get_type()).' reverted successfully' );
        }
    }

    return $c->response->redirect('conf.cgi?sub=objects&data.id='.$obj->get_id());
}

##########################################################
sub _object_delete {
    my $self = shift;
    my $c    = shift;
    my $obj  = shift;

    $c->{'obj_db'}->delete_object($obj);
    Thruk::Utils::set_message( $c, 'success_message', ucfirst($c->stash->{'type'}).' removed successfully' );
    return $c->response->redirect('conf.cgi?sub=objects&type='.$c->stash->{'type'});
}

##########################################################
sub _object_save {
    my $self = shift;
    my $c    = shift;
    my $obj  = shift;

    my $data        = $obj->get_data_from_param($c->{'request'}->{'parameters'});
    my $has_changed = $obj->has_object_changed($data);
    my $old_comment = join("\n", @{$obj->{'comments'}});
    my $new_comment = $c->{'request'}->{'parameters'}->{'conf_comment'};
    $new_comment    =~ s/\r//gmx;

    if($has_changed or $new_comment ne $old_comment) {
        # save object
        $c->{'obj_db'}->update_object($obj, $data, $new_comment);
        $c->stash->{'data_name'}   = $obj->get_name();
    }

    # just display the normal edit page if save failed
    if($obj->get_id() eq 'new') {
        $c->stash->{'new_file'} = '';
        $c->stash->{action}     = '';
        return;
    }

    # only save or continue to raw edit?
    if(defined $c->{'request'}->{'parameters'}->{'send'} and $c->{'request'}->{'parameters'}->{'send'} eq 'raw edit') {
        return $c->response->redirect('conf.cgi?sub=objects&action=editor&file='.$obj->{'file'}->{'path'}.'&line='.$obj->{'line'}.'&data.id='.$obj->get_id().'&back=edit');
    } else {
        if($has_changed or $new_comment ne $old_comment) {
            Thruk::Utils::set_message( $c, 'success_message', ucfirst($c->stash->{'type'}).' saved successfully' );
        } else {
            Thruk::Utils::set_message( $c, 'fail_message', ucfirst($c->stash->{'type'}).' did not change' );
        }
        return $c->response->redirect('conf.cgi?sub=objects&data.id='.$obj->get_id());
    }

    return;
}

##########################################################
sub _object_move {
    my $self = shift;
    my $c    = shift;
    my $obj  = shift;

    my $files_root = $self->_set_files_stash($c);
    if($c->stash->{action} eq 'movefile') {
        my $new_file = $c->{'request'}->{'parameters'}->{'newfile'};
        $new_file    =~ s/^\///gmx;
        my $file     = $c->{'obj_db'}->get_file_by_path($files_root.$new_file);
        if(!defined $file) {
            Thruk::Utils::set_message( $c, 'fail_message', $files_root.$new_file." is not a valid file!" );
        } elsif($c->{'obj_db'}->move_object($obj, $file)) {
            Thruk::Utils::set_message( $c, 'success_message', ucfirst($c->stash->{'type'}).' \''.$obj->get_name().'\' moved successfully' );
        } else {
            Thruk::Utils::set_message( $c, 'fail_message', "Failed to move ".ucfirst($c->stash->{'type'}).' \''.$obj->get_name().'\'' );
        }
        return $c->response->redirect('conf.cgi?sub=objects&data.id='.$obj->get_id());
    }
    elsif($c->stash->{action} eq 'move') {
        $c->stash->{'template'}  = 'conf_objects_move.tt';
    }
    return;
}

##########################################################
sub _object_clone {
    my $self = shift;
    my $c    = shift;
    my $obj  = shift;

    my $files_root          = $self->_set_files_stash($c);
    $c->stash->{'new_file'} = $obj->{'file'}->{'path'};
    $c->stash->{'new_file'} =~ s/^$files_root/\//gmx;
    $obj = Monitoring::Config::Object->new(
                                        type => $obj->get_type(),
                                        conf => $obj->{'conf'},
                                       );
    return $obj;
}


##########################################################
sub _object_new {
    my $self = shift;
    my $c    = shift;

    $self->_set_files_stash($c);
    $c->stash->{'new_file'} = '';
    my $obj = Monitoring::Config::Object->new(type => $c->stash->{'type'}, name => $c->stash->{'data_name'});
    return $obj;
}


##########################################################
sub _file_delete {
    my $self = shift;
    my $c    = shift;
    my $path = $c->{'request'}->{'parameters'}->{'path'} || '';
    $path    =~ s/^\#//gmx;

    my $files = $c->{'request'}->{'parameters'}->{'files'};
    for my $filename (ref $files eq 'ARRAY' ? @{$files} : ($files) ) {
        my $file = $c->{'obj_db'}->get_file_by_path($filename);
        if(defined $file) {
            $c->{'obj_db'}->file_delete($file);
        }
    }

    Thruk::Utils::set_message( $c, 'success_message', 'File(s) deleted successfully' );
    return $c->response->redirect('conf.cgi?sub=objects&action=browser#'.$path);
}


##########################################################
sub _file_undelete {
    my $self = shift;
    my $c    = shift;
    my $path = $c->{'request'}->{'parameters'}->{'path'} || '';
    $path    =~ s/^\#//gmx;

    my $files = $c->{'request'}->{'parameters'}->{'files'};
    for my $filename (ref $files eq 'ARRAY' ? @{$files} : ($files) ) {
        my $file = $c->{'obj_db'}->get_file_by_path($filename);
        if(defined $file) {
            $c->{'obj_db'}->file_undelete($file);
        }
    }

    Thruk::Utils::set_message( $c, 'success_message', 'File(s) recoverd successfully' );
    return $c->response->redirect('conf.cgi?sub=objects&action=browser#'.$path);
}


##########################################################
sub _file_save {
    my $self = shift;
    my $c    = shift;

    my $filename = $c->{'request'}->{'parameters'}->{'file'}    || '';
    my $content  = $c->{'request'}->{'parameters'}->{'content'} || '';
    my $lastline = $c->{'request'}->{'parameters'}->{'line'};
    my $file     = $c->{'obj_db'}->get_file_by_path($filename);
    my $lastobj;
    if(defined $file) {
        $lastobj = $file->update_objects_from_text($content, $lastline);
        $c->{'obj_db'}->_rebuild_index();
        my $files_root                   = $self->_set_files_stash($c);
        $c->{'obj_db'}->{'needs_commit'} = 1;
        $c->stash->{'file_name'}         = $file->{'path'};
        $c->stash->{'file_name'}         =~ s/^$files_root//gmx;
        if(scalar @{$file->{'errors'}} > 0) {
            Thruk::Utils::set_message( $c,
                                      'fail_message',
                                      'File '.$c->stash->{'file_name'}.' changed with errors',
                                      $file->{'errors'}
                                    );
        } else {
            Thruk::Utils::set_message( $c, 'success_message', 'File '.$c->stash->{'file_name'}.' changed successfully' );
        }
    } else {
        Thruk::Utils::set_message( $c, 'fail_message', 'File does not exist' );
    }
    if(defined $lastobj) {
        return $c->response->redirect('conf.cgi?sub=objects&data.id='.$lastobj->get_id());
    }
    return $c->response->redirect('conf.cgi?sub=objects&action=browser#'.$file->{'path'});
}

##########################################################
sub _file_editor {
    my $self = shift;
    my $c    = shift;

    my $files_root  = $self->_set_files_stash($c);
    my $filename    = $c->{'request'}->{'parameters'}->{'file'} || '';
    my $file        = $c->{'obj_db'}->get_file_by_path($filename);
    if(defined $file) {
        $c->stash->{'file'}          = $file;
        $c->stash->{'line'}          = $c->{'request'}->{'parameters'}->{'line'} || 1;
        $c->stash->{'back'}          = $c->{'request'}->{'parameters'}->{'back'} || '';
        $c->stash->{'file_link'}     = $file->{'path'};
        $c->stash->{'file_name'}     = $file->{'path'};
        $c->stash->{'file_name'}     =~ s/^$files_root//gmx;
        $c->stash->{'file_content'}  = $file->_get_new_file_content();
        $c->stash->{'template'}      = 'conf_objects_fileeditor.tt';
    } else {
        Thruk::Utils::set_message( $c, 'fail_message', 'File does not exist' );
    }
    return;
}


##########################################################
sub _file_browser {
    my $self = shift;
    my $c    = shift;

    $self->_set_files_stash($c);
    $c->stash->{'template'} = 'conf_objects_filebrowser.tt';
    return;
}
##########################################################

=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
