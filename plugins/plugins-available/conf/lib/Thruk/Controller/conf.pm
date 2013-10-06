package Thruk::Controller::conf;

use strict;
use warnings;
use Thruk 1.1.5;
use Thruk::Utils::Menu;
use Thruk::Utils::Conf;
use Thruk::Utils::Conf::Defaults;
use Monitoring::Config;
use Socket qw/inet_ntoa/;
use Carp;
use File::Copy;
use JSON::XS;
use parent 'Catalyst::Controller';
use Storable qw/dclone/;
use Data::Dumper;
use File::Slurp;
use Encode qw(decode_utf8 encode_utf8);
use Config::General qw(ParseConfig);
use Digest::MD5 qw(md5_hex);

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

# enable config features if this plugin is loaded
Thruk->config->{'use_feature_configtool'} = 1;

######################################

=head2 conf_cgi

page: /thruk/cgi-bin/conf.cgi

=cut
sub conf_cgi : Path('/thruk/cgi-bin/conf.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    $c->stash->{'config_backends_only'} = 1;
    return $c->detach('/conf/index');
}


##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddSafeDefaults') {
    my ( $self, $c ) = @_;

    # check permissions
    unless( $c->check_user_roles( "authorized_for_configuration_information")
        and $c->check_user_roles( "authorized_for_system_commands")) {
        if(    !defined $c->{'db'}
            or !defined $c->{'db'}->{'backends'}
            or ref $c->{'db'}->{'backends'} ne 'ARRAY'
            or scalar @{$c->{'db'}->{'backends'}} == 0 ) {
            # no backends configured or thruk config not possible
            if($c->config->{'Thruk::Plugin::ConfigTool'}->{'thruk'}) {
                return $c->detach("/error/index/14");
            }
        }
        # no permissions at all
        return $c->detach('/error/index/8');
    }

    $c->stash->{'no_auto_reload'}      = 1;
    $c->stash->{title}                 = 'Config Tool';
    $c->stash->{page}                  = 'config';
    $c->stash->{template}              = 'conf.tt';
    $c->stash->{subtitle}              = 'Config Tool';
    $c->stash->{infoBoxTitle}          = 'Config Tool';
    $c->stash->{'last_changed'}        = 0;
    $c->stash->{'needs_commit'}        = 0;
    $c->stash->{'show_save_reload'}    = 0;
    $c->stash->{'has_jquery_ui'}       = 1;

    Thruk::Utils::ssi_include($c);

    # check if we have at least one file configured
    if(   !defined $c->config->{'Thruk::Plugin::ConfigTool'}
       or ref($c->config->{'Thruk::Plugin::ConfigTool'}) ne 'HASH'
       or scalar keys %{$c->config->{'Thruk::Plugin::ConfigTool'}} == 0
    ) {
        Thruk::Utils::set_message( $c, 'fail_message', 'Config Tool is disabled.<br>Please have a look at the <a href="'.$c->stash->{'url_prefix'}.'thruk/documentation.html#_component_thruk_plugin_configtool">config tool setup instructions</a>.' );
    }

    my $subcat                = $c->{'request'}->{'parameters'}->{'sub'} || '';
    my $action                = $c->{'request'}->{'parameters'}->{'action'}  || 'show';

    if(exists $c->{'request'}->{'parameters'}->{'edit'} and defined $c->{'request'}->{'parameters'}->{'host'}) {
        $subcat = 'objects';
    }

    $c->stash->{sub}          = $subcat;
    $c->stash->{action}       = $action;
    $c->stash->{conf_config}  = $c->config->{'Thruk::Plugin::ConfigTool'} || {};
    $c->stash->{has_obj_conf} = scalar keys %{Thruk::Utils::Conf::_get_backends_with_obj_config($c)};

    # set default
    $c->stash->{conf_config}->{'show_plugin_syntax_helper'} = 1 unless defined $c->stash->{conf_config}->{'show_plugin_syntax_helper'};

    if($action eq 'cgi_contacts') {
        return $self->_process_cgiusers_page($c);
    }
    elsif($action eq 'json') {
        return $self->_process_json_page($c);
    }

    # show settings page
    if($subcat eq 'cgi') {
        return if Thruk::Action::AddDefaults::die_when_no_backends($c);
        $self->_process_cgi_page($c);
    }
    elsif($subcat eq 'thruk') {
        $self->_process_thruk_page($c);
    }
    elsif($subcat eq 'users') {
        return if Thruk::Action::AddDefaults::die_when_no_backends($c);
        $self->_process_users_page($c);
    }
    elsif($subcat eq 'plugins') {
        $self->_process_plugins_page($c);
    }
    elsif($subcat eq 'backends') {
        $self->_process_backends_page($c);
    }
    elsif($subcat eq 'objects') {
        $c->stash->{'obj_model_changed'} = 1;
        $self->_process_objects_page($c);
        Thruk::Utils::Conf::store_model_retention($c) if $c->stash->{'obj_model_changed'};
        $c->stash->{'parse_errors'} = $c->{'obj_db'}->{'parse_errors'};
    }

    return 1;
}


