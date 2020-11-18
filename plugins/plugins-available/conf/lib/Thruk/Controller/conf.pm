package Thruk::Controller::conf;

use strict;
use warnings;
use Monitoring::Config;
use Socket qw/inet_ntoa/;
use File::Copy;
use Cpanel::JSON::XS;
use Storable qw/dclone/;
use Data::Dumper qw/Dumper/;
use File::Slurp qw/read_file/;
use Encode qw/decode_utf8 encode_utf8/;
use Thruk::Utils::References;
use Thruk::Utils::Conf;
use Thruk::Utils::Conf::Defaults;
use Thruk::Utils::Plugin;
use Thruk::Authentication::User;
use Thruk::Utils::Log qw/:all/;
#use Thruk::Timer qw/timing_breakpoint/;

=head1 NAME

Thruk::Controller::conf - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

##########################################################

=head2 index

=cut
sub index {
    my($c) = @_;

    # Safe Defaults required for changing backends
    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_SAFE_DEFAULTS);
    #&timing_breakpoint('index start');

    my $subcat = $c->req->parameters->{'sub'}    || '';
    my $action = $c->req->parameters->{'action'} || 'show';

    # check permissions
    if($action eq 'user_password') {
        # ok
    }
    elsif(!$c->check_user_roles("admin")) {
        if(    !defined $c->{'db'}
            || !defined $c->{'db'}->{'backends'}
            || ref $c->{'db'}->{'backends'} ne 'ARRAY'
            || scalar @{$c->{'db'}->{'backends'}} == 0 ) {
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
    $c->stash->{'disable_backspace'}   = 1;
    $c->stash->{'has_refs'}            = 0;
    $c->stash->{'link_obj'}            = \&Thruk::Utils::Conf::link_obj;
    $c->stash->{no_tt_trim}            = 1;
    $c->stash->{post_obj_save_cmd}     = $c->config->{'Thruk::Plugin::ConfigTool'}->{'post_obj_save_cmd'}   // '';
    $c->stash->{show_summary_prompt}   = $c->config->{'Thruk::Plugin::ConfigTool'}->{'show_summary_prompt'} // 1;

    Thruk::Utils::ssi_include($c);

    # check if we have at least one file configured
    if(   !defined $c->config->{'Thruk::Plugin::ConfigTool'}
       || ref($c->config->{'Thruk::Plugin::ConfigTool'}) ne 'HASH'
       || scalar keys %{$c->config->{'Thruk::Plugin::ConfigTool'}} == 0
    ) {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'Config Tool is disabled.<br>Please have a look at the <a href="'.$c->stash->{'url_prefix'}.'documentation.html#_component_thruk_plugin_configtool">config tool setup instructions</a>.', escape => 0 } );
    }

    if(exists $c->req->parameters->{'edit'} and defined $c->req->parameters->{'host'}) {
        $subcat = 'objects';
    }

    # workaround for when specified more than once in the url...
    $subcat = shift @{$subcat} if ref $subcat eq 'ARRAY';

    $c->stash->{sub}          = $subcat;
    $c->stash->{action}       = $action;
    $c->stash->{conf_config}  = $c->config->{'Thruk::Plugin::ConfigTool'} || {};
    $c->stash->{has_obj_conf} = scalar keys %{Thruk::Utils::Conf::get_backends_with_obj_config($c)};

    #&timing_breakpoint('index starting subs');
    # set default
    $c->stash->{conf_config}->{'show_plugin_syntax_helper'} = 1 unless defined $c->stash->{conf_config}->{'show_plugin_syntax_helper'};

    if($action eq 'user_password') {
        return _process_user_password_page($c);
    }
    elsif($action eq 'cgi_contacts') {
        return _process_cgiusers_page($c);
    }
    elsif($action eq 'json') {
        return _process_json_page($c);
    }

    # show settings page
    if($subcat eq 'cgi') {
        return if Thruk::Action::AddDefaults::die_when_no_backends($c);
        _process_cgi_page($c);
    }
    elsif($subcat eq 'thruk') {
        _process_thruk_page($c);
    }
    elsif($subcat eq 'users') {
        return if Thruk::Action::AddDefaults::die_when_no_backends($c);
        _process_users_page($c);
    }
    elsif($subcat eq 'plugins') {
        _process_plugins_page($c);
    }
    elsif($subcat eq 'backends') {
        _process_backends_page($c);
    }
    elsif($subcat eq 'objects') {
        $c->stash->{'obj_model_changed'} = 0;
        _process_objects_page($c);
        Thruk::Utils::Conf::store_model_retention($c, $c->stash->{'param_backend'}) if $c->stash->{'obj_model_changed'};
        $c->stash->{'parse_errors'} = $c->{'obj_db'}->{'parse_errors'};
    }

    #&timing_breakpoint('index done');
    return 1;
}


##########################################################
# return json list for ajax search
sub _process_json_page {
    my( $c ) = @_;

    return unless Thruk::Utils::Conf::set_object_model($c);

    my $type = $c->req->parameters->{'type'} || 'hosts';
    $type    =~ s/s$//gmxo;

    # name resolver
    if($type eq 'dig') {
        return unless Thruk::Utils::check_csrf($c);
        my $resolved = 'unknown';
        if(defined $c->req->parameters->{'host'} and $c->req->parameters->{'host'} ne '') {
            my @addresses = gethostbyname($c->req->parameters->{'host'});
            @addresses = map { inet_ntoa($_) } @addresses[4 .. $#addresses];
            if(scalar @addresses > 0) {
                $resolved = join(' ', @addresses);
            }
        }
        my $json = { 'address' => $resolved };
        return $c->render(json => $json);
    }

    # icons?
    if($type eq 'icon') {
        my $objects = [];
        my $themes_dir = $c->config->{'themes_path'} || $c->config->{'home'}."/themes";
        my $icon_dirs  = Thruk::Utils::list($c->config->{'physical_logo_path'} || $themes_dir."/themes-available/Thruk/images/logos");
        for my $dir (@{$icon_dirs}) {
            $dir =~ s/\/$//gmx;
            next unless -d $dir.'/.';
            my $files = _find_files($c, $dir, '\.(png|gif|jpg)$');
            for my $file (@{$files}) {
                $file =~ s/$dir\///gmx;
                push @{$objects}, $file." - ".$c->stash->{'logo_path_prefix'}.$file;
            }
        }
        my $json = [ { 'name' => $type.'s', 'data' => $objects } ];
        return $c->render(json => $json);
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
        if(defined $c->req->parameters->{'withargs'}) {
            push @{$objects}, ('$ARG1$', '$ARG2$', '$ARG3$', '$ARG4$', '$ARG5$');
        }
        if(defined $c->req->parameters->{'withuser'}) {
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
            if(defined $c->req->parameters->{'plugin'} and $c->req->parameters->{'plugin'} ne '') {
                my $help = $c->{'obj_db'}->get_plugin_help($c, $c->req->parameters->{'plugin'});
                my @options = $help =~ m/(\-[\w\d]|\-\-[\d\w\-_]+)[=|,|\s|\$]/gmx;
                push @{$json}, { 'name' => 'arguments', 'data' => Thruk::Utils::array_uniq(\@options) } if scalar @options > 0;
            }
        }
        return $c->render(json => $json);
    }

    # plugins
    if($type eq 'plugin') {
        my $plugins = $c->{'obj_db'}->get_plugins($c);
        my $json    = [ { 'name' => 'plugins', 'data' => [ sort keys %{$plugins} ] } ];
        return $c->render(json => $json);
    }

    # plugin help
    if($type eq 'pluginhelp' and $c->stash->{conf_config}->{'show_plugin_syntax_helper'}) {
        return unless Thruk::Utils::check_csrf($c);
        my $help = $c->{'obj_db'}->get_plugin_help($c, $c->req->parameters->{'plugin'});
        my $json = [ { 'plugin_help' => $help } ];
        return $c->render(json => $json);
    }

    # plugin preview
    if($type eq 'pluginpreview' and $c->stash->{conf_config}->{'show_plugin_syntax_helper'}) {
        return unless Thruk::Utils::check_csrf($c);
        my $output = $c->{'obj_db'}->get_plugin_preview($c,
                                         $c->req->parameters->{'command'},
                                         $c->req->parameters->{'args'},
                                         $c->req->parameters->{'host'},
                                         $c->req->parameters->{'service'},
                                     );
        my $json   = [ { 'plugin_output' => $output } ];
        return $c->render(json => $json);
    }

    # command line
    if($type eq 'commanddetail') {
        return unless Thruk::Utils::check_csrf($c);
        my $name    = $c->req->parameters->{'command'};
        my $objects = $c->{'obj_db'}->get_objects_by_name('command', $name);
        my $json = [ { 'cmd_line' => '' } ];
        if(defined $objects->[0]) {
            $json = [ { 'cmd_line' => $objects->[0]->{'conf'}->{'command_line'} } ];
        }
        return $c->render(json => $json);
    }

    # servicemembers
    if($type eq 'servicemember') {
        return unless Thruk::Utils::Conf::set_object_model($c);
        $c->{'obj_db'}->read_rc_file();
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
        return $c->render(json => $json);
    }

    # service_description, same host service descriptions
    if($type eq 'service_description') {
        return unless Thruk::Utils::Conf::set_object_model($c);
        $c->{'obj_db'}->read_rc_file();
        my $descriptions = [];
        my $objects;
        my $ref = $c->req->parameters->{'ref'} ? $c->{'obj_db'}->get_object_by_id($c->req->parameters->{'ref'}) : undef;
        if($ref) {
            my $hosts = $c->{'obj_db'}->get_hosts_for_service($ref);
            for my $id (values %{$hosts}) {
                my $hst = $c->{'obj_db'}->get_object_by_id($id);
                push @{$objects}, $hst if $hst;
            }
        } else {
            $objects = $c->{'obj_db'}->get_objects_by_type('host');
        }
        for my $host (@{$objects}) {
            my $services = $c->{'obj_db'}->get_services_for_host($host);
            for my $svc (keys %{$services->{'group'}}, keys %{$services->{'host'}}) {
                push @{$descriptions}, $svc;
            }
        }
        my $json = [{ 'name' => $type.'s',
                      'data' => [ sort @{Thruk::Utils::array_uniq($descriptions)} ],
                   }];
        return $c->render(json => $json);
    }

    # objects attributes
    if($type eq 'attribute') {
        my $for  = $c->req->parameters->{'obj'};
        my $attr = $c->{'obj_db'}->get_default_keys($for, { no_alias => 1 });
        if($c->stash->{conf_config}->{'extra_custom_var_'.$for}) {
            for my $extra (@{Thruk::Utils::list($c->stash->{conf_config}->{'extra_custom_var_'.$for})}) {
                my @extras = split/\s*,\s*/mx, $extra;
                push @{$attr}, @extras;
            }
        }
        $attr = [ sort @{Thruk::Utils::array_uniq($attr)} ];

        # add existing custom variables from this type
        my $vars = Thruk::Utils::Status::get_custom_variable_names($c, $for, 0);
        for my $v (@{$vars}) {
            $v =~ s/^_*/_/gmx;
            push @{$attr}, $v;
        }

        my $json = [{ 'name' => $type.'s',
                      'data' => $attr,
                   }];
        return $c->render(json => $json);
    }

    # objects
    my $json;
    my $objects   = [];
    my $templates = [];
    my $filter    = $c->req->parameters->{'filter'};
    my $use_long  = $c->req->parameters->{'long'};
    if(defined $filter) {
        $json       = [];
        my $types   = {};
        my $objects = $c->{'obj_db'}->get_objects_by_type($type,$filter);
        for my $subtype (keys %{$objects}) {
            for my $name (keys %{$objects->{$subtype}}) {
                $types->{$subtype}->{$name} = 1 unless substr($name,0,1) eq '!';
            }
        }
        for my $typ (sort keys %{$types}) {
            push @{$json}, {
                  'name' => _translate_type($typ)."s",
                  'data' => [ sort keys %{$types->{$typ}} ],
            };
        }
    } else {
        for my $dat (@{$c->{'obj_db'}->get_objects_by_type($type)}) {
            my $name = $use_long ? $dat->get_long_name(undef, '  -  ') : $dat->get_name();
            if(defined $name) {
                if($dat->{'disabled'}) { $name = $name.' (disabled)' }
                push @{$objects}, $name;
            } else {
                _warn("object without a name in ".$dat->{'file'}->{'path'}.":".$dat->{'line'}." -> ".Dumper($dat->{'conf'}));
            }
        }
        for my $dat (@{$c->{'obj_db'}->get_templates_by_type($type)}) {
            my $name = $dat->get_template_name();
            if(defined $name) {
                push @{$templates}, $name;
            } else {
                _warn("template without a name in ".$dat->{'file'}->{'path'}.":".$dat->{'line'}." -> ".Dumper($dat->{'conf'}));
            }
        }
        $json = [ { 'name' => $type.'s',
                    'data' => [ sort @{Thruk::Utils::array_uniq($objects)} ],
                  },
                  { 'name' => $type.' templates',
                    'data' => [ sort @{Thruk::Utils::array_uniq($templates)} ],
                  },
                ];
    }
    return $c->render(json => $json);
}


##########################################################
# create the cgi.cfg config page
sub _process_cgiusers_page {
    my( $c ) = @_;

    my $contacts        = Thruk::Utils::Conf::get_cgi_user_list($c);
    delete $contacts->{'*'}; # we dont need this user here
    my $data            = [ values %{$contacts} ];
    my $json            = [ { 'name' => "contacts", 'data' => $data } ];
    return $c->render(json => $json);
}


##########################################################
# create the cgi.cfg config page
sub _process_cgi_page {
    my( $c ) = @_;

    my $file     = $c->config->{'Thruk::Plugin::ConfigTool'}->{'cgi.cfg'};
    return unless defined $file;
    $c->stash->{'readonly'} = (-w $file) ? 0 : 1;

    # create a default config from the current used cgi.cfg
    if(!-e $file && $file ne $c->config->{'cgi.cfg_effective'}) {
        copy($c->config->{'cgi.cfg_effective'}, $file) or die('cannot copy '.$c->config->{'cgi.cfg_effective'}.' to '.$file.': '.$!);
    }

    my $defaults = Thruk::Utils::Conf::Defaults->get_cgi_cfg();

    # save changes
    if($c->stash->{action} eq 'store') {
        if($c->stash->{'readonly'}) {
            Thruk::Utils::set_message( $c, 'fail_message', 'file is readonly' );
            return $c->redirect_to('conf.cgi?sub=cgi');
        }
        return unless Thruk::Utils::check_csrf($c);

        my $data = Thruk::Utils::Conf::get_data_from_param($c->req->parameters, $defaults);
        # check for empty multi selects
        for my $key (keys %{$defaults}) {
            next if $key !~ m/^authorized_for_/mx;
            $data->{$key} = [] unless defined $data->{$key};
        }
        _store_changes($c, $file, $data, $defaults);
        return $c->redirect_to('conf.cgi?sub=cgi');
    }

    my($content, $data, $hex) = Thruk::Utils::Conf::read_conf($file, $defaults);

    # get list of cgi users
    my $tmp = Thruk::Utils::Conf::get_cgi_user_list($c);
    my $cgi_contacts = {};
    for my $u (values %{$tmp}) {
        if($u->{'alias'}) {
            $cgi_contacts->{$u->{'name'}} = $u->{'name'}.' - '.$u->{'alias'};
        } else {
            $cgi_contacts->{$u->{'name'}} = $u->{'name'};
        }
    }

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

    my $authkeys = [qw/
        use_authentication
        use_ssl_authentication
        default_user_name
        lock_author_names
    /];
    my $authgroupkeys = [];
    for my $key (@{$Thruk::Authentication::User::possible_roles}) {
        push @{$authkeys}, $key;
        my $groupkey = $key;
        $groupkey =~ s/^authorized_for_/authorized_contactgroup_for_/gmx;
        push @{$authgroupkeys}, $groupkey;
    }

    my $keys = [
        [ 'CGI Settings', [qw/
                        show_context_help
                        use_pending_states
                        refresh_rate
                        escape_html_tags
                        action_url_target
                        notes_url_target
                    /],
        ],
        [ 'Authorization', $authkeys],
        [ 'Authorization Groups', $authgroupkeys],
    ];

    $c->stash->{'keys'}     = $keys;
    $c->stash->{'data'}     = $data;
    $c->stash->{'hex'}      = $hex;
    $c->stash->{'subtitle'} = "CGI &amp; Access Configuration";
    $c->stash->{'template'} = 'conf_data.tt';

    return 1;
}

##########################################################
# create the thruk config page
sub _process_thruk_page {
    my( $c ) = @_;

    my $file     = $c->config->{'Thruk::Plugin::ConfigTool'}->{'thruk'};
    return unless defined $file;
    my $defaults = Thruk::Utils::Conf::Defaults->get_thruk_cfg($c);
    $c->stash->{'readonly'} = (-w $file) ? 0 : 1;

    # save changes
    if($c->stash->{action} eq 'store') {
        if($c->stash->{'readonly'}) {
            Thruk::Utils::set_message( $c, 'fail_message', 'file is readonly' );
            return $c->redirect_to('conf.cgi?sub=thruk');
        }
        return unless Thruk::Utils::check_csrf($c);

        my $data = Thruk::Utils::Conf::get_data_from_param($c->req->parameters, $defaults);
        if(_store_changes($c, $file, $data, $defaults, $c)) {
            return Thruk::Utils::restart_later($c, $c->stash->{url_prefix}.'cgi-bin/conf.cgi?sub=thruk');
        } else {
            return $c->redirect_to('conf.cgi?sub=thruk');
        }
    }

    my($content, $data, $hex) = Thruk::Utils::Conf::read_conf($file, $defaults);

    my $keys = [
        [ 'General', [qw/
                        title_prefix
                        use_wait_feature
                        wait_timeout
                        use_frames
                        server_timezone
                        default_user_timezone
                        use_strict_host_authorization
                        show_long_plugin_output
                        info_popup_event_type
                        info_popup_options
                        resource_file
                        can_submit_commands
                     /],
        ],
        [ 'Paths', [qw/
                        tmp_path
                        ssi_path
                        plugin_path
                        user_template_path
                    /],
        ],
        [ 'Menu', [qw/
                        start_page
                        documentation_link
                        all_problems_link
                        allowed_frame_links
                    /],
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
                    /],
        ],
        [ 'Paging', [qw/
                        use_pager
                        paging_steps
                        group_paging_overview
                        group_paging_summary
                        group_paging_grid
                    /],
        ],
    ];

    $c->stash->{'keys'}     = $keys;
    $c->stash->{'data'}     = $data;
    $c->stash->{'hex'}      = $hex;
    $c->stash->{'subtitle'} = "Thruk Configuration";
    $c->stash->{'template'} = 'conf_data.tt';

    return 1;
}

##########################################################
# create the users config page
sub _process_users_page {
    my( $c ) = @_;

    my $file     = $c->config->{'Thruk::Plugin::ConfigTool'}->{'cgi.cfg'};
    return unless defined $file;
    my $defaults = Thruk::Utils::Conf::Defaults->get_cgi_cfg();
    $c->stash->{'readonly'} = (-w $file) ? 0 : 1;

    my $user = $c->req->parameters->{'data.username'} || '';
    my($name, $alias, $profile_file);
    if($user ne '') {
        ($name, $alias) = split(/\ \-\ /mx,$user, 2);
        $profile_file = $c->config->{'var_path'}."/users/".$name;
        $c->stash->{'profile_file'} = $profile_file;
        $c->stash->{'profile_file_exists'} = -e $profile_file ? 1 : 0;
    }

    # save changes to user
    if($user ne '' and defined $file and $c->stash->{action} eq 'store') {
        my($name, $alias) = split(/\ \-\ /mx,$user, 2);
        return unless Thruk::Utils::check_csrf($c);
        my $redirect = 'conf.cgi?action=change&sub=users&data.username='.$user;
        if($c->stash->{'readonly'}) {
            Thruk::Utils::set_message( $c, 'fail_message', 'file is readonly' );
            return $c->redirect_to($redirect);
        }
        my $msg = _update_password($c);
        if(defined $msg) {
            Thruk::Utils::set_message( $c, 'fail_message', $msg );
            return $c->redirect_to($redirect);
        }

        my $send = $c->req->parameters->{'send'} || '';
        if($send eq 'lock account' || $send eq 'unlock account') {
            my $userdata = Thruk::Utils::get_user_data($c, $name);
            if($send eq 'unlock account') {
                delete $userdata->{'login'}->{'locked'};
            } else {
                $userdata->{'login'}->{'locked'} = 1;
            }
            Thruk::Utils::store_user_data($c, $userdata, $name);
        }
        if($send eq 'remove user profile data') {
            if(!Thruk::Utils::check_for_nasty_filename($name)) {
                unlink($profile_file);
                Thruk::Utils::set_message( $c, 'success_message', 'profile removed successfully' );
            }
            return $c->redirect_to($redirect);
        }

        # save changes to cgi.cfg
        my($content, $data, $hex) = Thruk::Utils::Conf::read_conf($file, $defaults);
        my $new_data              = {};
        for my $key (keys %{$c->req->parameters}) {
            next unless $key =~ m/data\.authorized_for_/mx;
            $key =~ s/^data\.//gmx;
            my $users = {};
            for my $usr (@{$data->{$key}->[1]}) {
                $users->{$usr} = 1;
            }
            if($c->req->parameters->{'data.'.$key}) {
                $users->{$user} = 1;
            } else {
                delete $users->{$user};
            }
            @{$new_data->{$key}} = sort keys %{$users};
        }
        _store_changes($c, $file, $new_data, $defaults);

        Thruk::Utils::set_message( $c, 'success_message', 'User saved successfully' );
        return $c->redirect_to($redirect);
    }

    $c->stash->{'show_user'}  = 0;
    $c->stash->{'user_name'}  = '';

    if($c->stash->{action} eq 'change' and $user ne '') {
        my($content, $data, $hex) = Thruk::Utils::Conf::read_conf($file, $defaults);
        $c->stash->{'show_user'}  = 1;
        $c->stash->{'user_name'}  = $name;
        $c->stash->{'hex'}        = $hex;
        $c->stash->{'roles'}      = {};
        my $roles = $Thruk::Authentication::User::possible_roles;
        $c->stash->{'role_keys'}  = $roles;
        for my $role (@{$roles}) {
            $c->stash->{'roles'}->{$role} = 0;
            for my $tst (@{$data->{$role}->[1]}) {
                $c->stash->{'roles'}->{$role}++ if $tst eq $name;
            }
        }

        $c->stash->{'has_htpasswd_entry'} = 0;
        $c->stash->{'htpasswd_file'}      = $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'} // '';
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

        $c->stash->{'profile_user'} = Thruk::Authentication::User->new($c, $name)->set_dynamic_attributes($c);
    }

    $c->stash->{'subtitle'} = "User Configuration";
    $c->stash->{'template'} = 'conf_data_users.tt';

    return 1;
}

##########################################################
# create the plugins config page
sub _process_plugins_page {
    my( $c ) = @_;

    my $project_root         = $c->config->{home};
    my $plugin_dir           = $c->config->{'plugin_path'} || $project_root."/plugins";
    my $plugin_enabled_dir   = $plugin_dir.'/plugins-enabled';
    my $plugin_available_dir = $project_root.'/plugins/plugins-available';

    $c->stash->{'readonly'}  = 0;
    if(! -d $plugin_enabled_dir || ! -w $plugin_enabled_dir ) {
        $c->stash->{'readonly'}  = 1;
    }

    my $plugins = Thruk::Utils::Plugin::get_plugins($c);

    if($c->stash->{action} eq 'preview') {
        my $pic = $c->req->parameters->{'pic'} || die("missing pic");
        if($pic !~ m/^[a-zA-Z0-9_\ \-]+$/gmx) {
            die("unknown pic: ".$pic);
        }
        my $path = $plugin_enabled_dir.'/'.$pic.'/preview.png';
        if(!-e $path) {
            $path = $plugin_available_dir.'/'.$pic.'/preview.png';
        }
        $c->res->headers->content_type('image/png');
        $c->stash->{'text'} = "";
        if(-e $path) {
            $c->stash->{'text'} = read_file($path);
        }
        $c->stash->{'template'} = 'passthrough.tt';
        return 1;
    }
    elsif($c->stash->{action} eq 'save') {
        return unless Thruk::Utils::check_csrf($c);
        # don't store in demo mode
        if($c->config->{'demo_mode'}) {
            Thruk::Utils::set_message( $c, 'fail_message', "save is disabled in demo mode" );
            return $c->redirect_to('conf.cgi?sub=plugins');
        }
        if(! -d $plugin_enabled_dir || ! -w $plugin_enabled_dir ) {
            Thruk::Utils::set_message( $c, 'fail_message', 'Make sure plugins folder ('.$plugin_enabled_dir.') is writeable: '.$! );
        }
        else {
            for my $addon (glob($plugin_available_dir.'/*/')) {
                my($addon_name, $dir) = Thruk::Utils::Plugin::nice_addon_name($addon);
                if(!defined $c->req->parameters->{'plugin.'.$dir} || $c->req->parameters->{'plugin.'.$dir} == 0) {
                    Thruk::Utils::Plugin::disable_plugin($c, $dir) if $plugins->{$dir}->{'enabled'};
                }
                if(defined $c->req->parameters->{'plugin.'.$dir} and $c->req->parameters->{'plugin.'.$dir} == 1) {
                    Thruk::Utils::Plugin::enable_plugin($c, $dir) unless $plugins->{$dir}->{'enabled'};
                }
            }
            Thruk::Utils::set_message( $c, 'success_message', 'Plugins changed successfully.' );
            return Thruk::Utils::restart_later($c, $c->stash->{url_prefix}.'cgi-bin/conf.cgi?sub=plugins&reload_nav=1');
        }
    }

    $c->stash->{'plugins'}  = $plugins;
    $c->stash->{'subtitle'} = "Thruk Addons &amp; Plugin Manager";
    $c->stash->{'template'} = 'conf_plugins.tt';

    return 1;
}