##########################################################
# return json list for ajax search
sub _process_json_page {
    my( $self, $c ) = @_;

    return unless Thruk::Utils::Conf::set_object_model($c);

    my $type = $c->{'request'}->{'parameters'}->{'type'} || 'hosts';
    $type    =~ s/s$//gmxo;

    # name resolver
    if($type eq 'dig') {
        my $resolved = 'unknown';
        if(defined $c->{'request'}->{'parameters'}->{'host'} and $c->{'request'}->{'parameters'}->{'host'} ne '') {
            my @addresses = gethostbyname($c->{'request'}->{'parameters'}->{'host'});
            @addresses = map { inet_ntoa($_) } @addresses[4 .. $#addresses];
            if(scalar @addresses > 0) {
                $resolved = join(' ', @addresses);
            }
        }
        my $json            = { 'address' => $resolved };
        $c->stash->{'json'} = $json;
        $c->forward('Thruk::View::JSON');
        return;
    }

    # icons?
    if($type eq 'icon') {
        my $objects = [];
        my $themes_dir = $c->config->{'themes_path'} || $c->config->{'home'}."/themes";
        my $dir        = $c->config->{'physical_logo_path'} || $themes_dir."/themes-available/Thruk/images/logos";
        $dir =~ s/\/$//gmx;
        if(!-d $dir.'/.') {
            # try to create that folder, it might not exist yet
            eval {
                Thruk::Utils::IO::mkdir_r($dir);
            };
        }
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

    # macros
    if($type eq 'macro') {
        # common macros
        my $objects = [
            '$HOSTADDRESS$',
            '$HOSTALIAS$',
            '$HOSTNAME$',
            '$HOSTSTATE$',
            '$HOSTSTATEID$',
            '$HOSTATTEMPT$',
            '$HOSTOUTPUT$',
            '$LONGHOSTOUTPUT$',
            '$HOSTPERFDATA$',
            '$SERVICEDESC$',
            '$SERVICESTATE$',
            '$SERVICESTATEID$',
            '$SERVICESTATETYPE$',
            '$SERVICEATTEMPT$',
            '$SERVICEOUTPUT$',
            '$LONGSERVICEOUTPUT$',
            '$SERVICEPERFDATA$',
        ];
        if(defined $c->{'request'}->{'parameters'}->{'withargs'}) {
            push @{$objects}, ('$ARG1$', '$ARG2$', '$ARG3$', '$ARG4$', '$ARG5$');
        }
        if(defined $c->{'request'}->{'parameters'}->{'withuser'}) {
            my $user_macros = Thruk::Utils::read_resource_file($c->{'obj_db'}->{'config'}->{'obj_resource_file'});
            push @{$objects}, keys %{$user_macros};
        }
        for my $type (qw/host service/) {
            for my $macro (keys %{$c->{'obj_db'}->{'macros'}->{$type}}) {
                push @{$objects}, '$_'.uc($type).uc(substr($macro, 1)).'$';
            }
        }
        @{$objects} = sort @{$objects};
        my $json            = [ { 'name' => 'macros', 'data' => $objects } ];
        if($c->stash->{conf_config}->{'show_plugin_syntax_helper'}) {
            if(defined $c->{'request'}->{'parameters'}->{'plugin'} and $c->{'request'}->{'parameters'}->{'plugin'} ne '') {
                my $help = $c->{'obj_db'}->get_plugin_help($c, $c->{'request'}->{'parameters'}->{'plugin'});
                my @options = $help =~ m/(\-[\w\d]|\-\-[\d\w\-_]+)[=|,|\s|\$]/gmx;
                push @{$json}, { 'name' => 'arguments', 'data' => Thruk::Utils::array_uniq(\@options) } if scalar @options > 0;
            }
        }
        $c->stash->{'json'} = $json;
        $c->forward('Thruk::View::JSON');
        return;
    }

    # plugins
    if($type eq 'plugin') {
        my $plugins         = $c->{'obj_db'}->get_plugins($c);
        my $json            = [ { 'name' => 'plugins', 'data' => [ sort keys %{$plugins} ] } ];
        $c->stash->{'json'} = $json;
        $c->forward('Thruk::View::JSON');
        return;
    }

    # plugin help
    if($type eq 'pluginhelp' and $c->stash->{conf_config}->{'show_plugin_syntax_helper'}) {
        my $help            = $c->{'obj_db'}->get_plugin_help($c, $c->{'request'}->{'parameters'}->{'plugin'});
        my $json            = [ { 'plugin_help' => $help } ];
        $c->stash->{'json'} = $json;
        $c->forward('Thruk::View::JSON');
        return;
    }

    # plugin preview
    if($type eq 'pluginpreview' and $c->stash->{conf_config}->{'show_plugin_syntax_helper'}) {
        my $output          = $c->{'obj_db'}->get_plugin_preview($c,
                                                         $c->{'request'}->{'parameters'}->{'command'},
                                                         $c->{'request'}->{'parameters'}->{'args'},
                                                         $c->{'request'}->{'parameters'}->{'host'},
                                                         $c->{'request'}->{'parameters'}->{'service'},
                                                        );
        my $json            = [ { 'plugin_output' => $output } ];
        $c->stash->{'json'} = $json;
        $c->forward('Thruk::View::JSON');
        return;
    }

    # command line
    if($type eq 'commanddetail') {
        my $name    = $c->{'request'}->{'parameters'}->{'command'};
        my $objects = $c->{'obj_db'}->get_objects_by_name('command', $name);
        my $json = [ { 'cmd_line' => '' } ];
        if(defined $objects->[0]) {
            $json = [ { 'cmd_line' => $objects->[0]->{'conf'}->{'command_line'} } ];
        }
        $c->stash->{'json'} = $json;
        $c->forward('Thruk::View::JSON');
        return;
    }

    # servicemembers
    if($type eq 'servicemember') {
        my $members = [];
        my $objects = $c->{'obj_db'}->get_objects_by_type('host');
        for my $host (@{$objects}) {
            my $hostname = $host->get_name();
            my $services = $c->{'obj_db'}->get_services_for_host($host);
            for my $svc (keys %{$services->{'group'}}, keys %{$services->{'host'}}) {
                push @{$members}, $hostname.','.$svc;
            }
        }
        my $json = [{ 'name' => $type.'s',
                      'data' => [ sort @{Thruk::Utils::array_uniq($members)} ],
                   }];
        $c->stash->{'json'} = $json;
        $c->forward('Thruk::View::JSON');
        return;
    }

    # objects attributes
    if($type eq 'attribute') {
        my $for  = $c->{'request'}->{'parameters'}->{'obj'};
        my $attr = $c->{'obj_db'}->get_default_keys($for, { no_alias => 1 });
        push @{$attr}, 'customvariable';
        my $json = [{ 'name' => $type.'s',
                      'data' => [ sort @{Thruk::Utils::array_uniq($attr)} ],
                   }];
        $c->stash->{'json'} = $json;
        $c->forward('Thruk::View::JSON');
        return;
    }

    # objects
    my $json;
    my $objects   = [];
    my $templates = [];
    my $filter    = $c->{'request'}->{'parameters'}->{'filter'};
    my $use_long  = $c->{'request'}->{'parameters'}->{'long'};
    if(defined $filter) {
        my $types   = {};
        my $objects = $c->{'obj_db'}->get_objects_by_type($type,$filter);
        for my $subtype (keys %{$objects}) {
            for my $name (keys %{$objects->{$subtype}}) {
                $types->{$subtype}->{$name} = 1 unless substr($name,0,1) eq '!';
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
            my $name = $use_long ? $dat->get_long_name(undef, '  -  ') : $dat->get_name();
            if(defined $name) {
                if($dat->{'disabled'}) { $name = $name.' (disabled)' }
                push @{$objects}, $name
            } else {
                $c->log->warn("object without a name in ".$dat->{'file'}->{'path'}.":".$dat->{'line'}." -> ".Dumper($dat->{'conf'}));
            }
        }
        for my $dat (@{$c->{'obj_db'}->get_templates_by_type($type)}) {
            my $name = $dat->get_template_name();
            if(defined $name) {
                push @{$templates}, $name;
            } else {
                $c->log->warn("template without a name in ".$dat->{'file'}->{'path'}.":".$dat->{'line'}." -> ".Dumper($dat->{'conf'}));
            }
        }
        $json = [ { 'name' => $type.'s',
                    'data' => [ sort @{Thruk::Utils::array_uniq($objects)} ],
                  },
                  { 'name' => $type.' templates',
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
    $c->stash->{'readonly'} = (-w $file) ? 0 : 1;

    # create a default config from the current used cgi.cfg
    if(!-e $file and $file ne $c->config->{'cgi.cfg_effective'}) {
        copy($c->config->{'cgi.cfg_effective'}, $file) or die('cannot copy '.$c->config->{'cgi.cfg_effective'}.' to '.$file.': '.$!);
    }

    my $defaults = Thruk::Utils::Conf::Defaults->get_cgi_cfg();

    # save changes
    if($c->stash->{action} eq 'store') {
        if($c->stash->{'readonly'}) {
            Thruk::Utils::set_message( $c, 'fail_message', 'file is readonly' );
            return $c->response->redirect('conf.cgi?sub=cgi');
        }

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
    $c->stash->{'readonly'} = (-w $file) ? 0 : 1;

    # save changes
    if($c->stash->{action} eq 'store') {
        if($c->stash->{'readonly'}) {
            Thruk::Utils::set_message( $c, 'fail_message', 'file is readonly' );
            return $c->response->redirect('conf.cgi?sub=thruk');
        }

        my $data = Thruk::Utils::Conf::get_data_from_param($c->{'request'}->{'parameters'}, $defaults);
        $self->_store_changes($c, $file, $data, $defaults, $c);
        return Thruk::Utils::restart_later($c, $c->stash->{url_prefix}.'thruk/cgi-bin/conf.cgi?sub=thruk');
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
                        show_backends_in_table
                        show_full_commandline
                        shown_inline_pnp
                        show_modified_attributes
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
    $c->stash->{'readonly'} = (-w $file) ? 0 : 1;

    # save changes to user
    my $user = $c->{'request'}->{'parameters'}->{'data.username'} || '';
    if($user ne '' and defined $file and $c->stash->{action} eq 'store') {
        my $redirect = 'conf.cgi?action=change&sub=users&data.username='.$user;
        if($c->stash->{'readonly'}) {
            Thruk::Utils::set_message( $c, 'fail_message', 'file is readonly' );
            return $c->response->redirect($redirect);
        }
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
            $c->stash->{'has_contact'}    = 1;
            $c->stash->{'contact'}        = $contacts->[0];
        }

        $c->stash->{'contact_groups'} = $c->{'db'}->get_contactgroups_by_contact($c, $name);
        my($croles, $can_submit_commands, $calias, $roles_by_group)
                = Thruk::Utils::get_dynamic_roles($c, $name);
        $c->stash->{'contact_roles'}  = $croles;
        $c->stash->{'contact_can_submit_commands'} = $can_submit_commands;
        $c->stash->{'roles_by_group'} = $roles_by_group;
    }

    $c->stash->{'subtitle'} = "User Configuration";
    $c->stash->{'template'} = 'conf_data_users.tt';

    return 1;
}

##########################################################
# create the plugins config page
sub _process_plugins_page {
    my( $self, $c ) = @_;

    my $project_root         = $c->config->{home};
    my $plugin_dir           = $c->config->{'plugin_path'} || $project_root."/plugins";
    my $plugin_enabled_dir   = $plugin_dir.'/plugins-enabled';
    my $plugin_available_dir = $project_root.'/plugins/plugins-available';

    $c->stash->{'readonly'}  = 0;
    if(! -d $plugin_enabled_dir or ! -w $plugin_enabled_dir ) {
        $c->stash->{'readonly'}  = 1;
    }

    if($c->stash->{action} eq 'preview') {
        my $pic = $c->{'request'}->{'parameters'}->{'pic'} || die("missing pic");
        if($pic !~ m/^[a-zA-Z0-9_\ ]+$/gmx) {
            die("unknown pic: ".$pic);
        }
        my $path = $plugin_available_dir.'/'.$pic.'/preview.png';
        $c->res->content_type('images/png');
        $c->stash->{'text'} = "";
        if(-e $path) {
            $c->stash->{'text'} = read_file($path);
        }
        $c->stash->{'template'} = 'passthrough.tt';
        return 1;
    }
    elsif($c->stash->{action} eq 'save') {
        # don't store in demo mode
        if($c->config->{'demo_mode'}) {
            Thruk::Utils::set_message( $c, 'fail_message', "save is disabled in demo mode" );
            return $c->response->redirect('conf.cgi?sub=plugins');
        }
        if(! -d $plugin_enabled_dir or ! -w $plugin_enabled_dir ) {
            Thruk::Utils::set_message( $c, 'fail_message', 'Make sure plugins folder ('.$plugin_enabled_dir.') is writeable: '.$! );
        }
        else {
            for my $addon (glob($plugin_available_dir.'/*/')) {
                my($addon_name, $dir) = _nice_addon_name($addon);
                if(!defined $c->{'request'}->{'parameters'}->{'plugin.'.$dir} or $c->{'request'}->{'parameters'}->{'plugin.'.$dir} == 0) {
                    unlink($plugin_enabled_dir.'/'.$dir);
                }
                if(defined $c->{'request'}->{'parameters'}->{'plugin.'.$dir} and $c->{'request'}->{'parameters'}->{'plugin.'.$dir} == 1) {
                    if(!-e $plugin_enabled_dir.'/'.$dir) {
                        symlink($plugin_available_dir.'/'.$dir,
                                $plugin_enabled_dir.'/'.$dir)
                            or die("cannot create ".$plugin_enabled_dir.'/'.$dir." : ".$!);
                    }
                }
            }
            Thruk::Utils::set_message( $c, 'success_message', 'Plugins changed successfully.' );
            return Thruk::Utils::restart_later($c, $c->stash->{url_prefix}.'thruk/cgi-bin/conf.cgi?sub=plugins');
        }
    }

    my $plugins = {};
    for my $addon (glob($plugin_available_dir.'/*/')) {
        my($addon_name, $dir) = _nice_addon_name($addon);
        $plugins->{$addon_name} = { enabled => 0, dir => $dir, description => '(no description available.)', url => '' };
        if(-e $plugin_available_dir.'/'.$dir.'/description.txt') {
            my $description = read_file($plugin_available_dir.'/'.$dir.'/description.txt');
            my $url         = "";
            if($description =~ s/^Url:\s*(.*)$//gmx) { $url = $1; }
            $plugins->{$addon_name}->{'description'} = $description;
            $plugins->{$addon_name}->{'url'}         = $url;
        }
    }
    for my $addon (glob($plugin_enabled_dir.'/*/')) {
        my($addon_name, $dir) = _nice_addon_name($addon);
        $plugins->{$addon_name}->{'enabled'} = 1;
    }

    $c->stash->{'plugins'}  = $plugins;
    $c->stash->{'subtitle'} = "Thruk Addons &amp; Plugin Manager";
    $c->stash->{'template'} = 'conf_plugins.tt';

    return 1;
}

##########################################################
# create the backends config page
sub _process_backends_page {
    my( $self, $c ) = @_;

    my $file = $c->config->{'Thruk::Plugin::ConfigTool'}->{'thruk'};
    return unless $file;
    # non existing file gives readonly, so try to create it
    if(!-e $file) {
        open(my $fh, '>', $file);
        if($fh) {
            print $fh '';
            Thruk::Utils::IO::close($fh, $file);
        }
    }
    $c->stash->{'readonly'} = (-w $file) ? 0 : 1;

    if($c->stash->{action} eq 'save') {
        # don't store in demo mode
        if($c->config->{'demo_mode'}) {
            Thruk::Utils::set_message( $c, 'fail_message', "save is disabled in demo mode" );
            return $c->response->redirect('conf.cgi?sub=backends');
        }
        if($c->stash->{'readonly'}) {
            Thruk::Utils::set_message( $c, 'fail_message', 'file is readonly' );
            return $c->response->redirect('conf.cgi?sub=backends');
        }

        my $x=0;
        my $backends = [];
        my $new = 0;
        while(defined $c->request->parameters->{'name'.$x}) {
            my $backend = {
                'name'    => $c->request->parameters->{'name'.$x},
                'type'    => $c->request->parameters->{'type'.$x},
                'id'      => $c->request->parameters->{'id'.$x},
                'hidden'  => defined $c->request->parameters->{'hidden'.$x} ? $c->request->parameters->{'hidden'.$x} : 0,
                'section' => $c->request->parameters->{'section'.$x},
                'options' => {},
            };
            $backend->{'options'}->{'peer'}         = $c->request->parameters->{'peer'.$x}        if $c->request->parameters->{'peer'.$x};
            $backend->{'options'}->{'auth'}         = $c->request->parameters->{'auth'.$x}        if $c->request->parameters->{'auth'.$x};
            $backend->{'options'}->{'proxy'}        = $c->request->parameters->{'proxy'.$x}       if $c->request->parameters->{'proxy'.$x};
            $backend->{'options'}->{'remote_name'}  = $c->request->parameters->{'remote_name'.$x} if $c->request->parameters->{'remote_name'.$x};
            $x++;
            $backend->{'name'} = 'backend '.$x if(!$backend->{'name'} and $backend->{'options'}->{'peer'});
            next unless $backend->{'name'};
            delete $backend->{'id'} if $backend->{'id'} eq '';

            if($backend->{'options'}->{'peer'} and $backend->{'type'} eq 'livestatus' and $backend->{'options'}->{'peer'} =~ m/^\d+\.\d+\.\d+\.\d+$/mx) {
                $backend->{'options'}->{'peer'} .= ':6557';
            }

            # add values from existing backend config
            if(defined $backend->{'id'}) {
                my $peer = $c->{'db'}->get_peer_by_key($backend->{'id'});
                $backend->{'options'}->{'resource_file'} = $peer->{'resource_file'} if defined $peer->{'resource_file'};
                $backend->{'groups'}     = $peer->{'groups'}     if defined $peer->{'groups'};
                $backend->{'configtool'} = $peer->{'configtool'} if defined $peer->{'configtool'};
            }
            $new = 1 if $x == 1;
            push @{$backends}, $backend;
        }
        # put new one at the end
        if($new) { push(@{$backends}, shift(@{$backends})) }
        my $string    = Thruk::Utils::Conf::get_component_as_string($backends);
        Thruk::Utils::Conf::replace_block($file, $string, '<Component\s+Thruk::Backend>', '<\/Component>\s*');
        Thruk::Utils::set_message( $c, 'success_message', 'Backends changed successfully.' );
        return Thruk::Utils::restart_later($c, $c->stash->{url_prefix}.'thruk/cgi-bin/conf.cgi?sub=backends');
    }
    if($c->stash->{action} eq 'check_con') {
        my $peer        = $c->request->parameters->{'peer'};
        my $type        = $c->request->parameters->{'type'};
        my $auth        = $c->request->parameters->{'auth'};
        my $proxy       = $c->request->parameters->{'proxy'};
        my $remote_name = $c->request->parameters->{'remote_name'};
        my @test;
        eval {
            my $con = Thruk::Backend::Peer->new({
                                                 type    => $type,
                                                 name    => 'test connection',
                                                 options => { peer => $peer, auth => $auth, proxy => $proxy, remote_name => $remote_name },
                                                });
            @test   = $con->{'class'}->get_processinfo();
        };
        if(scalar @test >= 2 and ref $test[0] eq 'HASH' and scalar keys %{$test[0]} == 1 and scalar keys %{$test[0]->{(keys %{$test[0]})[0]}} > 0) {
            $c->stash->{'json'} = { ok => 1 };
        } else {
            my $error = $@;
            $error =~ s/\s+at\s\/.*//gmx;
            $error = 'got no valid result' if $error eq '';
            $c->stash->{'json'} = { ok => 0, error => $error };
        }
        return $c->forward('Thruk::View::JSON');
    }

    my $backends = [];
    my %conf;
    if(-f $file) {
        %conf = ParseConfig($file);
    }
    if(!defined $conf{'Component'}->{'Thruk::Backend'}) {
        $file =~ s/thruk_local\.conf/thruk.conf/mx;
        %conf = ParseConfig($file) if -f $file;
    }

    if(keys %conf > 0) {
        if(defined $conf{'Component'}->{'Thruk::Backend'}->{'peer'}) {
            if(ref $conf{'Component'}->{'Thruk::Backend'}->{'peer'} eq 'ARRAY') {
                $backends = $conf{'Component'}->{'Thruk::Backend'}->{'peer'};
            } else {
                push @{$backends}, $conf{'Component'}->{'Thruk::Backend'}->{'peer'};
            }
        }
    }
    if(scalar @{$backends} == 0) {
        # add empty sample backend
        push @{$backends}, { 'name' => '' };
    }
    # set ids
    for my $b (@{$backends}) {
        $b->{'type'}        = 'livestatus' unless defined $b->{'type'};
        $b->{'key'}         = substr(md5_hex(($b->{'options'}->{'peer'} || '')." ".$b->{'name'}), 0, 5) unless defined $b->{'key'};
        $b->{'addr'}        = $b->{'options'}->{'peer'}  || '';
        $b->{'auth'}        = $b->{'options'}->{'auth'}  || '';
        $b->{'proxy'}       = $b->{'options'}->{'proxy'} || '';
        $b->{'remote_name'} = $b->{'options'}->{'remote_name'} || '';
        $b->{'hidden'}      = 0 unless defined $b->{'hidden'};
        $b->{'section'}     = '' unless defined $b->{'section'};
        $b->{'type'}        = lc($b->{'type'});
    }
    $c->stash->{'sites'}    = $backends;
    $c->stash->{'subtitle'} = "Thruk Backends Manager";
    $c->stash->{'template'} = 'conf_backends.tt';

    return 1;
}

##########################################################
# create the objects config page
sub _process_objects_page {
    my( $self, $c ) = @_;

    return unless Thruk::Utils::Conf::set_object_model($c);

    _check_external_reload($c);

    $c->stash->{'subtitle'}         = "Object Configuration";
    $c->stash->{'template'}         = 'conf_objects.tt';
    $c->stash->{'file_link'}        = "";
    $c->stash->{'coretype'}         = $c->{'obj_db'}->{'coretype'};
    $c->stash->{'bare'}             = $c->{'request'}->{'parameters'}->{'bare'} || 0;
    $c->stash->{'has_history'}      = 0;

    $c->{'obj_db'}->read_rc_file();

    # check if we have a history for our configs
    my $files_root = $c->{'obj_db'}->get_files_root();
    my $dir        = $c->{'obj_db'}->{'config'}->{'git_base_dir'} || $c->config->{'Thruk::Plugin::ConfigTool'}->{'git_base_dir'} || $files_root;
    {
        local $SIG{CHLD} = 'DEFAULT';
        my $cmd          = "cd '".$dir."' && git log --pretty='format:%H' -1 2>&1";
        my $out          = `$cmd`;
        $c->stash->{'has_history'} = 1 if $? == 0;
        $c->log->debug($cmd);
        $c->log->debug($out);
    };


    # apply changes?
    if(defined $c->{'request'}->{'parameters'}->{'apply'}) {
        return if $self->_apply_config_changes($c);
    }

    # tools menu
    if(defined $c->{'request'}->{'parameters'}->{'tools'}) {
        return if $self->_process_tools_page($c);
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
            my $rc = $self->_object_save($c, $obj);
            if(defined $c->{'request'}->{'parameters'}->{'save_and_reload'}) {
                return if $self->_apply_config_changes($c);
            }
            return if $rc;
        }

        # disable this object temporarily
        elsif($c->stash->{action} eq 'disable') {
            return if $self->_object_disable($c, $obj);
        }

        # enable this object
        elsif($c->stash->{action} eq 'enable') {
            return if $self->_object_enable($c, $obj);
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

        # list services for host
        elsif($c->stash->{action} eq 'listservices' and $obj->get_type() eq 'host') {
            return if $self->_host_list_services($c, $obj);
        }

        # list references
        elsif($c->stash->{action} eq 'listref') {
            return if $self->_list_references($c, $obj);
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

    # object tree
    elsif($c->stash->{action} eq 'tree') {
        return if $self->_object_tree($c);
    }

    # object tree content
    elsif($c->stash->{action} eq 'tree_objects') {
        return if $self->_object_tree_objects($c);
    }

    # file editor
    elsif($c->stash->{action} eq 'editor') {
        return if $self->_file_editor($c);
    }

    # history
    elsif($c->stash->{action} eq 'history') {
        return if $self->_file_history($c);
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
        # make sure object has either a real file or none
        if(!defined $obj->{'file'} || !defined $obj->{'file'}->{'path'}) {
            delete $obj->{'file'};
        }
        $c->stash->{'file_link'} = $obj->{'file'}->{'display'} if defined $obj->{'file'};
    }

    # set default type for start page
    if($c->stash->{action} eq 'show' and $c->stash->{type} eq '') {
        $c->stash->{type} = 'host';
    }

    $c->stash->{'needs_commit'}      = $c->{'obj_db'}->{'needs_commit'};
    $c->stash->{'last_changed'}      = $c->{'obj_db'}->{'last_changed'};
    $c->stash->{'obj_model_changed'} = 0 unless $c->{'request'}->{'parameters'}->{'refresh'};
    $c->stash->{'referer'}           = $c->{'request'}->{'parameters'}->{'referer'} || '';
    $c->{'obj_db'}->_reset_errors(1);
    return 1;
}


##########################################################
# apply config changes
sub _apply_config_changes {
    my ( $self, $c ) = @_;

    $c->stash->{'subtitle'}      = "Apply Config Changes";
    $c->stash->{'template'}      = 'conf_objects_apply.tt';
    $c->stash->{'output'}        = '';
    $c->stash->{'changed_files'} = $c->{'obj_db'}->get_changed_files();

    if(defined $c->{'request'}->{'parameters'}->{'save_and_reload'}) {
        # don't store in demo mode
        if($c->config->{'demo_mode'}) {
            Thruk::Utils::set_message( $c, 'fail_message', "save is disabled in demo mode" );
            return $c->response->redirect('conf.cgi?sub=objects&apply=yes');
        }
        if($c->{'obj_db'}->commit($c)) {
            # update changed files
            $c->stash->{'changed_files'} = $c->{'obj_db'}->get_changed_files();
            # set flag to do the reload
            $c->{'request'}->{'parameters'}->{'reload'} = 'yes';
        } else {
            return $c->response->redirect('conf.cgi?sub=objects&apply=yes');
        }
    }

    # get diff of changed files
    if(defined $c->{'request'}->{'parameters'}->{'diff'}) {
        $c->stash->{'output'} .= "<ul>\n";
        for my $file (@{$c->stash->{'changed_files'}}) {
            $c->stash->{'output'} .= "<li><a href='#".Thruk::Utils::Filter::name2id($file->{'display'})."'>".$file->{'display'}."</a></li>\n";
        }
        $c->stash->{'output'} .= "</ul>\n";
        for my $file (@{$c->stash->{'changed_files'}}) {
            $c->stash->{'output'} .= "<hr><a id='".Thruk::Utils::Filter::name2id($file->{'display'})."'></a><pre>\n";
            $c->stash->{'output'} .= Thruk::Utils::Filter::escape_html($file->diff());
            $c->stash->{'output'} .= "</pre><br>\n";
        }
    }

    # config check
    elsif(defined $c->{'request'}->{'parameters'}->{'check'}) {
        if(defined $c->stash->{'peer_conftool'}->{'obj_check_cmd'}) {
            $c->stash->{'parse_errors'} = $c->{'obj_db'}->{'parse_errors'};
            Thruk::Utils::External::perl($c, { expr    => 'Thruk::Controller::conf::_config_check($c)',
                                               message => 'please stand by while configuration is beeing checked...'
                                              }
                                        );
            return;
        } else {
            Thruk::Utils::set_message( $c, 'fail_message', "please set 'obj_check_cmd' in your thruk_local.conf" );
        }
    }

    # config reload
    elsif(defined $c->{'request'}->{'parameters'}->{'reload'}) {
        # don't store in demo mode
        if($c->config->{'demo_mode'}) {
            Thruk::Utils::set_message( $c, 'fail_message', "reload is disabled in demo mode" );
            return $c->response->redirect('conf.cgi?sub=objects&apply=yes');
        }
        if(defined $c->stash->{'peer_conftool'}->{'obj_reload_cmd'}) {
            $c->stash->{'parse_errors'} = $c->{'obj_db'}->{'parse_errors'};
            Thruk::Utils::External::perl($c, { expr    => 'Thruk::Controller::conf::_config_reload($c)',
                                               message => 'please stand by while configuration is beeing reloaded...',
                                              }
                                        );
            return;
        } else {
            Thruk::Utils::set_message( $c, 'fail_message', "please set 'obj_reload_cmd' in your thruk_local.conf" );
        }
    }

    # save changes to file
    elsif(defined $c->{'request'}->{'parameters'}->{'save'}) {
        # don't store in demo mode
        if($c->config->{'demo_mode'}) {
            Thruk::Utils::set_message( $c, 'fail_message', "save is disabled in demo mode" );
            return $c->response->redirect('conf.cgi?sub=objects&apply=yes');
        }
        if($c->{'obj_db'}->commit($c)) {
            Thruk::Utils::set_message( $c, 'success_message', 'Changes saved to disk successfully' );
        }
        return $c->response->redirect('conf.cgi?sub=objects&apply=yes');
    }

    # make nicer output
    if(defined $c->{'request'}->{'parameters'}->{'diff'}) {
        $c->{'stash'}->{'output'} = Thruk::Utils::beautify_diff($c->{'stash'}->{'output'});
    }

    # discard changes
    if($c->{'request'}->{'parameters'}->{'discard'}) {
        $c->{'obj_db'}->discard_changes();
        Thruk::Utils::set_message( $c, 'success_message', 'Changes have been discarded' );
        return $c->response->redirect('conf.cgi?sub=objects&apply=yes');
    }
    $c->stash->{'obj_model_changed'} = 0 unless ($c->{'request'}->{'parameters'}->{'refresh'} || $c->{'request'}->{'parameters'}->{'discard'});
    $c->stash->{'needs_commit'}      = $c->{'obj_db'}->{'needs_commit'};
    $c->stash->{'last_changed'}      = $c->{'obj_db'}->{'last_changed'};
    $c->stash->{'files'}             = $c->{'obj_db'}->get_files();
    return;
}

##########################################################
# show tools page
sub _process_tools_page {
    my ( $self, $c ) = @_;

    $c->stash->{'subtitle'}      = 'Config Tools';
    $c->stash->{'template'}      = 'conf_objects_tools.tt';
    $c->stash->{'output'}        = '';
    $c->stash->{'action'}        = 'tools';
    $c->stash->{'warnings'}      = [];

    my $tool   = $c->{'request'}->{'parameters'}->{'tools'} || 'start';

    if($tool eq 'check_object_references') {
        my $warnings = [ @{$c->{'obj_db'}->_check_references()}, @{$c->{'obj_db'}->_check_orphaned_objects()} ];
        @{$warnings} = sort @{$warnings};
        $c->stash->{'warnings'} = $warnings;
    }

    $c->stash->{'tool'} = $tool;
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
    # don't store in demo mode
    if($c->config->{'demo_mode'}) {
        Thruk::Utils::set_message( $c, 'fail_message', "save is disabled in demo mode" );
        return;
    }
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
    local $ENV{REMOTE_USER}=$c->stash->{'remote_user'};
    $c->log->debug( "running cmd: ". $cmd );
    my $rc = $?;
    my $output = `$cmd 2>&1`;
    if($? == -1) {
        $output .= "[".$!."]";
    } else {
        $rc = $?>>8;
    }

    $c->{'stash'}->{'output'} = decode_utf8($output);
    $c->log->debug( "rc:     ". $rc );
    $c->log->debug( "output: ". $output );
    if($rc != 0) {
        return 0;
    }
    return 1;
}

##########################################################
sub _find_files {
    my($c, $dir, $types) = @_;
    my $files = $c->{'obj_db'}->_get_files_for_folder($dir, $types);
    return $files;
}

##########################################################
sub _get_context_object {
    my($self, $c) = @_;

    my $obj;

    $c->stash->{'type'}          = $c->{'request'}->{'parameters'}->{'type'}       || '';
    $c->stash->{'subcat'}        = $c->{'request'}->{'parameters'}->{'subcat'}     || 'config';
    $c->stash->{'data_name'}     = $c->{'request'}->{'parameters'}->{'data.name'}  || '';
    $c->stash->{'data_name2'}    = $c->{'request'}->{'parameters'}->{'data.name2'} || '';
    $c->stash->{'data_id'}       = $c->{'request'}->{'parameters'}->{'data.id'}    || '';
    $c->stash->{'file_name'}     = $c->{'request'}->{'parameters'}->{'file'};
    $c->stash->{'file_line'}     = $c->{'request'}->{'parameters'}->{'line'};
    $c->stash->{'data_name'}     =~ s/^(.*)\ \ \-\ \ .*$/$1/gmx;
    $c->stash->{'data_name'}     =~ s/\ \(disabled\)$//gmx;
    $c->stash->{'type'}          = lc $c->stash->{'type'};
    $c->stash->{'show_object'}   = 0;
    $c->stash->{'show_secondary_select'} = 0;

    if(defined $c->{'request'}->{'parameters'}->{'service'} and defined $c->{'request'}->{'parameters'}->{'host'}) {
        $c->stash->{'type'}       = 'service';
        my $objs = $c->{'obj_db'}->get_objects_by_name('host', $c->{'request'}->{'parameters'}->{'host'}, 0);
        if(defined $objs->[0]) {
            my $services = $c->{'obj_db'}->get_services_for_host($objs->[0]);
            for my $type (keys %{$services}) {
                for my $name (keys %{$services->{$type}}) {
                    if($name eq $c->{'request'}->{'parameters'}->{'service'}) {
                        if(defined $services->{$type}->{$name}->{'svc'}) {
                            $c->stash->{'data_id'} = $services->{$type}->{$name}->{'svc'}->get_id();
                        } else {
                            $c->stash->{'data_id'} = $services->{$type}->{$name}->get_id();
                        }
                    }
                }
            }
        }
    }
    elsif(defined $c->{'request'}->{'parameters'}->{'host'}) {
        $c->stash->{'type'} = 'host';
        $c->stash->{'data_name'}  = $c->{'request'}->{'parameters'}->{'host'};
    }

    # remove leading plus signs (used to append to lists) and leading ! (used to negate in lists)
    $c->stash->{'data_name'} =~ s/^(\+|\!)//mx;

    # new object
    if($c->stash->{'data_id'} and $c->stash->{'data_id'} eq 'new') {
        $obj = Monitoring::Config::Object->new( type     => $c->stash->{'type'},
                                                coretype => $c->{'obj_db'}->{'coretype'},
                                              );
        my $new_file   = $c->{'request'}->{'parameters'}->{'data.file'} || '';
        my $file = $self->_get_context_file($c, $obj, $new_file);
        return $obj unless $file;
        $obj->set_file($file);
        $obj->set_uniq_id($c->{'obj_db'});
        return $obj;
    }

    # object by id
    if($c->stash->{'data_id'}) {
        $obj = $c->{'obj_db'}->get_object_by_id($c->stash->{'data_id'});
    }

    # link from file to an object?
    if(!defined $obj && defined $c->stash->{'file_name'} && defined $c->stash->{'file_line'} and $c->stash->{'file_line'} =~ m/^\d+$/mx) {
        $obj = $c->{'obj_db'}->get_object_by_location($c->stash->{'file_name'}, $c->stash->{'file_line'});
        unless(defined $obj) {
            Thruk::Utils::set_message( $c, 'fail_message', 'No such object found in this file' );
        }
    }

    # object by name
    my @objs;
    if(!defined $obj && $c->stash->{'data_name'} ) {
        my $templates;
        if($c->stash->{'data_name'} =~ m/^ht:/mx or $c->stash->{'data_name'} =~ m/^st:/mx) {
            $templates=1; # only templates
        }
        if($c->stash->{'data_name'} =~ m/^ho:/mx or $c->stash->{'data_name'} =~ m/^se:/mx) {
            $templates=2; # no templates
        }
        $c->stash->{'data_name'} =~ s/^\w{2}://gmx;
        my $objs = $c->{'obj_db'}->get_objects_by_name($c->stash->{'type'}, $c->stash->{'data_name'}, 0, $c->stash->{'data_name2'});
        if(defined $templates) {
            my @newobjs;
            for my $o (@{$objs}) {
                if($templates == 1) {
                    push @newobjs, $o if $o->is_template();
                }
                if($templates == 2) {
                    push @newobjs, $o if !defined $o->{'conf'}->{'register'} or $o->{'conf'}->{'register'} != 0;
                }
            }
            @{$objs} = @newobjs;
        }
        if(defined $objs->[1]) {
            @objs = @{$objs};
            $c->stash->{'show_secondary_select'} = 1;
        }
        elsif(defined $objs->[0]) {
            $obj = $objs->[0];
        }
        elsif(!defined $obj) {
            Thruk::Utils::set_message( $c, 'fail_message', 'No such object. <a href="conf.cgi?sub=objects&action=new&amp;type='.$c->stash->{'type'}.'&amp;data.name='.$c->stash->{'data_name'}.'">Create it.</a>' );
        }
    }

    return $obj;
}

##########################################################
sub _get_context_file {
    my($self, $c, $obj, $new_file) = @_;
    my $files_root = $c->{'obj_db'}->get_files_root();
    if($files_root eq '') {
        $c->stash->{'new_file'} = '';
        Thruk::Utils::set_message($c, 'fail_message', 'Failed to create new file: please set at least one directory in your obj config.');
        return;
    }
    my $fullpath   = $files_root.'/'.$new_file;
    $fullpath      =~ s|\/+|\/|gmx;
    my $file       = $c->{'obj_db'}->get_file_by_path($fullpath);
    if(defined $file) {
        if(defined $file and $file->readonly()) {
            Thruk::Utils::set_message( $c, 'fail_message', 'File matches readonly pattern' );
            $c->stash->{'new_file'} = '/'.$new_file;
            return;
        }
    } else {
        # new file
        my $remotepath = $fullpath;
        my $localpath  = $remotepath;
        if($c->{'obj_db'}->is_remote()) {
            $localpath  = $c->{'obj_db'}->{'config'}->{'localdir'}.'/'.$localpath;
        }
        $file = Monitoring::Config::File->new($localpath, $c->{'obj_db'}->{'config'}->{'obj_readonly'}, $c->{'obj_db'}->{'coretype'}, undef, $remotepath);
        if(defined $file and $file->readonly()) {
            Thruk::Utils::set_message( $c, 'fail_message', 'Failed to create new file: file matches readonly pattern' );
            $c->stash->{'new_file'} = '/'.$new_file;
            return;
        }
        elsif(defined $file) {
            $c->{'obj_db'}->file_add($file);
        }
        else {
            $c->stash->{'new_file'} = '';
            Thruk::Utils::set_message( $c, 'fail_message', 'Failed to create new file: invalid path' );
            return;
        }
    }
    return $file;
}

##########################################################
sub _translate_type {
    my($self, $type) = @_;
    my $tt   = {
        'host_name'      => 'host',
        'hostgroup_name' => 'hostgroup',
    };
    return $tt->{$type} if defined $type;
    return;
}

##########################################################
sub _files_to_path {
    my($self, $c, $files) = @_;

    my $folder = { 'dirs' => {}, 'files' => {}, 'path' => '', 'date' => '' };

    my $ro_pattern = $c->{'obj_db'}->{'config'}->{'obj_readonly'};
    $ro_pattern = [] unless defined $ro_pattern;
    if(ref $ro_pattern eq '') { $ro_pattern = [$ro_pattern]; }

    for my $file (@{$files}) {
        my @parts    = split(/\//mx, $file->{'display'});
        my $filename = pop @parts;
        my $subdir = $folder;
        for my $dir (@parts) {
            $dir = $dir."/";
            unless(defined $subdir->{'dirs'}->{$dir}) {
                my $readonly = 0;
                my $fulldir = $subdir->{'path'}.$dir;
                for my $p (@{$ro_pattern}) {
                    if($fulldir =~ m/$p/mx) {
                        $readonly = 1;
                        last;
                    }
                }
                my @stat = stat($fulldir);
                $subdir->{'dirs'}->{$dir} = {
                                             'dirs'     => {},
                                             'files'    => {},
                                             'path'     => $fulldir,
                                             'date'     => Thruk::Utils::Filter::date_format($c, $stat[9]),
                                             'readonly' => $readonly,
                                            };
            }
            $subdir = $subdir->{'dirs'}->{$dir};
        }
        $subdir->{'files'}->{$filename} = {
                                           'date'     => Thruk::Utils::Filter::date_format($c, $file->{'mtime'}),
                                           'deleted'  => $file->{'deleted'},
                                           'readonly' => $file->{'readonly'},
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
    my($self, $c, $skip_readonly_files) = @_;

    my $all_files  = $c->{'obj_db'}->get_files();
    my $files_tree = $self->_files_to_path($c, $all_files);
    my $files_root = $files_tree->{'path'};
    my @filenames;
    for my $file (@{$all_files}) {
        next if($skip_readonly_files and $file->{'readonly'});
        my $filename = $file->{'display'};
        $filename    =~ s/^$files_root/\//gmx;
        push @filenames, $filename;
    }

    # file root is empty when there are no files (yet)
    if($files_root eq '') {
        my $dirs = Thruk::Utils::list($c->{'obj_db'}->{'config'}->{'obj_dir'});
        if(defined $dirs->[0]) {
            $files_root = $dirs->[0];
            $files_root =~ s/\/*$//gmx;
            $files_root = $files_root.'/';
        }
    }

    # no encoding here, filenames are encoded already
    $c->stash->{'filenames_json'} = JSON::XS->new->encode([{ name => 'files', data => [ sort @filenames ]}]);
    $c->stash->{'files_json'}     = JSON::XS->new->encode($files_tree);
    return $files_root;
}

##########################################################
sub _object_revert {
    my($self, $c, $obj) = @_;

    my $id = $obj->get_id();
    if(-e $obj->{'file'}->{'path'}) {
        my $oldobj;
        my $tmpfile = Monitoring::Config::File->new($obj->{'file'}->{'path'}, undef, $c->{'obj_db'}->{'coretype'});
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
sub _object_disable {
    my($self, $c, $obj) = @_;

    my $id = $obj->get_id();
    $obj->{'disabled'}               = 1;
    $obj->{'file'}->{'changed'}      = 1;
    $c->{'obj_db'}->{'needs_commit'} = 1;
    Thruk::Utils::set_message( $c, 'success_message', ucfirst($obj->get_type()).' disabled successfully' );

    # create log message
    $c->log->info(sprintf("[config][%s][%s] disabled %s '%s'",
                                $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'name'},
                                $c->stash->{'remote_user'},
                                $obj->get_type(),
                                $obj->get_name(),
    ));

    return $c->response->redirect('conf.cgi?sub=objects&data.id='.$obj->get_id());
}

##########################################################
sub _object_enable {
    my($self, $c, $obj) = @_;

    my $id = $obj->get_id();
    $obj->{'disabled'}               = 0;
    $obj->{'file'}->{'changed'}      = 1;
    $c->{'obj_db'}->{'needs_commit'} = 1;
    Thruk::Utils::set_message( $c, 'success_message', ucfirst($obj->get_type()).' enabled successfully' );

    # create log message
    $c->log->info(sprintf("[config][%s][%s] enabled %s '%s'",
                                $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'name'},
                                $c->stash->{'remote_user'},
                                $obj->get_type(),
                                $obj->get_name(),
    ));

    return $c->response->redirect('conf.cgi?sub=objects&data.id='.$obj->get_id());
}

##########################################################
sub _object_delete {
    my($self, $c, $obj) = @_;

    if(!$c->{'request'}->{'parameters'}->{'force'}) {
        my $refs = $c->{'obj_db'}->get_references($obj);
        if(scalar keys %{$refs}) {
            Thruk::Utils::set_message( $c, 'fail_message', ucfirst($obj->get_type()).' has remaining references' );
            return $c->response->redirect('conf.cgi?sub=objects&action=listref&data.id='.$obj->get_id().'&show_force=1');
        }
    }
    $c->{'obj_db'}->delete_object($obj);

    # create log message
    $c->log->info(sprintf("[config][%s][%s] removed %s '%s'",
                                $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'name'},
                                $c->stash->{'remote_user'},
                                $obj->get_type(),
                                $obj->get_name(),
    ));

    Thruk::Utils::set_message( $c, 'success_message', ucfirst($obj->get_type()).' removed successfully' );
    return $c->response->redirect('conf.cgi?sub=objects&type='.$obj->get_type());
}

##########################################################
sub _object_save {
    my($self, $c, $obj) = @_;

    my $data        = $obj->get_data_from_param($c->{'request'}->{'parameters'});
    my $old_comment = join("\n", @{$obj->{'comments'}});
    my $new_comment = $c->{'request'}->{'parameters'}->{'conf_comment'};
    $new_comment    =~ s/\r//gmx;
    my $new         = $c->{'request'}->{'parameters'}->{'data.id'} eq 'new' ? 1 : 0;

    # save object
    $obj->{'file'}->{'errors'} = [];
    $c->{'obj_db'}->update_object($obj, $data, $new_comment);
    $c->stash->{'data_name'} = $obj->get_name();

    # just display the normal edit page if save failed
    if($obj->get_id() eq 'new') {
        $c->stash->{action} = '';
        return;
    }

    $c->log->info(sprintf("[config][%s][%s] %s %s '%s'",
                                $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'name'},
                                $c->stash->{'remote_user'},
                                $new ? 'created' : 'changed',
                                $obj->get_type(),
                                $c->stash->{'data_name'},
    )) unless $ENV{'THRUK_TEST_CONF_NO_LOG'};

    # only save or continue to raw edit?
    if(defined $c->{'request'}->{'parameters'}->{'send'} and $c->{'request'}->{'parameters'}->{'send'} eq 'raw edit') {
        return $c->response->redirect('conf.cgi?sub=objects&action=editor&file='.encode_utf8($obj->{'file'}->{'display'}).'&line='.$obj->{'line'}.'&data.id='.$obj->get_id().'&back=edit');
    } else {
        if(scalar @{$obj->{'file'}->{'errors'}} > 0) {
            Thruk::Utils::set_message( $c, 'fail_message', ucfirst($c->stash->{'type'}).' changed with errors', $obj->{'file'}->{'errors'} );
            return; # return, otherwise details would not be displayed
        } else {
            # does the object have a name?
            if(!defined $c->stash->{'data_name'} or $c->stash->{'data_name'} eq '') {
                $obj->set_name('undefined');
                $c->{'obj_db'}->_rebuild_index();
                Thruk::Utils::set_message( $c, 'fail_message', ucfirst($c->stash->{'type'}).' changed without a name' );
            } else {
                Thruk::Utils::set_message( $c, 'success_message', ucfirst($c->stash->{'type'}).' changed successfully' ) if !$new;
                Thruk::Utils::set_message( $c, 'success_message', ucfirst($c->stash->{'type'}).' created successfully' ) if  $new;
            }
        }
        if($c->{'request'}->{'parameters'}->{'referer'}) {
            return $c->response->redirect($c->{'request'}->{'parameters'}->{'referer'});
        } else {
            return $c->response->redirect('conf.cgi?sub=objects&data.id='.$obj->get_id());
        }
    }

    return;
}

##########################################################
sub _object_move {
    my($self, $c, $obj) = @_;

    my $files_root = $self->_set_files_stash($c, 1);
    if($c->stash->{action} eq 'movefile') {
        my $new_file = $c->{'request'}->{'parameters'}->{'newfile'};
        my $file     = $self->_get_context_file($c, $obj, $new_file);
        if(defined $file and $c->{'obj_db'}->move_object($obj, $file)) {
            Thruk::Utils::set_message( $c, 'success_message', ucfirst($c->stash->{'type'}).' \''.$obj->get_name().'\' moved successfully' );
        }

        # create log message
        $c->log->info(sprintf("[config][%s][%s] moved %s '%s' to '%s'",
                                    $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'name'},
                                    $c->stash->{'remote_user'},
                                    $obj->get_type(),
                                    $obj->get_name(),
                                    $file->{'path'},
        )) unless $ENV{'THRUK_TEST_CONF_NO_LOG'};

        return $c->response->redirect('conf.cgi?sub=objects&data.id='.$obj->get_id());
    }
    elsif($c->stash->{action} eq 'move') {
        $c->stash->{'template'}  = 'conf_objects_move.tt';
    }
    return;
}

##########################################################
sub _object_clone {
    my($self, $c, $obj) = @_;

    my $files_root          = $self->_set_files_stash($c, 1);
    $c->stash->{'new_file'} = $obj->{'file'}->{'display'};
    $c->stash->{'new_file'} =~ s/^$files_root/\//gmx;
    # if cloned from a readonly file, keep new_file empty
    if($obj->{'file'}->{'readonly'}) { $c->stash->{'new_file'} = ''; }
    $obj = Monitoring::Config::Object->new(type     => $obj->get_type(),
                                           conf     => $obj->{'conf'},
                                           coretype => $c->{'obj_db'}->{'coretype'});
    return $obj;
}


##########################################################
sub _object_new {
    my($self, $c) = @_;

    $self->_set_files_stash($c, 1);
    $c->stash->{'new_file'} = '';
    my $obj = Monitoring::Config::Object->new(type     => $c->stash->{'type'},
                                              name     => $c->stash->{'data_name'},
                                              coretype => $c->{'obj_db'}->{'coretype'});

    if(!defined $obj) {
        Thruk::Utils::set_message( $c, 'fail_message', 'Failed to create object' );
        return;
    }

    # set initial config from cgi parameters
    my $initial_conf = $obj->get_data_from_param($c->{'request'}->{'parameters'}, $obj->{'conf'});
    if($obj->has_object_changed($initial_conf)) {
        $c->{'obj_db'}->update_object($obj, $initial_conf );
    }

    return $obj;
}


##########################################################
sub _file_delete {
    my($self, $c) = @_;

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
    my($self, $c) = @_;

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
    my($self, $c) = @_;

    my $filename = $c->{'request'}->{'parameters'}->{'file'}    || '';
    my $content  = $c->{'request'}->{'parameters'}->{'content'} || '';
    my $lastline = $c->{'request'}->{'parameters'}->{'line'};
    my $file     = $c->{'obj_db'}->get_file_by_path($filename);
    my $lastobj;
    if(defined $file) {
        $lastobj = $file->update_objects_from_text($content, $lastline);
        $c->{'obj_db'}->_rebuild_index();
        my $files_root                   = $self->_set_files_stash($c, 1);
        $c->{'obj_db'}->{'needs_commit'} = 1;
        $c->stash->{'file_name'}         = $file->{'display'};
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
    return $c->response->redirect('conf.cgi?sub=objects&action=browser#'.$file->{'display'});
}

##########################################################
sub _file_editor {
    my($self, $c) = @_;

    my $files_root  = $self->_set_files_stash($c);
    my $filename    = $c->{'request'}->{'parameters'}->{'file'} || '';
    my $file        = $c->{'obj_db'}->get_file_by_path($filename);
    if(defined $file) {
        $c->stash->{'file'}          = $file;
        $c->stash->{'line'}          = $c->{'request'}->{'parameters'}->{'line'} || 1;
        $c->stash->{'back'}          = $c->{'request'}->{'parameters'}->{'back'} || '';
        $c->stash->{'file_link'}     = $file->{'display'};
        $c->stash->{'file_name'}     = $file->{'display'};
        $c->stash->{'file_name'}     =~ s/^$files_root//gmx;
        $c->stash->{'file_content'}  = decode_utf8($file->get_new_file_content());
        $c->stash->{'template'}      = 'conf_objects_fileeditor.tt';
    } else {
        Thruk::Utils::set_message( $c, 'fail_message', 'File does not exist' );
    }
    return;
}

##########################################################
sub _file_browser {
    my($self, $c) = @_;

    $self->_set_files_stash($c);
    $c->stash->{'template'} = 'conf_objects_filebrowser.tt';
    return;
}

##########################################################
sub _file_history {
    my($self, $c) = @_;

    return 1 unless $c->stash->{'has_history'};

    my $commit     = $c->{'request'}->{'parameters'}->{'id'};
    my $files_root = $c->{'obj_db'}->get_files_root();
    my $dir        = $c->{'obj_db'}->{'config'}->{'git_base_dir'} || $c->config->{'Thruk::Plugin::ConfigTool'}->{'git_base_dir'} || $files_root;

    $c->stash->{'template'} = 'conf_objects_filehistory.tt';

    if($commit) {
        return if $self->_file_history_commit($c, $commit, $dir);
    }

    my $logs = $self->_get_git_logs($c, $dir);

    Thruk::Backend::Manager::_page_data(undef, $c, $logs);
    $c->stash->{'logs'} = $logs;
    $c->stash->{'dir'}  = $dir;
    return;
}

##########################################################
sub _file_history_commit {
    my($self, $c, $commit, $dir) = @_;

    # verify our commit id
    if($commit !~ m/^[a-zA-Z0-9]+$/mx) {
        Thruk::Utils::set_message( $c, 'fail_message', 'Not a valid commit id!' );
        return;
    }

    $c->stash->{'template'}   = 'conf_objects_filehistory_commit.tt';

    my $data = $self->_get_git_commit($c, $dir, $commit);
    if(!$data) {
        Thruk::Utils::set_message( $c, 'fail_message', 'Not a valid commit!' );
        return;
    }

    $c->{'stash'}->{'previous'} = '';
    $c->{'stash'}->{'next'}     = '';
    my $logs = $self->_get_git_logs($c, $dir);
    for my $l (@{$logs}) {
        if($l->{'id'} eq $data->{'id'}) {
            $c->{'stash'}->{'previous'} = $self->_get_git_commit($c, $dir, $l->{'previous'}) if $l->{'previous'};
            $c->{'stash'}->{'next'}     = $self->_get_git_commit($c, $dir, $l->{'next'})     if $l->{'next'};
            last;
        }
    }

    # make new files visible
    $data->{'diff'} =~ s/\-\-\-\s+\/dev\/null\n\+\+\+\s+b\/(.*?)$/--- a\/$1/gmxs;
    $data->{'diff'} = Thruk::Utils::Filter::escape_html($data->{'diff'});

    # changed files
    our $diff_link_nr    = 0;
    our $diff_link_files = [];
    $data->{'diff'} =~ s/^(\-\-\-\s+a\/.*)$/&_diff_link($1)/gemx;
    $data->{'diff'} = Thruk::Utils::beautify_diff($data->{'diff'});
    $data->{'diff'} =~ s/^\s+//gmx;

    $c->{'stash'}->{'dir'}    = $dir;
    $c->{'stash'}->{'data'}   = $data;
    $c->{'stash'}->{'links'}  = $diff_link_files;

    return 1;
}

##########################################################
sub _get_git_logs {
    my($self, $c, $dir) = @_;
    my $cmd = "cd '".$dir."' && git log --pretty='format:".join("\x1f", '%h', '%an', '%ae', '%at', '%s')."\x1e' -- .";
    my $out = `$cmd`;
    my $logs = [];
    my $last;
    for my $line (split("\x1e", $out)) {
        my @d = split("\x1f", $line);
        next if scalar @d < 5;
        $d[0] =~ s/^\n//mx;
        my $data = {
            'id'           => $d[0],
            'author_name'  => $d[1],
            'author_email' => $d[2],
            'date'         => $d[3],
            'message'      => $d[4],
            'next'         => '',
            'previous'     => '',
        };
        push @{$logs}, $data;
        $last->{'previous'} = $data->{'id'} if $last;
        $data->{'next'}     = $last->{'id'} if $last;
        $last = $data;
    }
    return $logs;
}

##########################################################
sub _get_git_commit {
    my($self, $c, $dir, $commit) = @_;
    my $cmd = "cd '".$dir."' && git show --pretty='format:".join("\x1f", '%h', '%an', '%ae', '%at', '%p', '%t', '%s', '%b')."\x1f' ".$commit;
    my $output = `$cmd`;
    my @d = split(/\x1f/mx, $output);
    return if scalar @d < 4;
    my $data = {
            'id'           => $d[0],
            'author_name'  => $d[1],
            'author_email' => $d[2],
            'date'         => $d[3],
            'parent'       => $d[4],
            'tree'         => $d[5],
            'message'      => $d[6],
            'body'         => $d[7],
            'diff'         => $d[8],
    };
    return $data;
}

##########################################################
sub _diff_link {
    my($text) = @_;
    our $diff_link_nr;
    our $diff_link_files;
    $diff_link_files->[$diff_link_nr] = $text;
    $diff_link_files->[$diff_link_nr] =~ s/^\-\-\-\s+a\///gmx;
    $text = "<hr><a name='file".$diff_link_nr."'></a>\n".$text;
    $diff_link_nr++;
    return $text;
}

##########################################################
sub _object_tree {
    my($self, $c) = @_;

    # create list of templates
    for my $type (qw/host service contact/) {
        my $templates = {};
        my $objs = $c->{'obj_db'}->get_templates_by_type($type);
        for my $o (@{$objs}) {
            next if $o->{'disabled'};
            if(!defined $o->{'conf'}->{'use'}) {
                $templates->{$o->get_template_name()} = $o;
            } else {
                for my $tname (@{$o->{'conf'}->{'use'}}) {
                    my $t = $c->{'obj_db'}->get_template_by_name($type, $tname);
                    $t->{'child_templates'} = {} unless defined $t->{'child_templates'};
                    $t->{'child_templates'}->{$o->get_template_name()} = $o;
                }
            }
        }
        $c->stash->{$type.'templates'} = $templates;
    }

    $c->stash->{'template'} = 'conf_objects_tree.tt';
    return;
}

##########################################################
sub _object_tree_objects {
    my($self, $c) = @_;

    my $type     = $c->{'request'}->{'parameters'}->{'type'}     || '';
    my $template = $c->{'request'}->{'parameters'}->{'template'};
    my $origin   = $c->{'request'}->{'parameters'}->{'origin'};
    my $objs = [];
    if($type) {
        my $filter;
        if(defined $template) {
            $filter = {};
            $filter->{'use'} = $template
        }
        $objs = $c->{'obj_db'}->get_objects_by_type($type, $filter, $origin);
        $c->stash->{'objects_type'} = $type;
    } else {
        $objs = $c->{'obj_db'}->get_objects();
        $c->stash->{'objects_type'} = 'all';
    }

    # sort by name
    @{$objs} = sort {uc($a->get_name()) cmp uc($b->get_name())} @{$objs};

    $c->stash->{'tree_objects_layout'} = 'table';
    if(defined $c->request->cookie('thruk_obj_layout')) {
        $c->stash->{'tree_objects_layout'} = $c->request->cookie('thruk_obj_layout')->value();
    }

    my $all_files  = $c->{'obj_db'}->get_files();
    my $files_tree = $self->_files_to_path($c, $all_files);
    my $files_root = $files_tree->{'path'};
    $c->stash->{'files_tree'} = $files_tree;
    $c->stash->{'files_root'} = $files_root;

    $c->stash->{'objects'}  = $objs;
    $c->stash->{'template'} = 'conf_objects_tree_objects.tt';
    return;
}

##########################################################
sub _host_list_services {
    my($self, $c, $obj) = @_;

    my $services = $c->{'obj_db'}->get_services_for_host($obj);
    $c->stash->{'services'} = $services ;

    $c->stash->{'template'} = 'conf_objects_host_list_services.tt';
    return;
}

##########################################################
sub _list_references {
    my($self, $c, $obj) = @_;

    # references from other objects
    my $refs = $c->{'obj_db'}->get_references($obj);
    my $incoming = {};
    for my $type (keys %{$refs}) {
        $incoming->{$type} = {};
        for my $id (keys %{$refs->{$type}}) {
            my $obj = $c->{'obj_db'}->get_object_by_id($id);
            $incoming->{$type}->{$obj->get_name()} = $id;
        }
    }

    # references from this to other objects
    my $outgoing = {};
    my $resolved = $obj->get_resolved_config($c->{'obj_db'});
    for my $attr (keys %{$resolved}) {
        my $refs = $resolved->{$attr};
        if(ref $refs eq '') { $refs = [$refs]; }
        if(defined $obj->{'default'}->{$attr} && $obj->{'default'}->{$attr}->{'link'}) {
            my $type = $obj->{'default'}->{$attr}->{'link'};
            for my $r (@{$refs}) {
                if($type eq 'command') { $r =~ s/\!.*$//mx; }
                $outgoing->{$type}->{$r} = '';
            }
        }
    }
    # add used templates
    if(defined $obj->{'conf'}->{'use'}) {
        for my $t (@{$obj->{'conf'}->{'use'}}) {
            $outgoing->{$obj->get_type()}->{$t} = '';
        }
    }

    # linked from delete object page?
    $c->stash->{'force_delete'} = $c->{'request'}->{'parameters'}->{'show_force'} ? 1 : 0;

    $c->stash->{'incoming'} = $incoming;
    $c->stash->{'outgoing'} = $outgoing;
    $c->stash->{'template'} = 'conf_objects_listref.tt';
    return;
}

##########################################################
sub _config_check {
    my($c) = @_;
    if($c->{'obj_db'}->is_remote() and $c->{'obj_db'}->remote_config_check($c)) {
        Thruk::Utils::set_message( $c, 'success_message', 'config check successfull' );
    }
    elsif(!$c->{'obj_db'}->is_remote() and _cmd(undef, $c, $c->stash->{'peer_conftool'}->{'obj_check_cmd'})) {
        Thruk::Utils::set_message( $c, 'success_message', 'config check successfull' );
    } else {
        Thruk::Utils::set_message( $c, 'fail_message', 'config check failed!' );
    }
    _nice_check_output($c);

    $c->stash->{'obj_model_changed'} = 0 unless $c->{'request'}->{'parameters'}->{'refresh'};
    $c->stash->{'needs_commit'}      = $c->{'obj_db'}->{'needs_commit'};
    $c->stash->{'last_changed'}      = $c->{'obj_db'}->{'last_changed'};
    return;
}

##########################################################
sub _config_reload {
    my($c) = @_;

    if($c->{'obj_db'}->is_remote() and $c->{'obj_db'}->remote_config_reload($c)) {
        Thruk::Utils::set_message( $c, 'success_message', 'config reloaded successfully' );
        $c->stash->{'last_changed'} = 0;
        $c->stash->{'needs_commit'} = 0;
    }
    elsif(!$c->{'obj_db'}->is_remote() and _cmd(undef, $c, $c->stash->{'peer_conftool'}->{'obj_reload_cmd'})) {
        Thruk::Utils::set_message( $c, 'success_message', 'config reloaded successfully' );
        $c->stash->{'last_changed'} = 0;
        $c->stash->{'needs_commit'} = 0;
    } else {
        Thruk::Utils::set_message( $c, 'fail_message', 'config reload failed!' );
    }

    _nice_check_output($c);

    # wait until core responds again
    for(1..30) {
        sleep(1);
        eval {
            local $SIG{'PIPE'}='IGNORE'; # exits sometimes on reload
            $c->{'db'}->reset_failed_backends();
            $c->{'db'}->get_processinfo();
        };
        if(!$@ and !defined $c->{'stash'}->{'failed_backends'}->{$c->stash->{'param_backend'}}) {
            last;
        }
    }

    # reload navigation, probably some names have changed
    $c->stash->{'reload_nav'} = 1;

    $c->stash->{'obj_model_changed'} = 0 unless $c->{'request'}->{'parameters'}->{'refresh'};
    return;
}

##########################################################
sub _nice_check_output {
    my($c) = @_;
    $c->{'stash'}->{'output'} =~ s/(Error\s*:.*)$/<b><font color="red">$1<\/font><\/b>/gmx;
    $c->{'stash'}->{'output'} =~ s/(Warning\s*:.*)$/<b><font color="#FFA500">$1<\/font><\/b>/gmx;
    $c->{'stash'}->{'output'} =~ s/(CONFIG\s+ERROR.*)$/<b><font color="red">$1<\/font><\/b>/gmx;
    $c->{'stash'}->{'output'} =~ s/(\(config\s+file\s+'(.*?)',\s+starting\s+on\s+line\s+(\d+)\))/<a href="conf.cgi?sub=objects&amp;file=$2&amp;line=$3">$1<\/a>/gmx;
    $c->{'stash'}->{'output'} =~ s/\s+in\s+file\s+'(.*?)'\s+on\s+line\s+(\d+)/ in file <a href="conf.cgi?sub=objects&amp;type=file&amp;file=$1&amp;line=$2">'$1' on line $2<\/a>/gmx;
    $c->{'stash'}->{'output'} =~ s/\s+in\s+(\w+)\s+'(.*?)'/ in $1 '<a href="conf.cgi?sub=objects&amp;type=$1&amp;data.name=$2">$2<\/a>'/gmx;
    $c->{'stash'}->{'output'} =~ s/Warning:\s+(\w+)\s+'(.*?)'\s+/Warning: $1 '<a href="conf.cgi?sub=objects&amp;type=$1&amp;data.name=$2">$2<\/a>' /gmx;
    $c->{'stash'}->{'output'} =~ s/Error:\s+(\w+)\s+'(.*?)'\s+/Error: $1 '<a href="conf.cgi?sub=objects&amp;type=$1&amp;data.name=$2">$2<\/a>' /gmx;
    $c->{'stash'}->{'output'} =~ s/Error\s*:\s*the\s+service\s+([^\s]+)\s+on\s+host\s+'([^']+)'/Error: the service <a href="conf.cgi?sub=objects&amp;type=service&amp;data.name=$1&amp;data.name2=$2">$1<\/a> on host '$2'/gmx;
    $c->{'stash'}->{'output'} = "<pre>".$c->{'stash'}->{'output'}."</pre>";
    return;
}

##########################################################
# check for external reloads
sub _check_external_reload {
    my($c) = @_;

    return unless defined $c->{'obj_db'}->{'last_changed'};

    if($c->{'obj_db'}->{'last_changed'} > 0) {
        my $last_reloaded = $c->stash->{'pi_detail'}->{$c->stash->{'param_backend'}}->{'program_start'} || 0;
        if($last_reloaded > $c->{'obj_db'}->{'last_changed'}) {
            $c->{'obj_db'}->{'last_changed'} = 0;
            $c->stash->{'last_changed'}      = 0;
        }
    }
    return;
}

##########################################################
# return nicer addon name
sub _nice_addon_name {
    my($name) = @_;
    my $dir = $name;
    $dir =~ s/\/+$//gmx;
    $dir =~ s/^.*\///gmx;
    my $nicename = join(' ', map(ucfirst, split(/_/mx, $dir)));
    return($nicename, $dir);
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