##########################################################
# create the backends config page
sub _process_backends_page {
    my( $c ) = @_;

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
        return unless Thruk::Utils::check_csrf($c);
        # don't store in demo mode
        if($c->config->{'demo_mode'}) {
            Thruk::Utils::set_message( $c, 'fail_message', "save is disabled in demo mode" );
            return $c->redirect_to('conf.cgi?sub=backends');
        }
        if($c->stash->{'readonly'}) {
            Thruk::Utils::set_message( $c, 'fail_message', 'file is readonly' );
            return $c->redirect_to('conf.cgi?sub=backends');
        }

        my $numbers = [];
        for my $key (sort keys %{$c->req->parameters}) {
            if($key =~ m/^name(\d+)/mx) {
                push @{$numbers}, $1;
            }
        }
        my $backends = {};
        my $has_new = 0;
        for my $x (sort { $a <=> $b } @{$numbers}) {
            my $backend = {
                'name'    => $c->req->parameters->{'name'.$x},
                'type'    => $c->req->parameters->{'type'.$x},
                'id'      => $c->req->parameters->{'id'.$x},
                'hidden'  => defined $c->req->parameters->{'hidden'.$x} ? $c->req->parameters->{'hidden'.$x} : 0,
                'section' => $c->req->parameters->{'section'.$x},
                'options' => {},
            };
            $backend->{'options'}->{'peer'}         = $c->req->parameters->{'peer'.$x}        if $c->req->parameters->{'peer'.$x};
            $backend->{'options'}->{'auth'}         = $c->req->parameters->{'auth'.$x}        if $c->req->parameters->{'auth'.$x};
            $backend->{'options'}->{'proxy'}        = $c->req->parameters->{'proxy'.$x}       if $c->req->parameters->{'proxy'.$x};
            $backend->{'options'}->{'remote_name'}  = $c->req->parameters->{'remote_name'.$x} if $c->req->parameters->{'remote_name'.$x};
            $x++;
            $backend->{'name'} = 'backend '.$x if(!$backend->{'name'} && $backend->{'options'}->{'peer'});
            next unless $backend->{'name'};
            delete $backend->{'id'} if $backend->{'id'} eq '';

            $backend->{'options'}->{'peer'} = Thruk::Utils::list($backend->{'options'}->{'peer'});

            for my $p (@{$backend->{'options'}->{'peer'}}) {
                if($backend->{'type'} eq 'livestatus' and $p =~ m/^\d+\.\d+\.\d+\.\d+$/mx) {
                    $p .= ':6557';
                }
            }

            # add values from existing backend config
            my $savefile = $file;
            if(defined $backend->{'id'}) {
                my $peer = $c->{'db'}->get_peer_by_key($backend->{'id'});
                $backend->{'options'}->{'resource_file'} = $peer->{'resource_file'} if defined $peer->{'resource_file'};
                $backend->{'options'}->{'fallback_peer'} = $peer->{'config'}->{'options'}->{'fallback_peer'} if defined $peer->{'config'}->{'options'}->{'fallback_peer'};
                $backend->{'groups'}     = $peer->{'groups'}     if defined $peer->{'groups'};
                $backend->{'configtool'} = $peer->{'configtool'} if defined $peer->{'configtool'};
                $backend->{'state_host'} = $peer->{'config'}->{'state_host'} if defined $peer->{'config'}->{'state_host'};
                $savefile = $peer->{'peer_config'}->{'_FILE'} // $file;
            }
            $has_new = 1 if $x == 1;
            $savefile =~ s|/thruk\.conf$|/thruk_local.conf|gmx;
            $backends->{$savefile} = [] unless $backends->{$savefile};
            push @{$backends->{$savefile}}, $backend;
        }
        # put new one at the end
        if($has_new) { push(@{$backends->{$file}}, shift(@{$backends->{$file}})) }
        for my $f (sort keys %{$backends}) {
            my $string = Thruk::Utils::Conf::get_component_as_string($backends->{$f});
            Thruk::Utils::Conf::replace_block($f, $string, '<Component\s+Thruk::Backend>', '<\/Component>\s*');
        }
        Thruk::Utils::set_message( $c, 'success_message', 'Backends changed successfully.' );
        return Thruk::Utils::restart_later($c, $c->stash->{url_prefix}.'cgi-bin/conf.cgi?sub=backends');
    }
    if($c->stash->{action} eq 'check_con') {
        return unless Thruk::Utils::check_csrf($c);
        my $peer        = $c->req->parameters->{'peer'};
        my $type        = $c->req->parameters->{'type'};
        my $auth        = $c->req->parameters->{'auth'};
        my $proxy       = $c->req->parameters->{'proxy'};
        my $remote_name = $c->req->parameters->{'remote_name'};
        my @test;
        eval {
            local $ENV{'THRUK_USE_LMD'} = "";
            my $con = Thruk::Backend::Peer->new({
                                                 type    => $type,
                                                 name    => 'test connection',
                                                 options => { peer => $peer, auth => $auth, proxy => $proxy, remote_name => $remote_name },
                                                }, $c->config);
            @test   = $con->{'class'}->get_processinfo();
        };
        my $json;
        if(scalar @test >= 2 and ref $test[0] eq 'HASH' and scalar keys %{$test[0]} == 1 and scalar keys %{$test[0]->{(keys %{$test[0]})[0]}} > 0) {
            $json = { ok => 1 };
        } else {
            my $error = $@;
            $error =~ s/\s+at\s\/.*//gmx;
            $error = 'got no valid result' if $error eq '';
            $json = { ok => 0, error => $error };
        }
        return $c->render(json => $json);
    }

    my $backends = [];
    my $peers    = $c->{'db'}->get_peers(1);
    push @{$peers}, {} if scalar @{$peers} == 0;
    for my $p (@{$peers}) {
        my $b = Thruk::Utils::dclone($p->{'peer_config'});
        $b->{'name'}        = $b->{'name'} // '';
        $b->{'type'}        = lc($b->{'type'} // 'livestatus');
        $b->{'id'}          = $p->{'key'}  // substr(Thruk::Utils::Crypt::hexdigest(($b->{'options'}->{'peer'} || '')." ".$b->{'name'}), 0, 5);
        $b->{'addr'}        = $b->{'options'}->{'peer'}  || '';
        $b->{'auth'}        = $b->{'options'}->{'auth'}  || '';
        $b->{'proxy'}       = $b->{'options'}->{'proxy'} || '';
        $b->{'remote_name'} = $b->{'options'}->{'remote_name'} || '';
        $b->{'hidden'}      = $b->{'hidden'}  // 0;
        $b->{'section'}     = $b->{'section'} // '';
        $b->{'file'}        = $b->{'_FILE'}   // $file;
        $b->{'lineno'}      = $b->{'_LINE'}   // '';
        push @{$backends}, $b;
    }
    $c->stash->{'conf_file'}  = $file;
    $c->stash->{'conf_sites'} = $backends;
    $c->stash->{'subtitle'}   = "Thruk Backends Manager";
    $c->stash->{'template'}   = 'conf_backends.tt';

    return 1;
}

##########################################################
# create the objects config page
sub _process_objects_page {
    my( $c ) = @_;

    my $rc = Thruk::Utils::Conf::set_object_model($c);
    if($rc == -1) {
        $c->stash->{errorMessage}       = "config tool unavailable";
        $c->stash->{errorDescription}   = $c->stash->{set_object_model_err} || '';
        return $c->detach('/error/index/99');
    } elsif($rc == 0) {
        return;
    }

    _check_external_reload($c);

    $c->stash->{'subtitle'}         = "Object Configuration";
    $c->stash->{'template'}         = 'conf_objects.tt';
    $c->stash->{'file_link'}        = "";
    $c->stash->{'coretype'}         = $c->{'obj_db'}->{'coretype'};
    $c->stash->{'bare'}             = $c->req->parameters->{'bare'} || 0;
    $c->stash->{'has_history'}      = 0;

    # start editing files
    if(defined $c->req->parameters->{'start_edit'}) {
        my $file = Thruk::Utils::Conf::start_file_edit($c, $c->req->parameters->{'start_edit'});
        if($file) {
            return $c->render(json => {'ok' => 1, hex => $file->{'hex'} });
        }
        return $c->render(json => {'ok' => 0 });
    }

    $c->{'obj_db'}->read_rc_file();

    # check if we have a history for our configs
    my $files_root = _set_files_stash($c);
    my $dir        = $c->{'obj_db'}->{'config'}->{'git_base_dir'} || $c->config->{'Thruk::Plugin::ConfigTool'}->{'git_base_dir'} || $files_root;
    if(-d $dir) {
        my $cmd       = "cd '".$dir."' && git log --pretty='format:%H' -1 2>&1";
        my($rc, $out) = Thruk::Utils::IO::cmd($c, $cmd);
        $c->stash->{'has_history'} = 1 if $rc == 0;
    }

    # apply changes?
    if(defined $c->req->parameters->{'apply'}) {
        return if _apply_config_changes($c);
    }

    # tools menu
    if(defined $c->req->parameters->{'tools'}) {
        return if _process_tools_page($c);
    }

    # get object from params
    $c->stash->{cloned}    = 0;
    $c->stash->{clone_ref} = Thruk::Utils::list($c->req->parameters->{'clone_ref'} || []);
    my $obj = _get_context_object($c);
    if(defined $obj) {

        # revert all changes from one file
        if($c->stash->{action} eq 'revert') {
            return unless Thruk::Utils::check_csrf($c);
            return if _object_revert($c, $obj);
        }

        # save this object
        elsif($c->stash->{action} eq 'store') {
            return unless Thruk::Utils::check_csrf($c);
            my $rc = _object_save($c, $obj);
            if($rc && defined $c->req->parameters->{'cloned'}) {
                if(!$obj->is_template()) {
                    _clone_refs($c, $obj, $c->req->parameters->{'cloned'}, $c->req->parameters->{'clone_ref'});
                }
            }

            # save changes to cgi.cfg
            my $type = $obj->get_type();
            my $file = $c->config->{'Thruk::Plugin::ConfigTool'}->{'cgi.cfg'};
            if($c->stash->{'conf_config'}->{'cgi.cfg'} && ($type eq 'contactgroup' || $type eq 'contact') && -w $file) {
                my $name     = $obj->get_name();
                my $defaults = Thruk::Utils::Conf::Defaults->get_cgi_cfg();
                my($content, $data, $hex) = Thruk::Utils::Conf::read_conf($file, $defaults);
                my $new_data              = {};
                for my $key (keys %{$c->req->parameters}) {
                    next unless $key =~ m/authdata\.authorized_for_/mx;
                    $key =~ s/^authdata\.//gmx;
                    my $key2 = $key;
                    if($type eq 'contactgroup') {
                        $key2 =~ s/^authorized_for_/authorized_contactgroup_for_/gmx;
                    }
                    my $users = {};
                    for my $usr (@{$data->{$key2}->[1]}) {
                        $users->{$usr} = 1;
                    }
                    if($c->req->parameters->{'authdata.'.$key}) {
                        $users->{$name} = 1;
                    } else {
                        delete $users->{$name};
                    }
                    @{$new_data->{$key2}} = sort keys %{$users};
                }
                _store_changes($c, $file, $new_data, $defaults, undef, 1);
            }

            if(defined $c->req->parameters->{'save_and_reload'}) {
                return if _apply_config_changes($c);
            }
            return if !defined $rc;
            $c->stash->{cloned} = $c->req->parameters->{'cloned'} || 0;
        }

        # disable this object temporarily
        elsif($c->stash->{action} eq 'disable') {
            return unless Thruk::Utils::check_csrf($c);
            return if _object_disable($c, $obj);
        }

        # enable this object
        elsif($c->stash->{action} eq 'enable') {
            return unless Thruk::Utils::check_csrf($c);
            return if _object_enable($c, $obj);
        }

        # delete this object
        elsif($c->stash->{action} eq 'delete') {
            return unless Thruk::Utils::check_csrf($c);
            return if _object_delete($c, $obj);
        }

        # move objects
        elsif(   $c->stash->{action} eq 'move'
              or $c->stash->{action} eq 'movefile') {
            return if _object_move($c, $obj);
        }

        # clone this object
        elsif($c->stash->{action} eq 'clone') {
            return unless Thruk::Utils::check_csrf($c);
            $c->stash->{cloned} = $obj->get_id() || 0;
            # select refs to clone if there are some
            if(!$obj->is_template() && !$c->req->parameters->{'clone_ref'}) {
                my $cloned_name = $obj->get_name();
                my $clonables   = $c->{'obj_db'}->clone_refs($obj, $obj, $cloned_name, $cloned_name."_2", undef, 1);
                if($clonables && scalar keys %{$clonables} > 0) {
                    $c->stash->{object}     = $obj;
                    $c->stash->{clonables}  = $clonables;
                    $c->stash->{'template'} = 'conf_choose_clone.tt';
                    return;
                }
            }
            $obj = _object_clone($c, $obj);
        }

        # list services for host
        elsif($c->stash->{action} eq 'listservices' and $obj->get_type() eq 'host') {
            return if _host_list_services($c, $obj);
        }

        # list references
        elsif($c->stash->{action} eq 'listref') {
            return if _list_references($c, $obj);
        }
    }

    # create new object
    if($c->stash->{action} eq 'new') {
        $obj = _object_new($c);
    }

    # browse files
    elsif($c->stash->{action} eq 'browser') {
        return if _file_browser($c);
    }

    # object tree
    elsif($c->stash->{action} eq 'tree') {
        return if _object_tree($c);
    }

    # object tree content
    elsif($c->stash->{action} eq 'tree_objects') {
        return if _object_tree_objects($c);
    }

    # file editor
    elsif($c->stash->{action} eq 'editor') {
        return if _file_editor($c);
    }

    # history
    elsif($c->stash->{action} eq 'history') {
        return if _file_history($c);
    }

    # save changed files from editor
    elsif($c->stash->{action} eq 'savefile') {
        return unless Thruk::Utils::check_csrf($c);
        return if _file_save($c);
    }

    # delete files/folders from browser
    elsif($c->stash->{action} eq 'deletefiles') {
        return unless Thruk::Utils::check_csrf($c);
        return if _file_delete($c);
    }

    # undelete files/folders from browser
    elsif($c->stash->{action} eq 'undeletefiles') {
        return unless Thruk::Utils::check_csrf($c);
        return if _file_undelete($c);
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
        if($obj->{'file'} && $obj->{'file'}->{'path'} && !$obj->{'file'}->readonly()) {
            Thruk::Utils::Conf::start_file_edit($c, $obj->{'file'}->{'path'});
        }
        $c->stash->{'file_link'} = $obj->{'file'}->{'display'} if defined $obj->{'file'};
        _gather_references($c, $obj);

        # add roles
        if($c->stash->{'conf_config'}->{'cgi.cfg'} && ($c->stash->{'type'} eq 'contactgroup' || $c->stash->{'type'} eq 'contact')) {
            my $file     = $c->config->{'Thruk::Plugin::ConfigTool'}->{'cgi.cfg'};
            my $defaults = Thruk::Utils::Conf::Defaults->get_cgi_cfg();
            my($content, $data, $hex) = Thruk::Utils::Conf::read_conf($file, $defaults);
            my $roles = $Thruk::Authentication::User::possible_roles;
            $c->stash->{'hex'}       = $hex;
            $c->stash->{'role_keys'} = $roles;
            for my $role (@{$roles}) {
                $c->stash->{'roles'}->{$role} = 0;
                my $tstrole = $role;
                if($c->stash->{'type'} eq 'contactgroup') {
                    $tstrole =~ s/^authorized_for_/authorized_contactgroup_for_/gmx;
                }
                for my $tst (@{$data->{$tstrole}->[1]}) {
                    $c->stash->{'roles'}->{$role}++ if $tst eq $c->stash->{'data_name'};
                }
            }
        }
    }

    # set default type for start page
    if($c->stash->{action} eq 'show' and $c->stash->{type} eq '') {
        $c->stash->{type} = 'host';
    }

    $c->stash->{'needs_commit'}      = $c->{'obj_db'}->{'needs_commit'};
    $c->stash->{'last_changed'}      = $c->{'obj_db'}->{'last_changed'};
    $c->stash->{'referer'}           = $c->req->parameters->{'referer'} || '';
    $c->{'obj_db'}->_reset_errors(1);
    return 1;
}

##########################################################
# apply config changes
sub _apply_config_changes {
    my ( $c ) = @_;

    $c->stash->{'subtitle'}      = "Apply Config Changes";
    $c->stash->{'template'}      = 'conf_objects_apply.tt';
    $c->stash->{'output'}        = '';
    $c->stash->{'changed_files'} = $c->{'obj_db'}->get_changed_files();

    local $ENV{'THRUK_SUMMARY_MESSAGE'} = $c->req->parameters->{'summary'}     if $c->req->parameters->{'summary'};
    local $ENV{'THRUK_SUMMARY_DETAILS'} = $c->req->parameters->{'summarydesc'} if $c->req->parameters->{'summarydesc'};

    if(defined $c->req->parameters->{'save_and_reload'}) {
        return unless Thruk::Utils::check_csrf($c);
        # don't store in demo mode
        if($c->config->{'demo_mode'}) {
            Thruk::Utils::set_message( $c, 'fail_message', "save is disabled in demo mode" );
            return $c->redirect_to('conf.cgi?sub=objects&apply=yes');
        }
        if($c->{'obj_db'}->commit($c)) {
            # update changed files
            $c->stash->{'changed_files'} = $c->{'obj_db'}->get_changed_files();
            # set flag to do the reload
            $c->req->parameters->{'reload'} = 'yes';
        } else {
            return $c->redirect_to('conf.cgi?sub=objects&apply=yes');
        }
    }

    # get diff of changed files
    if(defined $c->req->parameters->{'diff'}) {
        my $ignore_whitespace_changes = $c->req->parameters->{'ignore_whitespace'} // 0;
        my $diffs = {};
        for my $file (@{$c->stash->{'changed_files'}}) {
            my $diff = $file->diff($ignore_whitespace_changes);
            if($diff ne '') {
                $diffs->{$file->{'display'}} = $diff;
            }
        }

        $c->stash->{'output'} .= "<hr style='margin: 0;'>\n";
        $c->stash->{'output'} .= "<form action='conf.cgi#output' method='POST' class='diffoptions'>\n";
        $c->stash->{'output'} .= "<input type='hidden' name='diff' value='1'>\n";
        $c->stash->{'output'} .= "<input type='hidden' name='apply' value='yes'>\n";
        $c->stash->{'output'} .= "<input type='hidden' name='sub' value='objects'>\n";
        $c->stash->{'output'} .= "<input type='checkbox' name='ignore_whitespace' id='ignore_whitespace' value='1'".($ignore_whitespace_changes ? ' checked' : '')."><label for='ignore_whitespace'>Ignore Whitespace Changes</label>\n";
        $c->stash->{'output'} .= "<input type='submit' value='update'>\n";
        $c->stash->{'output'} .= "</form>\n";

        if(scalar keys %{$diffs} == 0) {
            if($ignore_whitespace_changes) {
                return $c->redirect_to('conf.cgi?sub=objects&apply=yes&diff=1&ignore_whitespace=0');
            }
            $c->stash->{'output'} .= "<br><br>no changes\n";
            return;
        }

        $c->stash->{'output'} .= "<ul>\n";
        for my $file_display (sort keys %{$diffs}) {
            $c->stash->{'output'} .= "<li><a href='#".Thruk::Utils::Filter::name2id($file_display)."'>".$file_display."</a></li>\n";
        }
        $c->stash->{'output'} .= "</ul>\n";

        for my $file_display (sort keys %{$diffs}) {
            $c->stash->{'output'} .= "<hr><a id='".Thruk::Utils::Filter::name2id($file_display)."'></a><pre>\n";
            $c->stash->{'output'} .= Thruk::Utils::Filter::escape_html($diffs->{$file_display});
            $c->stash->{'output'} .= "</pre><br>\n";
        }

        $c->stash->{'output'} = Thruk::Utils::beautify_diff($c->stash->{'output'});
    }

    # config check
    elsif(defined $c->req->parameters->{'check'}) {
        return unless Thruk::Utils::check_csrf($c);
        if(defined $c->stash->{'peer_conftool'}->{'obj_check_cmd'}) {
            $c->stash->{'parse_errors'} = $c->{'obj_db'}->{'parse_errors'};
            Thruk::Utils::External::perl($c, { expr    => 'Thruk::Controller::conf::_config_check($c)',
                                               message => 'please stand by while configuration is beeing checked...',
                                        });
            return;
        } else {
            Thruk::Utils::set_message( $c, 'fail_message', "please set 'obj_check_cmd' in your thruk_local.conf" );
        }
    }

    # config reload
    elsif(defined $c->req->parameters->{'reload'}) {
        return unless Thruk::Utils::check_csrf($c);
        # don't store in demo mode
        if($c->config->{'demo_mode'}) {
            Thruk::Utils::set_message( $c, 'fail_message', "reload is disabled in demo mode" );
            return $c->redirect_to('conf.cgi?sub=objects&apply=yes');
        }
        if(defined $c->stash->{'peer_conftool'}->{'obj_reload_cmd'} or $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'type'} ne 'configonly') {
            $c->stash->{'parse_errors'} = $c->{'obj_db'}->{'parse_errors'};
            Thruk::Utils::External::perl($c, { expr    => 'Thruk::Controller::conf::_config_reload($c)',
                                               message => 'please stand by while configuration is beeing reloaded...',
                                        });
            return;
        } else {
            Thruk::Utils::set_message( $c, 'fail_message', "please set 'obj_reload_cmd' in your thruk_local.conf" );
        }
    }

    # save changes to file
    elsif(defined $c->req->parameters->{'save'}) {
        return unless Thruk::Utils::check_csrf($c);
        # don't store in demo mode
        if($c->config->{'demo_mode'}) {
            Thruk::Utils::set_message( $c, 'fail_message', "save is disabled in demo mode" );
            return $c->redirect_to('conf.cgi?sub=objects&apply=yes');
        }
        if($c->{'obj_db'}->commit($c)) {
            $c->stash->{'obj_model_changed'} = 1;
            Thruk::Utils::set_message( $c, 'success_message', 'Changes saved to disk successfully' );
        }
        return $c->redirect_to('conf.cgi?sub=objects&apply=yes');
    }

    # discard changes
    if($c->req->parameters->{'discard'}) {
        return unless Thruk::Utils::check_csrf($c);
        $c->{'obj_db'}->discard_changes();
        $c->stash->{'obj_model_changed'} = 1;
        Thruk::Utils::set_message( $c, 'success_message', 'Changes have been discarded' );
        return $c->redirect_to('conf.cgi?sub=objects&apply=yes');
    }

    $c->stash->{'needs_commit'} = $c->{'obj_db'}->{'needs_commit'};
    $c->stash->{'last_changed'} = $c->{'obj_db'}->{'last_changed'};
    $c->stash->{'files'}        = $c->{'obj_db'}->get_files();
    return;
}

##########################################################
# show tools page
sub _process_tools_page {
    my ( $c ) = @_;

    $c->stash->{'subtitle'}  = 'Config Tools';
    $c->stash->{'template'}  = 'conf_objects_tools.tt';
    $c->stash->{'output'}    = '';
    $c->stash->{'action'}    = 'tools';
    $c->stash->{'results'}   = [];
    my $tool                 = $c->req->parameters->{'tools'} || '';
    $tool                    =~ s/[^a-zA-Z_]//gmx;
    my $tools                = _get_tools($c);
    $c->stash->{'tools'}     = $tools;
    my $ignore_file          = $c->config->{'var_path'}.'/conf_tools_ignore';
    my $ignores              = -s $ignore_file ? Thruk::Utils::IO::json_lock_retrieve($ignore_file) : {};
    $c->stash->{'tool'}      = $tool;

    $c->stats->profile(begin => "tool: ".$tool);

    if($tool eq 'start') {
    }
    elsif($tool eq 'reset_ignores') {
        $tool = $c->req->parameters->{'oldtool'};
        if(defined $tools->{$tool}) {
            $ignores->{$tool} = {};
            Thruk::Utils::IO::json_lock_store($ignore_file, $ignores);
            Thruk::Utils::set_message( $c, 'success_message', "successfully reset ignores" );
        }
        $c->stats->profile(end => "tool: ".$tool);
        return $c->redirect_to('conf.cgi?sub=objects&tools='.$tool);
    }
    elsif(defined $tools->{$tool}) {
        if($c->req->parameters->{'ignore'}) {
            $ignores->{$tool}->{$c->req->parameters->{'ident'}} = 1;
            Thruk::Utils::IO::json_lock_store($ignore_file, $ignores);
            my $json = {'ok' => 1};
            $c->stats->profile(end => "tool: ".$tool);
            return $c->render(json => $json);
        }
        # this might take a while
        $c->stash->{'parse_errors'} = $c->{'obj_db'}->{'parse_errors'};
        return if Thruk::Utils::External::render_page_in_background($c);

        $c->stash->{'toolobj'} = $tools->{$tool};
        if($c->req->parameters->{'cleanup'} && $c->req->parameters->{'ident'}) {
            $c->stats->profile(begin => "tool cleanup");
            $tools->{$tool}->cleanup($c, $c->req->parameters->{'ident'}, $ignores->{$tool});
            $c->stats->profile(end => "tool cleanup");
            $c->stash->{'obj_model_changed'} = 1;
            if($c->req->parameters->{'ident'} eq 'all') {
                $c->stats->profile(end => "tool: ".$tool);
                return $c->redirect_to('conf.cgi?sub=objects&tools='.$tool);
            }
            my $json = {'ok' => 1};
            $c->stats->profile(end => "tool: ".$tool);
            return $c->render(json => $json);
        } else {
            $c->stats->profile(begin => "tool get_list");
            my($hidden, $results) = $tools->{$tool}->get_list($c, $ignores->{$tool});
            $c->stats->profile(end => "tool get_list");
            @{$results} = sort { $a->{'type'} cmp $b->{'type'} || $a->{'name'} cmp $b->{'name'} } @{$results};
            $c->stash->{'results'} = $results;
            $c->stash->{'hidden'}  = $hidden;
        }
    } else {
        $c->stash->{'tool'} = "start";
    }

    # sort tools into categories
    my $tools_by_category = {};
    for my $name (keys %{$tools}) {
        my $t = $tools->{$name};
        $tools_by_category->{$t->{category}}->{$name} = $t;
    }
    $c->stash->{'tools_by_category'} = $tools_by_category;

    $c->stats->profile(end => "tool: ".$tool);
    return;
}

##########################################################
# create the users password page
sub _process_user_password_page {
    my($c) = @_;

    my $referer = $c->req->parameters->{'referer'} || $c->stash->{'url_prefix'}.'main.html';
    if($c->config->{'disable_user_password_change'}) {
        Thruk::Utils::set_message($c, 'fail_message', "Changing passwords is disabled.");
        return $c->redirect_to($referer);
    }

    my $htpw_file = $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'};
    if(!$htpw_file || !-w $htpw_file) {
        Thruk::Utils::set_message($c, 'fail_message', "Changing passwords is disabled.");
        return $c->redirect_to($referer);
    }

    my $binary = _get_htpasswd();
    if(!$binary) {
        Thruk::Utils::set_message($c, 'fail_message', 'could not find htpasswd or htpasswd2, cannot update passwords');
        return $c->redirect_to($referer);
    }
    my $help        = Thruk::Utils::IO::cmd("$binary --help 2>&1");
    my $has_minus_v = $help =~ m|\s+\-v\s+|gmx;

    my $user     = $c->user->get('username');
    my $htpasswd = Thruk::Utils::Conf::read_htpasswd($htpw_file);
    if(!defined $htpasswd->{$user}) {
        Thruk::Utils::set_message($c, 'fail_message', "Your password cannot be changed.");
        return $c->redirect_to($referer);
    }

    # change password?
    if($c->req->parameters->{'save'}) {
        return unless Thruk::Utils::check_csrf($c);

        my $old        = $c->req->parameters->{'data.old'}        || '';
        my $pass1      = $c->req->parameters->{'data.password'}   || '';
        my $pass2      = $c->req->parameters->{'data.password2'}  || '';
        my $min_length = $c->config->{'user_password_min_length'} || 5;
        if($has_minus_v && !$old) {
            Thruk::Utils::set_message($c, 'fail_message', "Current password missing");
        }
        elsif($pass1 eq '' || $pass2 eq '') {
            Thruk::Utils::set_message($c, 'fail_message', "New password cannot be empty");
        }
        elsif(length($pass1) < $min_length) {
            Thruk::Utils::set_message($c, 'fail_message', "New password must have at least ".$min_length." characters.");
        }
        elsif($pass1 ne '' && $pass1 eq $pass2) {
            my $err = _htpasswd_password($c, $user, $pass1, $old);
            if($err) {
                _error("changing password for ".$user." failed: ".$err);
                Thruk::Utils::set_message($c, 'fail_message', "Password change failed.");
            } else {
                _audit_log("configtool", "new password set for user ".$user);
                Thruk::Utils::set_message($c, 'success_message', "Password changed successfully");
            }
        }
        return $c->redirect_to('conf.cgi?action=user_password');
    }

    $c->stash->{'show_old_pass'} = $has_minus_v ? 1 : 0;
    $c->stash->{'subtitle'}      = "Change Password";
    $c->stash->{'template'}      = 'conf_user_password.tt';

    return 1;
}

##########################################################
# get list of all tools
sub _get_tools {
    my ($c) = @_;

    my $modules = Thruk::Utils::find_modules('/Thruk/Utils/Conf/Tools/*.pm');
    my $tools   = {};
    for my $file (@{$modules}) {
        require $file;
        my $class = $file;
        $class    =~ s|/|::|gmx;
        $class    =~ s|\.pm$||gmx;
        $class->import;
        my $tool = $class->new();
        my $name = $class;
        $name =~ s|Thruk::Utils::Conf::Tools::||gmx;
        $tools->{$name} = $tool;
    }

    return($tools);
}

##########################################################
# update a users password
sub _update_password {
    my ( $c ) = @_;

    my $user = $c->req->parameters->{'data.username'};
    my $send = $c->req->parameters->{'send'} || 'save';
    if(defined $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'}) {
        # remove password?
        if($send eq 'remove password') {
            return unless Thruk::Utils::check_csrf($c);
            my $err = _htpasswd_password($c, $user, undef);
            return $err if $err;
            _audit_log("configtool", "password removed for user ".$user);
            return;
        }

        # change password?
        my $pass1 = $c->req->parameters->{'data.password'}  || '';
        my $pass2 = $c->req->parameters->{'data.password2'} || '';
        if($pass1 ne '') {
            return unless Thruk::Utils::check_csrf($c);
            if($pass1 eq $pass2) {
                my $err = _htpasswd_password($c, $user, $pass1);
                return $err if $err;
                _audit_log("configtool", "new password set for user ".$user);
                return;
            } else {
                return('Passwords do not match');
            }
        }
    }
    return;
}

##########################################################
# store changes to a file
sub _htpasswd_password {
    my($c, $user, $password, $oldpassword) = @_;

    my $htpasswd = _get_htpasswd();
    return('could not find htpasswd or htpasswd2, cannot update passwords') unless $htpasswd;

    if(!defined $password) {
        my $cmd = [ $htpasswd, '-D', $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'}, $user ];
        if(_cmd($c, $cmd)) {
            return;
        }
        _error("failed to remove password.");
        _error("cmd: ".join(" ", @{$cmd}));
        _error($c->stash->{'output'});
        return( 'failed to remove password, check the logfile!' );
    }

    # check if htpasswd support -i switch
    my $help = Thruk::Utils::IO::cmd("$htpasswd --help 2>&1");
    my $has_minus_i = $help =~ m|\s+\-i\s+|gmx;
    my $has_minus_v = $help =~ m|\s+\-v\s+|gmx;

    # check old password first?
    if($has_minus_v && $oldpassword) {
        my $cmd = [$htpasswd];
        push @{$cmd}, '-c' unless -s $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'};
        push @{$cmd}, '-i' if  $has_minus_i;
        push @{$cmd}, '-b' if !$has_minus_i;
        push @{$cmd}, '-v';
        push @{$cmd}, $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'};
        push @{$cmd}, $user;
        push @{$cmd}, $oldpassword if !$has_minus_i;
        if(!_cmd($c, $cmd, $has_minus_i ? $oldpassword : undef)) {
            return('old password did not match');
        }
    }

    my $cmd = [$htpasswd];
    push @{$cmd}, '-c' unless -s $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'};
    push @{$cmd}, '-i' if $has_minus_i;
    push @{$cmd}, '-b' if !$has_minus_i;
    push @{$cmd}, $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'};
    push @{$cmd}, $user;
    push @{$cmd}, $password if !$has_minus_i;
    if(_cmd($c, $cmd, $has_minus_i ? $password : undef)) {
        return;
    }
    if(!$has_minus_i) {
        pop @{$cmd};
        push @{$cmd}, '****';
    }
    _error("failed to update password.");
    _error("cmd: ".join(" ", @{$cmd}));
    _error($c->stash->{'output'});
    return('failed to update password, check the logfile!');
}

##########################################################
# returns htpasswd path
sub _get_htpasswd {
    # htpasswd is usually somewhere in sbin
    # SLES11: htpasswd2 /usr/bin
    local $ENV{'PATH'} = ($ENV{'PATH'} || '').':/usr/sbin:/sbin:/usr/bin';
    my $htpasswd = Thruk::Utils::which('htpasswd2') || Thruk::Utils::which('htpasswd');
    return($htpasswd);
}

##########################################################
# store changes to a file
sub _store_changes {
    my ( $c, $file, $data, $defaults, $update_in_conf, $ignore_no_changes_made) = @_;
    return unless Thruk::Utils::check_csrf($c);
    my $old_hex = $c->req->parameters->{'hex'};
    if(!defined $old_hex || $old_hex eq '') {
        Thruk::Utils::set_message( $c, 'success_message', "no changes made." );
        return;
    }
    # don't store in demo mode
    if($c->config->{'demo_mode'}) {
        Thruk::Utils::set_message( $c, 'fail_message', "save is disabled in demo mode." );
        return;
    }
    _debug("saving config changes to ".$file);
    my $res = Thruk::Utils::Conf::update_conf($file, $data, $old_hex, $defaults, $update_in_conf);
    if(defined $res) {
        if($res eq "no changes made." && $ignore_no_changes_made) {
            return;
        }
        Thruk::Utils::set_message( $c, 'fail_message', $res );
        return;
    } else {
        Thruk::Utils::set_message( $c, 'success_message', 'Saved successfully.' );
    }
    return 1;
}

##########################################################
# execute cmd
sub _cmd {
    my($c, $cmd, $stdin) = @_;

    my($rc, $output) = Thruk::Utils::IO::cmd($c, $cmd, $stdin);
    $c->stash->{'output'} = $output;
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
    my($c) = @_;

    my $obj;

    $c->stash->{'type'}          = $c->req->parameters->{'type'}       || '';
    $c->stash->{'subcat'}        = $c->req->parameters->{'subcat'}     || 'config';
    $c->stash->{'data_name'}     = $c->req->parameters->{'data.name'}  || '';
    $c->stash->{'data_name2'}    = $c->req->parameters->{'data.name2'} || '';
    $c->stash->{'data_id'}       = $c->req->parameters->{'data.id'}    || '';
    $c->stash->{'file_name'}     = $c->req->parameters->{'file'};
    $c->stash->{'file_line'}     = $c->req->parameters->{'line'};
    $c->stash->{'data_name'}     =~ s/^(.*)\ \ \-\ \ .*$/$1/gmx;
    $c->stash->{'data_name'}     =~ s/\ \(disabled\)$//gmx;
    $c->stash->{'type'}          = lc $c->stash->{'type'};
    $c->stash->{'show_object'}   = 0;
    $c->stash->{'show_secondary_select'} = 0;

    if(defined $c->req->parameters->{'service'} and defined $c->req->parameters->{'host'}) {
        $c->stash->{'type'} = 'service';
        my $objs = $c->{'obj_db'}->get_services_by_name($c->req->parameters->{'host'}, $c->req->parameters->{'service'});
        if(defined $objs->[0]) {
            $c->stash->{'data_id'} = $objs->[0]->get_id();
        }
    }
    elsif(defined $c->req->parameters->{'host'}) {
        $c->stash->{'type'} = 'host';
        $c->stash->{'data_name'}  = $c->req->parameters->{'host'};
    }

    # remove leading plus signs (used to append to lists) and leading ! (used to negate in lists)
    $c->stash->{'data_name'} =~ s/^(\+|\!)//mx;

    # new object
    if($c->stash->{'data_id'} and $c->stash->{'data_id'} eq 'new') {
        $obj = Monitoring::Config::Object->new( type     => $c->stash->{'type'},
                                                coretype => $c->{'obj_db'}->{'coretype'},
                                              );
        my $new_file   = $c->req->parameters->{'data.file'} || '';
        my $file = get_context_file($c, $obj, $new_file);
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
    if(!defined $obj && defined $c->stash->{'file_name'} && defined $c->stash->{'file_line'} && $c->stash->{'file_line'} =~ m/^\d+$/mx) {
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
                    push @newobjs, $o if !defined $o->{'conf'}->{'register'} || $o->{'conf'}->{'register'} != 0;
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
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'No such object. <a href="conf.cgi?sub=objects&action=new&amp;type='.Thruk::Utils::Filter::escape_html($c->stash->{'type'}).'&amp;data.name='.Thruk::Utils::Filter::escape_html($c->stash->{'data_name'}).'">Create it.</a>', escape => 0 } );
        }
    }

    return $obj;
}

##########################################################

=head2 get_context_file

    returns file for name, creates new file unless already existing.

=cut
sub get_context_file {
    my($c, $obj, $new_file) = @_;
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
    my($type) = @_;
    my $tt   = {
        'host_name'      => 'host',
        'hostgroup_name' => 'hostgroup',
    };
    return $tt->{$type} if defined $type;
    return;
}

##########################################################
sub _files_to_path {
    my($c, $files) = @_;

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
    my($c, $skip_readonly_files) = @_;

    my $all_files  = $c->{'obj_db'}->get_files();
    my $files_tree = _files_to_path($c, $all_files);
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

    $c->stash->{'filenames_json'} = Thruk::Utils::Filter::json_encode([{ name => 'files', data => [ sort @filenames ]}]);
    $c->stash->{'files_json'}     = Thruk::Utils::Filter::json_encode($files_tree);
    $c->stash->{'files_tree'}     = $files_tree;

    return $files_root;
}

##########################################################
sub _object_revert {
    my($c, $obj) = @_;

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
            $c->stash->{'obj_model_changed'} = 1;
            $c->{'obj_db'}->update_object($obj, dclone($oldobj->{'conf'}), join("\n", @{$oldobj->{'comments'}}));
            Thruk::Utils::set_message( $c, 'success_message', ucfirst($obj->get_type()).' reverted successfully' );
        } else {
            Thruk::Utils::set_message( $c, 'fail_message', 'Cannot revert new objects, you can just delete them.' );
        }
    } else {
        Thruk::Utils::set_message( $c, 'fail_message', 'Cannot revert new objects, you can just delete them.' );
    }

    return $c->redirect_to('conf.cgi?sub=objects&data.id='.$obj->get_id());
}

##########################################################
sub _object_disable {
    my($c, $obj) = @_;

    my $id = $obj->get_id();
    $obj->{'disabled'}               = 1;
    $obj->{'file'}->{'changed'}      = 1;
    $c->{'obj_db'}->{'needs_commit'} = 1;
    $c->stash->{'obj_model_changed'} = 1;
    Thruk::Utils::set_message( $c, 'success_message', ucfirst($obj->get_type()).' disabled successfully' );

    # store log message
    $c->{'obj_db'}->{'logs'} = [] unless $c->{'obj_db'}->{'logs'};
    push @{$c->{'obj_db'}->{'logs'}},
        sprintf("[config][%s][%s] disabled %s '%s'",
                                $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'name'},
                                $c->stash->{'remote_user'},
                                $obj->get_type(),
                                $obj->get_name(),
    );

    return $c->redirect_to('conf.cgi?sub=objects&data.id='.$obj->get_id());
}

##########################################################
sub _object_enable {
    my($c, $obj) = @_;

    my $id = $obj->get_id();
    $obj->{'disabled'}               = 0;
    $obj->{'file'}->{'changed'}      = 1;
    $c->{'obj_db'}->{'needs_commit'} = 1;
    $c->stash->{'obj_model_changed'} = 1;
    Thruk::Utils::set_message( $c, 'success_message', ucfirst($obj->get_type()).' enabled successfully' );

    # create log message
    $c->{'obj_db'}->{'logs'} = [] unless $c->{'obj_db'}->{'logs'};
    push @{$c->{'obj_db'}->{'logs'}},
        sprintf("[config][%s][%s] enabled %s '%s'",
                                $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'name'},
                                $c->stash->{'remote_user'},
                                $obj->get_type(),
                                $obj->get_name(),
    );

    return $c->redirect_to('conf.cgi?sub=objects&data.id='.$obj->get_id());
}

##########################################################
sub _object_delete {
    my($c, $obj) = @_;

    my $refs       = $c->{'obj_db'}->get_references($obj);
    my $other_refs = _get_non_config_tool_references($c, $obj);

    if(!$c->req->parameters->{'force'}) {
        if(scalar keys %{$refs} || scalar keys %{$other_refs}) {
            return $c->redirect_to('conf.cgi?sub=objects&action=listref&data.id='.$obj->get_id().'&show_force=1');
        }
    }

    if($c->req->parameters->{'ref'}) {
        my $name        = $obj->get_name();
        my $refs_delete = Thruk::Utils::list($c->req->parameters->{'ref'});
        for my $id (@{$refs_delete}) {
            for my $type (keys %{$refs}) {
                if($refs->{$type}->{$id}) {
                    my $ref_obj = $c->{'obj_db'}->get_object_by_id($id);
                    for my $attr (keys %{$refs->{$type}->{$id}}) {
                        if(ref $ref_obj->{'conf'}->{$attr} eq 'ARRAY') {
                            $ref_obj->{'conf'}->{$attr} = [grep(!/^\Q$name\E$/mx, @{$ref_obj->{'conf'}->{$attr}})];
                        } elsif(ref $ref_obj->{'conf'}->{$attr} eq '') {
                            delete $ref_obj->{'conf'}->{$attr};
                        }
                        $c->{'obj_db'}->update_object($ref_obj, $ref_obj->{'conf'});
                        $ref_obj->{'file'}->{'changed'}  = 1;
                        $c->{'obj_db'}->{'needs_commit'} = 1;
                        # remove if its unused now
                        $c->{'obj_db'}->delete_object($ref_obj) if($ref_obj->can('is_unused') && $ref_obj->is_unused($c->{'obj_db'}));
                    }
                }
            }
        }
    }

    $c->{'obj_db'}->delete_object($obj);
    $c->stash->{'obj_model_changed'} = 1;

    # create log message
    $c->{'obj_db'}->{'logs'} = [] unless $c->{'obj_db'}->{'logs'};
    push @{$c->{'obj_db'}->{'logs'}},
        sprintf("[config][%s][%s] removed %s '%s'",
                                $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'name'},
                                $c->stash->{'remote_user'},
                                $obj->get_type(),
                                $obj->get_name(),
    );

    Thruk::Utils::set_message( $c, 'success_message', ucfirst($obj->get_type()).' removed successfully' );
    return $c->redirect_to('conf.cgi?sub=objects&type='.$obj->get_type());
}

##########################################################
sub _object_save {
    my($c, $obj) = @_;

    my $data        = $obj->get_data_from_param($c->req->parameters);
    my $old_comment = join("\n", @{$obj->{'comments'}});
    my $new_comment = $c->req->parameters->{'conf_comment'} || '';
    $new_comment    =~ s/\r//gmx;
    my $new         = $c->req->parameters->{'data.id'} eq 'new' ? 1 : 0;

    # create copy of object to get references later if renamed
    my $old_obj = Monitoring::Config::Object->new(
        id       => $obj->get_id(),
        type     => $obj->get_type(),
        conf     => $obj->{'conf'},
        coretype => $c->{'obj_db'}->{'coretype'},
    );

    # save object
    $obj->{'file'}->{'errors'} = [];
    $c->{'obj_db'}->update_object($obj, $data, $new_comment);
    $c->stash->{'data_name'} = $obj->get_name();

    # just display the normal edit page if save failed
    if($obj->get_id() eq 'new') {
        $c->stash->{action} = '';
        return;
    }

    $c->{'obj_db'}->{'logs'} = [] unless $c->{'obj_db'}->{'logs'};
    push @{$c->{'obj_db'}->{'logs'}},
        sprintf("[config][%s][%s] %s %s '%s'",
                                $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'name'},
                                $c->stash->{'remote_user'},
                                $new ? 'created' : 'changed',
                                $obj->get_type(),
                                ($c->stash->{'data_name'} || 'undefined'),
    );
    $c->stash->{'obj_model_changed'} = 1;

    # only save or continue to raw edit?
    if(defined $c->req->parameters->{'send'} and $c->req->parameters->{'send'} eq 'raw edit') {
        return $c->redirect_to('conf.cgi?sub=objects&action=editor&file='.encode_utf8($obj->{'file'}->{'display'}).'&line='.$obj->{'line'}.'&data.id='.$obj->get_id().'&back=edit');
    }

    if(scalar @{$obj->{'file'}->{'errors'}} > 0) {
        Thruk::Utils::set_message( $c, 'fail_message', ucfirst($c->stash->{'type'}).' changed with errors', $obj->{'file'}->{'errors'} );
        return; # return, otherwise details would not be displayed
    }

    # does the object have a name?
    if(!defined $c->stash->{'data_name'} || $c->stash->{'data_name'} eq '') {
        $obj->set_name('undefined');
        $c->{'obj_db'}->_rebuild_index();
        Thruk::Utils::set_message( $c, 'fail_message', sprintf('%s %s without a name', ucfirst($c->stash->{'type'}), $new ? 'created' : 'changed'));
    } else {
        Thruk::Utils::set_message( $c, 'success_message', sprintf('%s %s successfully', ucfirst($c->stash->{'type'}), $new ? 'created' : 'changed'));
    }

    if($c->req->parameters->{'referer'}) {
        return $c->redirect_to($c->req->parameters->{'referer'});
    }

    # list outside dependencies after renaming object
    if(!$new && $c->stash->{'data_name'} ne $old_obj->get_name()) {
        my $other_refs = _get_non_config_tool_references($c, $old_obj);
        if(scalar keys %{$other_refs} > 0) {
            Thruk::Utils::set_message( $c, 'success_message', ucfirst($c->stash->{'type'}).' saved successfully. Please check external references.' );
            $c->stash->{object} = $old_obj;
            _list_references($c, $old_obj);
            $c->stash->{'show_incoming'} = 0;
            $c->stash->{'show_outgoing'} = 0;
            $c->stash->{'show_renamed'}  = 1;
            return;
        }
    }

    return $c->redirect_to('conf.cgi?sub=objects&data.id='.$obj->get_id());
}

##########################################################
sub _object_move {
    my($c, $obj) = @_;

    my $files_root = _set_files_stash($c, 1);
    if($c->stash->{action} eq 'movefile') {
        return unless Thruk::Utils::check_csrf($c);
        my $new_file = $c->req->parameters->{'newfile'};
        my $file     = get_context_file($c, $obj, $new_file);
        if(defined $file and $c->{'obj_db'}->move_object($obj, $file)) {
            Thruk::Utils::set_message( $c, 'success_message', ucfirst($c->stash->{'type'}).' \''.$obj->get_name().'\' moved successfully' );
        }

        # create log message
        $c->{'obj_db'}->{'logs'} = [] unless $c->{'obj_db'}->{'logs'};
        push @{$c->{'obj_db'}->{'logs'}},
            sprintf("[config][%s][%s] moved %s '%s' to '%s'",
                                    $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'name'},
                                    $c->stash->{'remote_user'},
                                    $obj->get_type(),
                                    $obj->get_name(),
                                    $file->{'path'},
        );
        $c->stash->{'obj_model_changed'} = 1;

        return $c->redirect_to('conf.cgi?sub=objects&data.id='.$obj->get_id());
    }
    elsif($c->stash->{action} eq 'move') {
        $c->stash->{'template'} = 'conf_objects_move.tt';
    }
    return;
}

##########################################################
sub _object_clone {
    my($c, $obj) = @_;

    my $files_root          = _set_files_stash($c, 1);
    $c->stash->{'new_file'} = $obj->{'file'}->{'display'};
    $c->stash->{'new_file'} =~ s/^$files_root/\//gmx;
    # if cloned from a readonly file, keep new_file empty
    if($obj->{'file'}->{'readonly'}) { $c->stash->{'new_file'} = ''; }
    my $newobj = Monitoring::Config::Object->new(
        type     => $obj->get_type(),
        conf     => $obj->{'conf'},
        coretype => $c->{'obj_db'}->{'coretype'},
    );
    return $newobj;
}


##########################################################
sub _clone_refs {
    my($c, $obj, $cloned_id, $clone_refs) = @_;
    return unless $cloned_id;
    my $new_name = $obj->get_name();
    my $orig     = $c->{'obj_db'}->get_object_by_id($cloned_id);
    if(!$orig) {
        Thruk::Utils::set_message( $c, 'fail_message', 'Could not find object to clone from.' );
        return;
    }

    my $cloned_name = $orig->get_name();
    if($new_name eq $cloned_name) {
        Thruk::Utils::set_message( $c, 'fail_message', 'New name must be different' );
        return;
    }

    $c->{'obj_db'}->clone_refs($orig, $obj, $cloned_name, $new_name, $clone_refs);

    return;
}


##########################################################
sub _object_new {
    my($c) = @_;

    _set_files_stash($c, 1);
    $c->stash->{'new_file'} = '';
    my $standard_keys;
    my $default_values = {};
    if($c->config->{'Thruk::Plugin::ConfigTool'}->{'default_keys_'.$c->stash->{'type'}}) {
        $standard_keys = [split(/\s+/mx, $c->config->{'Thruk::Plugin::ConfigTool'}->{'default_keys_'.$c->stash->{'type'}})];
        for my $k (@{$standard_keys}) {
            my $v;
            ($k,$v) = split(/:/mx, $k, 2);
            $default_values->{$k} = $v if defined $v;
        }
    }
    my $obj = Monitoring::Config::Object->new(type     => $c->stash->{'type'},
                                              name     => $c->stash->{'data_name'},
                                              coretype => $c->{'obj_db'}->{'coretype'},
                                              standard => $standard_keys,
                                            );

    if(!defined $obj) {
        Thruk::Utils::set_message( $c, 'fail_message', 'Failed to create object' );
        return;
    }

    $obj->{'conf'} = { %{$obj->{'conf'}}, %{$obj->sanitize_values($default_values)} };

    if($c->req->parameters->{'template'}) {
        $obj->{'conf'}->{'name'}     = '';
        $obj->{'conf'}->{'register'} = 0;
        delete $obj->{'conf'}->{'host_name'};
        delete $obj->{'conf'}->{'service_description'};
        delete $obj->{'conf'}->{'contact_name'};
        delete $obj->{'conf'}->{'alias'};
    }

    # set initial config from cgi parameters
    my $initial_conf = $obj->get_data_from_param($c->req->parameters, $obj->{'conf'});
    if(scalar keys %{$initial_conf} > 0 && $obj->has_object_changed($initial_conf)) {
        $c->{'obj_db'}->update_object($obj, $initial_conf );
    }

    return $obj;
}


##########################################################
sub _file_delete {
    my($c) = @_;

    my $path = $c->req->parameters->{'path'} || '';
    $path    =~ s/^\#//gmx;

    my $files = $c->req->parameters->{'files'};
    for my $filename (ref $files eq 'ARRAY' ? @{$files} : ($files) ) {
        my $file = $c->{'obj_db'}->get_file_by_path($filename);
        if(defined $file) {
            $c->{'obj_db'}->file_delete($file);
        }
    }

    Thruk::Utils::set_message( $c, 'success_message', 'File(s) deleted successfully' );
    return $c->redirect_to('conf.cgi?sub=objects&action=browser#'.$path);
}


##########################################################
sub _file_undelete {
    my($c) = @_;

    my $path = $c->req->parameters->{'path'} || '';
    $path    =~ s/^\#//gmx;

    my $files = $c->req->parameters->{'files'};
    for my $filename (ref $files eq 'ARRAY' ? @{$files} : ($files) ) {
        my $file = $c->{'obj_db'}->get_file_by_path($filename);
        if(defined $file) {
            $c->{'obj_db'}->file_undelete($file);
        }
    }

    Thruk::Utils::set_message( $c, 'success_message', 'File(s) recoverd successfully' );
    return $c->redirect_to('conf.cgi?sub=objects&action=browser#'.$path);
}


##########################################################
sub _file_save {
    my($c) = @_;

    my $filename = $c->req->parameters->{'file'}    || '';
    my $content  = $c->req->parameters->{'content'} || '';
    my $lastline = $c->req->parameters->{'line'};
    my $file     = $c->{'obj_db'}->get_file_by_path($filename);
    my $lastobj;
    if(defined $file) {
        $lastobj = $file->update_objects_from_text($content, $lastline);
        $c->{'obj_db'}->_rebuild_index();
        my $files_root                   = _set_files_stash($c, 1);
        $c->{'obj_db'}->{'needs_commit'} = 1;
        $c->stash->{'obj_model_changed'} = 1;
        $c->stash->{'file_name'}         = $file->{'display'};
        $c->stash->{'file_name'}         =~ s/^$files_root//gmx;
        if(scalar @{$file->{'errors'}} > 0) {
            Thruk::Utils::set_message( $c,
                                      'fail_message',
                                      'File '.$c->stash->{'file_name'}.' changed with errors',
                                      $file->{'errors'},
                                    );
        } else {
            Thruk::Utils::set_message( $c, 'success_message', 'File '.$c->stash->{'file_name'}.' changed successfully' );
        }
    }
    elsif(_is_extra_file($filename, $c->config->{'Thruk::Plugin::ConfigTool'}->{'edit_files'})) {
        Thruk::Utils::set_message( $c, 'success_message', 'File '.$filename.' changed successfully' );
        Thruk::Utils::IO::write($filename, $content);
        if(defined $c->req->parameters->{'backlink'}) {
            return $c->redirect_to($c->req->parameters->{'backlink'});
        }
    } else {
        Thruk::Utils::set_message( $c, 'fail_message', 'File does not exist' );
    }

    if(defined $lastobj) {
        return $c->redirect_to('conf.cgi?sub=objects&data.id='.$lastobj->get_id());
    }
    return $c->redirect_to('conf.cgi?sub=objects&action=browser#'.$file->{'display'});
}

##########################################################
sub _file_editor {
    my($c) = @_;

    my $files_root  = _set_files_stash($c);
    my $filename    = $c->req->parameters->{'file'} || '';
    my $file        = $c->{'obj_db'}->get_file_by_path($filename);
    if(defined $file) {
        $c->stash->{'file'}          = $file;
        $c->stash->{'line'}          = $c->req->parameters->{'line'} || 1;
        $c->stash->{'back'}          = $c->req->parameters->{'back'} || '';
        $c->stash->{'file_link'}     = $file->{'display'};
        $c->stash->{'file_name'}     = $file->{'display'};
        $c->stash->{'file_name'}     =~ s/^$files_root//gmx;
        $c->stash->{'file_content'}  = decode_utf8($file->get_new_file_content());
        $c->stash->{'template'}      = $c->config->{'use_feature_editor'} ? 'conf_objects_fancyeditor.tt' : 'conf_objects_fileeditor.tt';
    }
    elsif(_is_extra_file($filename, $c->config->{'Thruk::Plugin::ConfigTool'}->{'edit_files'})) {
        $file = Monitoring::Config::File->new($filename, [], $c->{'obj_db'}->{'coretype'}, 1);
        $c->stash->{'file'}          = $file;
        $c->stash->{'file_link'}     = $filename;
        $c->stash->{'file_name'}     = $filename;
        $c->stash->{'line'}          = $c->req->parameters->{'line'} || 1;
        $c->stash->{'file_content'}  = '';
        if(-f $filename) {
            my $content                  = read_file($filename);
            $c->stash->{'file_content'}  = decode_utf8($content);
        }
        $c->stash->{'template'}      = $c->config->{'use_feature_editor'} ? 'conf_objects_fancyeditor.tt' : 'conf_objects_fileeditor.tt';
        $c->stash->{'subtitle'}      = "";
    } else {
        Thruk::Utils::set_message( $c, 'fail_message', 'File does not exist' );
    }
    return;
}

##########################################################
sub _file_browser {
    my($c) = @_;

    _set_files_stash($c);
    $c->stash->{'template'} = 'conf_objects_filebrowser.tt';
    return;
}

##########################################################
sub _file_history {
    my($c) = @_;

    return 1 unless $c->stash->{'has_history'};

    my $commit     = $c->req->parameters->{'id'};
    my $obj_id     = $c->req->parameters->{'data.id'};
    my $files_root = $c->{'obj_db'}->get_files_root();
    my $dir        = $c->{'obj_db'}->{'config'}->{'git_base_dir'} || $c->config->{'Thruk::Plugin::ConfigTool'}->{'git_base_dir'} || $files_root;

    $c->stash->{'template'} = 'conf_objects_filehistory.tt';

    if($obj_id) {
        return if _file_history_blame_obj($c, $obj_id);
    }
    if($commit) {
        return if _file_history_commit($c, $commit, $dir);
    }

    my $logs = _get_git_logs($c, $dir);

    Thruk::Backend::Manager::page_data($c, $logs);
    $c->stash->{'logs'} = $logs;
    $c->stash->{'dir'}  = $dir;
    return;
}

##########################################################
sub _file_history_commit {
    my($c, $commit, $dir) = @_;

    # verify our commit id
    if($commit !~ m/^[a-zA-Z0-9]+$/mx) {
        Thruk::Utils::set_message( $c, 'fail_message', 'Not a valid commit id!' );
        return;
    }

    my $data = _get_git_commit($c, $dir, $commit);
    if(!$data) {
        Thruk::Utils::set_message( $c, 'fail_message', 'Not a valid commit!' );
        return;
    }

    $c->stash->{'previous'} = '';
    $c->stash->{'next'}     = '';
    my $logs = _get_git_logs($c, $dir);
    for my $l (@{$logs}) {
        if($l->{'id'} eq $data->{'id'}) {
            $c->stash->{'previous'} = _get_git_commit($c, $dir, $l->{'previous'}) if $l->{'previous'};
            $c->stash->{'next'}     = _get_git_commit($c, $dir, $l->{'next'})     if $l->{'next'};
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

    $c->stash->{'dir'}      = $dir;
    $c->stash->{'data'}     = $data;
    $c->stash->{'links'}    = $diff_link_files;
    $c->stash->{'template'} = 'conf_objects_filehistory_commit.tt';

    return 1;
}

##########################################################
sub _file_history_blame_obj {
    my($c, $obj_id) = @_;

    my $obj = $c->{'obj_db'}->get_object_by_id($c->stash->{'data_id'});
    if(!$obj) {
        Thruk::Utils::set_message($c, 'fail_message', 'no such object');
        return;
    }
    if(!$obj->{'file'} || $obj->{'line'} <= 0) {
        Thruk::Utils::set_message($c, 'fail_message', 'object has not yet been saved');
        return;
    }

    my $blame = _get_git_blame($c, $obj->{'file'}->{'path'}, $obj->{'line'}, $obj->{'line2'});

    $c->stash->{'object'}   = $obj;
    $c->stash->{'blame'}    = $blame;
    $c->stash->{'template'} = 'conf_objects_filehistory_blame.tt';

    return 1;
}

##########################################################
sub _get_git_logs {
    my($c, $dir) = @_;
    my $cmd = "cd '".$dir."' && git log --pretty='format:".join("\x1f", '%h', '%an', '%ae', '%at', '%s')."\x1e'";
    my($rc, $out) = Thruk::Utils::IO::cmd($cmd);
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
    my($c, $dir, $commit) = @_;
    my $cmd = "cd '".$dir."' && git show --pretty='format:".join("\x1f", '%h', '%an', '%ae', '%at', '%p', '%t', '%s', '%b')."\x1f' ".$commit;
    my $output = Thruk::Utils::IO::cmd($cmd);
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
sub _get_git_blame {
    my($c, $path, $line_start, $line_end) = @_;
    my $dir = Thruk::Utils::dirname($path);
    my $cmd = "cd '".$dir."' && git blame -swp -L $line_start,$line_end '".$path."'";
    my $output = Thruk::Utils::IO::cmd($cmd);
    my $blame = {lines => [], commits => {}};
    my($state, $block, $commit) = (0, {}, {});
    for my $line (split/\n/mx, $output) {
        # new commit header starts
        if($state == 0) {
            my($hash, $sourceline, $resultline, $num_lines) = split(/\s+/mx, $line);
            $commit = {
                hash       => $hash,
                sourceline => $sourceline,
                resultline => $resultline,
                num_lines  => $num_lines,
            };
            $state = 3;
            # new commit hash, parse commit details
            if(!$blame->{'commits'}->{$hash}) {
                $state = 2;
                $blame->{'commits'}->{$hash} = $commit;
            }
            next;
        }

        # commit details parser
        if($state == 2) {
            my($key, $value) = split(/\s+/mx, $line, 2);
            $commit->{$key} = $value;
            if($key eq 'filename') {
                # commit header parsing done
                $state = 3;
            }
            next;
        }

        # line parser
        if($state == 3) {
            chomp($line);
            $block = {
                line       => $line,
                hash       => $commit->{'hash'},
                sourceline => $commit->{'sourceline'},
                resultline => $commit->{'resultline'},
            };
            push @{$blame->{'lines'}}, $block;
            $state = 0;
            next;
        }
    }
    return $blame;
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
    my($c) = @_;

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
    my($c) = @_;

    my $type     = $c->req->parameters->{'type'}     || '';
    my $template = $c->req->parameters->{'template'};
    my $origin   = $c->req->parameters->{'origin'};
    my $dir      = $c->req->parameters->{'dir'};
    my $objs = [];
    if($dir) {
        $objs = $c->{'obj_db'}->get_objects_by_path($dir);
        $c->stash->{'objects_type'} = 'all';
    }
    elsif($type) {
        my $filter;
        if(defined $template) {
            $filter = {};
            $filter->{'use'} = $template;
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
    if(defined $c->cookie('thruk_obj_layout')) {
        $c->stash->{'tree_objects_layout'} = $c->cookie('thruk_obj_layout')->value();
    }

    my $all_files  = $c->{'obj_db'}->get_files();
    my $files_tree = _files_to_path($c, $all_files);
    my $files_root = $files_tree->{'path'};
    $c->stash->{'files_tree'} = $files_tree;
    $c->stash->{'files_root'} = $files_root;

    $c->stash->{'objects'}  = $objs;
    $c->stash->{'template'} = 'conf_objects_tree_objects.tt';
    return;
}

##########################################################
sub _host_list_services {
    my($c, $obj) = @_;

    my $services = $c->{'obj_db'}->get_services_for_host($obj);
    $c->stash->{'services'} = $services ;
    $c->stash->{'template'} = 'conf_objects_host_list_services.tt';
    return;
}

##########################################################
sub _list_references {
    my($c, $obj) = @_;
    _gather_references($c, $obj, 1);
    $c->stash->{'show_incoming'} = 1;
    $c->stash->{'show_outgoing'} = 1;
    $c->stash->{'show_renamed'}  = 0;
    $c->stash->{'template'}      = 'conf_objects_listref.tt';
    return;
}

##########################################################
sub _config_check {
    my($c) = @_;
    my $obj_check_cmd = $c->stash->{'peer_conftool'}->{'obj_check_cmd'};
    $obj_check_cmd = $obj_check_cmd.' 2>&1' if($obj_check_cmd && $obj_check_cmd !~ m|>|mx);
    my $rc = 0;
    if($c->{'obj_db'}->is_remote() && $c->{'obj_db'}->remote_config_check($c)) {
        Thruk::Utils::set_message( $c, 'success_message', 'config check successfull' );
        $rc = 1;
    }
    elsif(!$c->{'obj_db'}->is_remote() && _cmd($c, $obj_check_cmd)) {
        Thruk::Utils::set_message( $c, 'success_message', 'config check successfull' );
        $rc = 1;
    } else {
        Thruk::Utils::set_message( $c, 'fail_message', 'config check failed!' );
    }
    _nice_check_output($c);

    $c->stash->{'needs_commit'}      = $c->{'obj_db'}->{'needs_commit'};
    $c->stash->{'last_changed'}      = $c->{'obj_db'}->{'last_changed'};
    return $rc;
}

##########################################################
sub _config_reload {
    my($c) = @_;
    $c->stats->profile(begin => "conf::_config_reload");

    $c->stash->{'original_output'} = "";
    my $time = time();
    my $name = $c->stash->{'param_backend'};
    my $peer = $c->{'db'}->get_peer_by_key($name);
    my $pkey = $peer->peer_key();
    my $wait = 1;

    my $last_reload = $c->stash->{'pi_detail'}->{$pkey}->{'program_start'};
    if(!$last_reload) {
        my $processinfo = $c->{'db'}->get_processinfo(backends => $pkey);
        $last_reload = ($processinfo->{$pkey} && $processinfo->{$pkey}->{'program_start'}) || (time() - 1);
    }

    $c->stats->profile(comment => "program_start before reload: ".$last_reload);
    if($c->stash->{'peer_conftool'}->{'obj_reload_cmd'}) {
        if($c->{'obj_db'}->is_remote() && $c->{'obj_db'}->remote_config_reload($c)) {
            Thruk::Utils::set_message( $c, 'success_message', 'config reloaded successfully' );
            $c->{'obj_db'}->{'last_changed'} = 0;
            $c->{'obj_db'}->{'needs_commit'} = 0;
            Thruk::Utils::Conf::store_model_retention($c, $pkey);
        }
        elsif(!$c->{'obj_db'}->is_remote() && _cmd($c, $c->stash->{'peer_conftool'}->{'obj_reload_cmd'})) {
            Thruk::Utils::set_message( $c, 'success_message', 'config reloaded successfully' );
            $c->{'obj_db'}->{'last_changed'} = 0;
            $c->{'obj_db'}->{'needs_commit'} = 0;
            Thruk::Utils::Conf::store_model_retention($c, $pkey);
        } else {
            Thruk::Utils::set_message( $c, 'fail_message', 'config reload failed!' );
            $wait = 0;
        }

        _nice_check_output($c);
    } else {
        # restart by livestatus
        die("no backend found by name ".$name) unless $peer;
        my $options = {
            'command' => sprintf("COMMAND [%d] RESTART_PROCESS", $time),
            'backend' => [ $pkey ],
        };
        $c->{'db'}->send_command( %{$options} );
        $c->stash->{'output'} = 'config reloaded by external command.';
    }
    $c->stats->profile(comment => "reload command issued: ".time());

    # wait until core responds again
    if($wait) {
        if(!Thruk::Utils::wait_after_reload($c, $pkey, $last_reload)) {
            $c->stash->{'original_output'} .= 'Warning: waiting for core reload failed.';
            $c->stash->{'output'}          .= "\n<font color='red'>".$c->stash->{'original_output'}."</font>";
        }
    }

    # reload navigation, probably some names have changed
    $c->stash->{'reload_nav'} = 1;

    $c->stats->profile(end => "conf::_config_reload");
    return 1;
}

##########################################################
sub _nice_check_output {
    my($c) = @_;
    $c->stash->{'original_output'} = $c->stash->{'output'};
    $c->stash->{'output'} =~ s/(Error\s*:.*)$/<b><font color="red">$1<\/font><\/b>/gmx;
    $c->stash->{'output'} =~ s/(Warning\s*:.*)$/<b><font color="#FFA500">$1<\/font><\/b>/gmx;
    $c->stash->{'output'} =~ s/(CONFIG\s+ERROR.*)$/<b><font color="red">$1<\/font><\/b>/gmx;
    $c->stash->{'output'} =~ s/(\(config\s+file\s+'(.*?)',\s+starting\s+on\s+line\s+(\d+)\))/<a href="conf.cgi?sub=objects&amp;file=$2&amp;line=$3">$1<\/a>/gmx;
    $c->stash->{'output'} =~ s/\s+in\s+file\s+'(.*?)'\s+on\s+line\s+(\d+)/ in file <a href="conf.cgi?sub=objects&amp;type=file&amp;file=$1&amp;line=$2">'$1' on line $2<\/a>/gmx;
    $c->stash->{'output'} =~ s/\s+in\s+(\w+)\s+'(.*?)'/ in $1 '<a href="conf.cgi?sub=objects&amp;type=$1&amp;data.name=$2">$2<\/a>'/gmx;
    $c->stash->{'output'} =~ s/Warning:\s+(\w+)\s+'(.*?)'\s+/Warning: $1 '<a href="conf.cgi?sub=objects&amp;type=$1&amp;data.name=$2">$2<\/a>' /gmx;
    $c->stash->{'output'} =~ s/Error:\s+(\w+)\s+'(.*?)'\s+/Error: $1 '<a href="conf.cgi?sub=objects&amp;type=$1&amp;data.name=$2">$2<\/a>' /gmx;
    $c->stash->{'output'} =~ s/Error\s*:\s*the\s+service\s+([^\s]+)\s+on\s+host\s+'([^']+)'/Error: the service <a href="conf.cgi?sub=objects&amp;type=service&amp;data.name=$1&amp;data.name2=$2">$1<\/a> on host '$2'/gmx;
    $c->stash->{'output'} = "<pre>".$c->stash->{'output'}."</pre>";
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
            $c->stash->{'obj_model_changed'} = 1;
        }
    }
    return;
}

##########################################################
sub _gather_references {
    my($c, $obj, $include_outside) = @_;

    #&timing_breakpoint('_gather_references');

    my($incoming, $outgoing) = $c->{'obj_db'}->gather_references($obj);

    $c->stash->{'other_refs'} = {} unless $c->stash->{'other_refs'};
    $c->stash->{'other_refs'} = _get_non_config_tool_references($c, $obj) if $include_outside;

    # linked from delete object page?
    $c->stash->{'force_delete'} = $c->req->parameters->{'show_force'} ? 1 : 0;

    $c->stash->{'incoming'} = $incoming;
    $c->stash->{'outgoing'} = $outgoing;
    $c->stash->{'has_refs'} = 1 if(scalar keys %{$incoming} || scalar keys %{$outgoing} || scalar keys %{$c->stash->{'other_refs'}});

    #&timing_breakpoint('_gather_references done');

    return({incoming => $incoming, outgoing => $outgoing});
}

##########################################################
sub _is_extra_file {
    my($filename, $edit_files) = @_;
    $edit_files = Thruk::Utils::list($edit_files);
    for my $file (@{$edit_files}) {
        # direct match
        if($file eq $filename) {
            return 1;
        }
        # pattern is a directory and the file is below that folder
        elsif($filename =~ m|^\Q$file\E/|mx && -d $file) {
            return 1;
        }
    }
    return 0;
}

##########################################################
sub _get_non_config_tool_references {
    my($c, $obj) = @_;
    my $other_refs = {};
    if($obj->get_type() eq 'host') {
        Thruk::Utils::References::get_host_matches($c, $c->stash->{'param_backend'}, { $c->stash->{'param_backend'} => 1 }, $other_refs, $obj->get_primary_name() || $obj->get_name());
    }
    elsif($obj->get_type() eq 'hostgroup') {
        Thruk::Utils::References::get_hostgroup_matches($c, $c->stash->{'param_backend'}, { $c->stash->{'param_backend'} => 1 }, $other_refs, $obj->get_primary_name() || $obj->get_name());
    }
    elsif($obj->get_type() eq 'service') {
        # expand hosts and hostgroups and iterate over all of them
        my $all_hosts = {};
        for my $host_name (@{$obj->{'conf'}->{'host_name'}}) {
            $all_hosts->{$host_name} = 1;
        }
        for my $hostgroup_name (@{$obj->{'conf'}->{'hostgroup_name'}}) {
            my $groups = $c->{'db'}->get_hostgroups(filter => [{ name => $hostgroup_name }], backend => [$c->stash->{'param_backend'}], columns => [qw/name members/]);
            for my $group (@{$groups}) {
                for my $host_name (@{$group->{'members'}}) {
                    $all_hosts->{$host_name} = 1;
                }
            }
        }
        for my $host_name (sort keys %{$all_hosts}) {
            Thruk::Utils::References::get_service_matches($c, $c->stash->{'param_backend'}, { $c->stash->{'param_backend'} => 1 }, $other_refs, $host_name, $obj->get_primary_name() || $obj->get_name());
        }
    }
    elsif($obj->get_type() eq 'servicegroup') {
        Thruk::Utils::References::get_servicegroup_matches($c, $c->stash->{'param_backend'}, { $c->stash->{'param_backend'} => 1 }, $other_refs, $obj->get_primary_name() || $obj->get_name());
    }
    elsif($obj->get_type() eq 'contact') {
        Thruk::Utils::References::get_contact_matches($c, $c->stash->{'param_backend'}, { $c->stash->{'param_backend'} => 1 }, $other_refs, $obj->get_primary_name() || $obj->get_name());
    }
    $other_refs = $other_refs->{$c->stash->{'param_backend'}};
    delete $other_refs->{'Livestatus'};
    delete $other_refs->{'Configuration'};

    # remove duplicates
    for my $key (sort keys %{$other_refs}) {
        my $uniq = {};
        my @new = ();
        for my $entry (@{$other_refs->{$key}}) {
            my $first = 0;
            if(!$uniq->{$entry->{'name'}}->{$entry->{'details'}}) {
                $uniq->{$entry->{'name'}}->{$entry->{'details'}} = 0;
                $first = 1;
            }
            $uniq->{$entry->{'name'}}->{$entry->{'details'}}++;
            push @new, $entry if $first;
        }
        for my $n (@new) {
            if($uniq->{$n->{'name'}}->{$n->{'details'}} > 1) {
                $n->{'details'} = $n->{'details'}.' ('.$uniq->{$n->{'name'}}->{$n->{'details'}}.' times)';
            }
        }
        $other_refs->{$key} = \@new;
    }

    return($other_refs);
}

##########################################################

1;
