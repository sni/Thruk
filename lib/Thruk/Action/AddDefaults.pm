package Thruk::Action::AddDefaults;

=head1 NAME

Thruk::Action::AddDefaults - Add Defaults to the context

=head1 DESCRIPTION

loads cgi.cfg

creates backend manager

=head1 METHODS

=cut


use warnings;
use strict;
use Carp qw/confess/;
use Cpanel::JSON::XS qw/decode_json/;
use Data::Dumper qw/Dumper/;
use POSIX ();
use Scalar::Util qw/weaken/;

use Thruk::Base ();
use Thruk::Config 'noautoload';
use Thruk::Constants qw/:add_defaults :peer_states/;
use Thruk::Utils ();
use Thruk::Utils::Filter ();
use Thruk::Utils::IO ();
use Thruk::Utils::Log qw/:all/;
use Thruk::Utils::Menu ();
use Thruk::Utils::Timezone ();

my @stash_config_keys = qw/
    url_prefix product_prefix title_prefix use_feature_configtool
    datetime_format datetime_format_today datetime_format_long datetime_format_log
    show_notification_number strict_passive_mode hide_passive_icon
    show_full_commandline all_problems_link show_long_plugin_output
    priorities show_modified_attributes downtime_duration expire_ack_duration show_contacts
    show_backends_in_table cookie_path
    use_feature_trends show_error_reports skip_js_errors perf_bar_mode
    bug_email_rcpt first_day_of_week sitepanel perf_bar_pnp_popup
    status_color_background show_logout_button use_feature_recurring_downtime
    force_sticky_ack force_send_notification force_persistent_ack
    force_persistent_comments use_bookmark_titles use_dynamic_titles use_feature_bp
    thruk_author
/;

######################################

=head2 begin

    begin, running at the begin of every req (except static ones)

    runs before add_defaults().

=cut

sub begin {
    my($c) = @_;
    $c->stats->profile(begin => "Root begin");

    # collect statistics when running external command or if enabled by env variable
    if($ENV{'THRUK_JOB_DIR'} || ($ENV{'THRUK_PERFORMANCE_DEBUG'} && $ENV{'THRUK_PERFORMANCE_DEBUG'} >= 2)) {
        $c->stats->enable(1);
    }

    set_configs_stash($c);
    $c->stash->{'root_begin'} = 1;

    $c->stash->{'c'} = $c;
    weaken($c->stash->{'c'});

    $c->stash->{'show_sounds'}        = 0;
    $c->stash->{'has_debug_options'}  = $c->req->parameters->{'debug'} || 0;

    # use pager?
    Thruk::Utils::set_paging_steps($c, $c->config->{'paging_steps'});

    # which theme?
    my $available_themes = Thruk::Base::array2hash($c->config->{'themes'});
    my($param_theme, $cookie_theme);
    if( $c->req->parameters->{'theme'} ) {
        $param_theme = $c->req->parameters->{'theme'};
    }
    elsif($c->cookies('thruk_theme') ) {
        my $theme_cookie = $c->cookies('thruk_theme');
        $cookie_theme = $theme_cookie if(defined $theme_cookie && defined $available_themes->{$theme_cookie});
    }
    my $theme = $param_theme || $cookie_theme || $c->config->{'default_theme'};
    $theme = $c->config->{'default_theme'} unless defined $available_themes->{$theme};
    $theme = 'Light'                       unless defined $available_themes->{$theme};
    $theme = $c->config->{'themes'}->[0]   unless defined $available_themes->{$theme};
    $c->stash->{'theme'} = $theme || 'None';

    if(exists $c->req->parameters->{'noheader'}) {
        $c->req->parameters->{'hidetop'}  = 1;
    }

    # hide navigation
    $c->stash->{show_nav} = (defined $c->req->parameters->{'nav'} && $c->req->parameters->{'nav'} eq '0') ? 0 : 1;

    # minmal custom monitor screen
    $c->stash->{minimal} = $c->req->parameters->{'minimal'} || '';

    # menu cookie set?
    my $menu_states = {};
    for my $key (keys %{$c->config->{'initial_menu_state'}}) {
        my $val = $c->config->{'initial_menu_state'}->{$key};
        $key = lc $key;
        $key =~ s/\ /_/gmx;
        $menu_states->{$key} = $val;
    }
    if($c->cookies('thruk_side') ) {
        my @states = $c->cookies('thruk_side');
        for my $state (@states) {
            my($k,$v) = split(/=/mx,$state,2);
            $k = lc($k // '');
            $k =~ s/\ /_/gmx;
            $menu_states->{$k} = $v;
        }
    }
    $c->stash->{'menu_states'} = $menu_states;

    my $target = $c->req->parameters->{'target'};
    if(defined $target && $target eq '_parent' ) {
        $c->stash->{'target'} = '_parent';
    }

    $c->stash->{'iframed'} = $c->req->parameters->{'iframed'} || 0;

    # additional views on status pages
    $c->stash->{'additional_views'} = $Thruk::Globals::additional_views || {};

    # icon image path
    $c->stash->{'logo_path_prefix'}  = exists $c->config->{'logo_path_prefix'} ? $c->config->{'logo_path_prefix'} : $c->stash->{'url_prefix'}.'themes/'.$c->stash->{'theme'}.'/images/logos/';

    # view mode must be a scalar
    for my $key (qw/view_mode hidetop style/) {
        if($c->req->parameters->{$key}) {
            if(ref $c->req->parameters->{$key} eq 'ARRAY') {
                $c->req->parameters->{$key} = pop(@{$c->req->parameters->{$key}});
            }
        }
    }
    $c->stash->{hidetop} = $c->req->parameters->{hidetop} if defined $c->req->parameters->{hidetop};

    $c->stash->{'action_menus_inserted'} = {};

    ###############################
    # parse cgi.cfg
    Thruk::Config::merge_cgi_cfg($c);
    $c->stash->{'escape_html_tags'}  = $c->config->{'escape_html_tags'}  // 1;

    ###############################
    # Authentication
    if(!$c->user_exists) {
        my $product_prefix = $c->config->{'product_prefix'};
        # if changed, adjust thruk_auth as well
        if($c->req->path_info =~ m#/$product_prefix/(themes|javascript|cache|vendor|images|usercontent|cgi\-bin/(login|remote)\.cgi)#mx) {
            _debug($1.".cgi does not require authentication") if Thruk::Base->debug;
        } else {
            if(!$c->authenticate(skip_db_access => 1)) {
                _debug("user authentication failed") if Thruk::Base->verbose;
                return $c->detach('/error/index/10');
            }
        }
    }

    # sound cookie set?
    if(defined $c->cookies('thruk_sounds')) {
        my $sound_cookie = $c->cookies('thruk_sounds');
        if($sound_cookie && $sound_cookie eq 'off') {
            $c->stash->{'play_sounds'} = 0;
        }
        if($sound_cookie && $sound_cookie eq 'on') {
            $c->stash->{'play_sounds'} = 1;
        }
    }

    # favicon cookie set?
    $c->stash->{'fav_counter'} = 0;
    if(defined $c->cookies('thruk_favicon')) {
        my $favicon_cookie = $c->cookies('thruk_favicon');
        if($favicon_cookie && $favicon_cookie eq 'off') {
            $c->stash->{'fav_counter'} = 0;
        }
        if($favicon_cookie && $favicon_cookie eq 'on') {
            $c->stash->{'fav_counter'} = 1;
        }
    }

    # main table cookie set?
    $c->stash->{'main_table_full'} = $c->cookies('thruk_main_table_full') // $c->config->{'thruk_main_table_full'} // 0;

    $c->stash->{'usercontent_folder'} = $c->config->{'home'}.'/root/thruk/usercontent';
    # make usercontent folder based on env var if set. But only if it exists. Fallback to standard folder
    # otherwise except it doesn't exist either. Then better take the later if both do not exist.
    if($ENV{'THRUK_CONFIG'} && (-d $ENV{'THRUK_CONFIG'}.'/usercontent/.' || !-d $c->stash->{'usercontent_folder'}.'/.')) {
        $c->stash->{'usercontent_folder'} = $ENV{'THRUK_CONFIG'}.'/usercontent';
    }

    # ex.: global bookmarks from var/global_user_data
    $c->stash->{global_user_data} = Thruk::Utils::get_global_user_data($c);

    # do some sanity checks
    if($c->req->parameters->{'referer'}) {
        $c->req->parameters->{'referer'} =~ s%^http://$c->{'env'}->{'SERVER_NAME'}(:80|)/%/%gmx;
        $c->req->parameters->{'referer'} =~ s%^https://$c->{'env'}->{'SERVER_NAME'}(:443|)/%/%gmx;
        if($c->req->parameters->{'referer'} =~ m/^(\w+:\/\/|\/\/)/mx) {
            $c->error("unsupported referer");
            return $c->detach('/error/index/100');
        }
    }

    for my $key (qw/q dfl_q s0_value/) {
        my $q = $c->req->parameters->{$key};
        next unless $q;
        $q =~ s/\s*$//gmx;
        if($q =~ s/^\w+.*\s+as\s+(\w+)$//gmx) {
            $c->req->parameters->{'style'} = $1;
        }
    }

    $c->stats->profile(end => "Root begin");
    return 1;
}

######################################

=head2 end

check and display errors (if any)

=cut

sub end {
    my( $c ) = @_;

    $c->stats->profile(begin => "Root end");

    update_site_panel_hashes($c) unless $c->stash->{'hide_backends_chooser'};

    if(!defined $c->stash->{'navigation'} || $c->stash->{'navigation'} eq '') {
        if(!$c->stash->{'skip_navigation'}) {
            Thruk::Utils::Menu::read_navigation($c);
        }
    }

    $c->stash->{hidetop} = $c->stash->{hidetop} // $c->config->{hide_top} // 'auto';
    if($c->stash->{hidetop} eq 'auto' || $c->stash->{hidetop} eq '') {
        $c->stash->{hidetop} = 1;
        if($c->cookies('thruk_screen')) {
            my $screen;
            eval {
                $screen = decode_json($c->cookies('thruk_screen'));
            };
            if($screen->{'width'} && $screen->{'width'} =~ m/^\d+$/gmx && $screen->{'width'} > 1300) {
                $c->stash->{hidetop} = 0;
            }
        }
    }

    my @errors = @{ $c->error };
    if( scalar @errors > 0 ) {
        for my $error (@errors) {
            _error($error);
        }
        return $c->detach('/error/index/13');
    }

    if($c->stash->{'debug_info'}) {
        # save debug info into tmp file
        Thruk::Action::AddDefaults::save_debug_information_to_tmp_file($c);
    }

    if($ENV{THRUK_LEAK_CHECK}) {
        eval {
            require Devel::Gladiator;
            Devel::Gladiator->import(qw(arena_ref_counts));
            my $refs = arena_ref_counts();
            if($c->config->{'arena'}) {
                my $res = {};
                for my $key (keys %{$refs}) {
                    $c->config->{'arena'}->{$key} = 0 unless defined $c->config->{'arena'}->{$key};
                    if($c->config->{'arena'}->{$key} > 0 and $c->config->{'arena'}->{$key} < $refs->{$key}) {
                        $res->{$key} = $refs->{$key} - $c->config->{'arena'}->{$key};
                    }
                }
                # there will be new scalars from time to time
                delete $res->{'SCALAR'} if $res->{'SCALAR'} and $res->{'SCALAR'} < 10;
                if($Thruk::Globals::COUNT >= 2 && scalar keys %{$res} > 0) {
                    _info("request: ".$Thruk::Globals::COUNT." (".$c->req->path."):");
                    for my $key (sort { ($res->{$b} <=> $res->{$a}) } keys %{$res}) {
                        _info(sprintf("+%-10i %30s  -  total %10i\n", $res->{$key}, $key, $c->config->{'arena'}->{$key}));
                    }
                }
            }
            for my $key (keys %{$refs}) {
                if(!$c->config->{'arena'}->{$key} || $c->config->{'arena'}->{$key} < $refs->{$key}) {
                    $c->config->{'arena'}->{$key} = $refs->{$key};
                }
            }
        };
        print STDERR $@ if $@ && Thruk::Base->debug;
    }

    # figure out intelligent titles
    # only if use_dynamic_titles is true
    # we haven't found a bookmark title
    # and a custom title wasn't set
    if(!set_custom_title($c) && $c->stash->{'use_dynamic_titles'} && $c->stash->{page}) {
        # titles for status.cgi
        if($c->stash->{page} eq 'status' && $c->stash->{'real_page'} ne 'bp') {
            if($c->stash->{'hostgroup'}) {
                $c->stash->{'title'} = $c->stash->{'hostgroup'} eq 'all' ? 'All Hostgroups' : $c->stash->{'hostgroup'};
            }
            elsif($c->stash->{'servicegroup'}) {
                $c->stash->{'title'} = $c->stash->{'servicegroup'} eq 'all' ? 'All Servicegroups' : $c->stash->{'servicegroup'};
            }
            elsif($c->stash->{'host'}) {
                $c->stash->{'title'} = $c->stash->{'host'} eq 'all' ? 'All Hosts' : $c->stash->{'host'};
            }
        }
        # titles for extinfo
        elsif($c->stash->{page} eq 'extinfo') {
            my $type = $c->req->parameters->{'type'} || 0;

            $c->stash->{'title'} = $c->stash->{'infoBoxTitle'} if $c->stash->{'infoBoxTitle'};
            if($type !~ m/^\d+$/mx) {}
            # host details
            elsif($type == 1) {
                $c->stash->{'title'} = $c->req->parameters->{'host'};
            }
            # service details
            elsif($type == 2) {
                $c->stash->{'title'} = $c->req->parameters->{'service'} . " @ " . $c->req->parameters->{'host'};
            }
            # hostgroup information
            elsif($type == 5) {
                $c->stash->{'title'} = $c->req->parameters->{'hostgroup'} . " " . $c->stash->{'infoBoxTitle'};
            }
            # servicegroup information
            elsif($type == 8) {
               $c->stash->{'title'} = $c->req->parameters->{'servicegroup'} . " " . $c->stash->{'infoBoxTitle'};
            }
        }
    }

    if(defined $c->config->{'refresh_rate'} && (!defined $c->stash->{'no_auto_reload'} || $c->stash->{'no_auto_reload'} == 0)) {
        $c->stash->{'refresh_rate'} = $c->config->{'refresh_rate'};
    }
    $c->stash->{'refresh_rate'} = $c->req->parameters->{'refresh'} if(defined $c->req->parameters->{'refresh'} and $c->req->parameters->{'refresh'} =~ m/^\d+$/mx);
    if(defined $c->stash->{'refresh_rate'} and $c->stash->{'refresh_rate'} == 0) {
        $c->stash->{'no_auto_reload'} = 1;
    }

    if($c->req->parameters->{'bodyCls'}) {
        $c->stash->{'extrabodyclass'} .= " ".$c->req->parameters->{'bodyCls'};
    }
    if($c->req->parameters->{'htmlCls'}) {
        $c->stash->{'extrahtmlclass'} .= " ".$c->req->parameters->{'htmlCls'};
    }
    if($c->stash->{'minimal'}) {
        $c->stash->{'extrahtmlclass'} .= " minimal";
    }

    $c->stats->profile(end => "Root end");
    return 1;
}

########################################

=head2 add_defaults

    add default values and create backend connections

    runs after before()

=cut

sub add_defaults {
    my ($c, $flags, $no_config_adjustments) = @_;
    confess("no c?") unless defined $c;

    my($flags_hash, $flags_name) = _get_flags($flags);
    $c->stats->profile(begin => "AddDefaults::add_defaults(".$flags_name.")");

    ###############################
    # user / group specific config?
    if(!$no_config_adjustments && $c->user_exists) {
        $c->stash->{'usr_config_adjustments'} = [];
        for my $group (@{$c->user->{'groups'}}) {
            if($c->config->{'Group'}->{$group}) {
                push @{$c->stash->{'usr_config_adjustments'}}, $c->config->{'Group'}->{$group};
            }
        }
        if(defined $c->config->{'User'}->{$c->stash->{'remote_user'}}) {
            push @{$c->stash->{'usr_config_adjustments'}}, $c->config->{'User'}->{$c->stash->{'remote_user'}};
        }

        if(scalar @{$c->stash->{'usr_config_adjustments'}} > 0) {
            $c->clone_user_config() unless $c->config->{'cloned'};
            my $backends_changed;
            for my $add (@{$c->stash->{'usr_config_adjustments'}}) {
                $backends_changed = 1 if $add->{'Thruk::Backend'};
                Thruk::Config::merge_sub_config($c->config, $add);
            }
            Thruk::Config::set_default_config($c->config);
            set_configs_stash($c);
            if($backends_changed) {
                require Thruk::Backend::Pool;
                my $pool = Thruk::Backend::Pool->new($c->config->{'Thruk::Backend'}->{'peer'});
                require Thruk::Backend::Manager;
                $c->{'db'} = Thruk::Backend::Manager->new($pool);
            }
            add_defaults($c, $flags, 1);
        }
    }

    $c->stash->{'defaults_added'} = 1;

    ###############################
    # timezone settings
    my $user_tz = $c->config->{'default_user_timezone'} || "Server Setting";
    if($c->user && $c->user->{'settings'}->{'tz'}) {
        $user_tz = $c->user->{'settings'}->{'tz'};
    }
    my $timezone;
    if($user_tz ne 'Server Setting') {
        if($user_tz eq 'Local Browser') {
            $timezone = $c->cookies('thruk_tz');
        } else {
            $timezone = $user_tz;
        }
        if($timezone && $timezone =~ m/^UTC(.+)$/mx) {
            my $offset = $1*3600;
            for my $tz (@{Thruk::Utils::get_timezone_data($c)}) {
                if($tz->{'offset'} == $offset) {
                    $timezone = $tz->{'text'};
                    last;
                }
            }
        }
    }
    Thruk::Utils::Timezone::set_timezone($c->config, $timezone);

    ## use critic
    $c->stash->{'user_tz'} = $user_tz;

    ###############################
    $c->stash->{'enable_shinken_features'} = $c->config->{'enable_shinken_features'} || 0;
    $c->stash->{'enable_icinga_features'}  = $c->config->{'enable_icinga_features'}  || 0;

    ###############################
    # redirect to error page unless we have a connection
    if(!$c->db() || scalar @{$c->db->peer_order} == 0 ) {

        return 1 if $c->{'errored'};

        my $product_prefix = $c->config->{'product_prefix'};

        # return here for static content, no backend needed
        if(   $c->req->path_info =~ m|$product_prefix/\w+\.html|mx
           or $c->req->path_info =~ m|$product_prefix\/\w+\.html|mx
           or $c->req->path_info =~ m|$product_prefix\/$|mx
           or $c->req->path_info =~ m|$product_prefix\/cgi\-bin\/conf\.cgi|mx
           or $c->req->path_info =~ m|$product_prefix\/cgi\-bin\/remote\.cgi|mx
           or $c->req->path_info =~ m|$product_prefix\/cgi\-bin\/login\.cgi|mx
           or $c->req->path_info =~ m|$product_prefix\/cgi\-bin\/restricted\.cgi|mx
           or $c->req->path_info =~ m|$product_prefix\/cgi\-bin\/parts\.cgi|mx
           or $c->req->path_info eq '/'
           or $c->req->path_info eq $product_prefix
           or $c->req->path_info eq $product_prefix.'/docs'
           or $c->req->path_info eq $product_prefix.'\\/docs\\/' ) {
            $c->stash->{'no_auto_reload'} = 1;
            return 1;
        }
        # redirect to backends manager if admin user
        if( $c->config->{'use_feature_configtool'} ) {
            $c->req->parameters->{'sub'} = 'backends';
            Thruk::Utils::set_message( $c, 'fail_message', 'Please setup backend(s) connections first.');
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/conf.cgi?sub=backends");
        } else {
            return $c->detach("/error/index/14");
        }
    }

    ###############################
    # no backend?
    return unless $c->db();

    ###############################
    # read cached data
    my $cached_data = {};
    {
        my $cache = $c->cache;
        if($cache) {
            my $cached = $c->cache->get;
            $cached_data = $cached->{'global'} || {};
        }
    }

    ###############################
    my $safe_defaults_added_already;
    if(!$c->config->{'_lmd_federation_checked'} && ($ENV{'THRUK_USE_LMD'} || $c->config->{'lmd_remote'})) {
        # required on first run to expand federation peers
        eval {
            $c->db->reset_failed_backends($c);
            set_processinfo($c, ADD_SAFE_DEFAULTS, $cached_data);
            $safe_defaults_added_already = 1;
        };
    }
    my $disabled_backends = set_enabled_backends($c);

    ###############################
    # add program status
    # this is also the first query on every page, so do the
    # backend availability checks here
    if(!$no_config_adjustments && !$c->stash->{'config_adjustments'}->{'extra_backends'}) {
        $c->stats->profile(begin => "AddDefaults::get_proc_info");
        my $last_program_restart = 0;
        my $retries = 3;
        $retries = 1 if $flags; # but only once on safe/cached pages
        local $ENV{'LIVESTATUS_RETRIES'} = 0 if $flags; # skip default retries

        my $err;
        for my $x (1..$retries) {
            last if($safe_defaults_added_already && $flags);

            # reset failed states, otherwise retry would be useless
            $c->db->reset_failed_backends($c);

            eval {
                $last_program_restart = set_processinfo($c, $flags, $cached_data);
            };
            $err = $@;
            last unless $err;
            _debug(sprintf("retry %d/%d (flags: %s), data source error: %s", $x, $retries, $flags_name, $err));
            last if $x == $retries;
            sleep 1;
        }
        if($err) {
            # index.html and some other pages should not be redirect to the error page on backend errors
            set_possible_backends($c, $disabled_backends);
            if(Thruk::Base->debug) {
                _warn("data source error: $err");
            } else {
                _debug("data source error: $err");
            }
            return 1 if $flags_hash->{ADD_SAFE_DEFAULTS};
            return $c->detach('/error/index/9');
        }
        $c->stash->{'last_program_restart'} = $last_program_restart;

        set_possible_backends($c, $disabled_backends);
        $c->stats->profile(end => "AddDefaults::get_proc_info");
    }

    ###############################
    if($c->user) {
        if(   !$c->stash->{'last_program_restart'}
           || !$c->user->{'timestamp'}
           || $c->stash->{'last_program_restart'} > $c->user->{'timestamp'}
           || Thruk::Base->mode_cli()
           || ($c->user->{'timestamp'} < (time() - 300))
        ) {
            # refresh dynamic roles and groups
            $c->user->set_dynamic_attributes($c);
        }
        if($c->{'session'} && !$c->{'session'}->{'fake'}) {
            $c->stash->{'cookie_auth'} = 1;
        }
    }

    ###############################
    die_when_no_backends($c);

    if(defined $ENV{'OMD_ROOT'}) {
        # get core from init script link (omd)
        my $core = '';
        if(-e $ENV{'OMD_ROOT'}.'/etc/init.d/core') {
            $core = readlink($ENV{'OMD_ROOT'}.'/etc/init.d/core');
        }
        ###############################
        # do we have only shinken backends?
        if(!exists $c->config->{'enable_shinken_features'}) {
            $c->stash->{'enable_shinken_features'} = 1 if $core eq 'shinken';
        }

        ###############################
        # do we have only icinga backends?
        if(!exists $c->config->{'enable_icinga_features'}) {
            $c->stash->{'enable_icinga_features'} = 1 if $core eq 'icinga';
            $c->stash->{'enable_icinga_features'} = 1 if $core eq 'icinga2';
        }
    }

    # config edit buttons?
    $c->stash->{'show_config_edit_buttons'} = 0;
    if($c->config->{'use_feature_configtool'} && $c->check_user_roles("admin")) {
        # get backends with object config
        for my $peer (@{$c->db->get_peers(1)}) {
            if(scalar keys %{$peer->{'configtool'}} > 0) {
                $c->stash->{'show_config_edit_buttons'} = $c->config->{'show_config_edit_buttons'};
                $c->stash->{'backends_with_obj_config'}->{$peer->{'key'}} = 1;
            }
            else {
                $c->stash->{'backends_with_obj_config'}->{$peer->{'key'}} = 0;
            }
        }
    }

    ###############################
    # show sound preferences?
    $c->stash->{'has_cgi_sounds'} = 0;
    $c->stash->{'show_sounds'}    = 1;
    for my $key (qw/host_unreachable host_down service_critical service_warning service_unknown normal/) {
        if(defined $c->config->{$key."_sound"}) {
            $c->stash->{'has_cgi_sounds'} = 1;
            last;
        }
    }

    ###############################
    $c->stash->{'has_lmd'} = $c->config->{'use_lmd_core'} ? 1 : 0;
    $c->stash->{'has_expire_acks'} = $c->config->{'has_expire_acks'} // 1;
    $c->stash->{'require_comments_for_disable_cmds'} = $c->config->{'require_comments_for_disable_cmds'} || 0;

    ###############################
    # now double check if this user is allowed to use api keys
    if(!$c->config->{'api_keys_enabled'} && $c->req->header('X-Thruk-Auth-Key')) {
        $c->error("this account is not allowed to use api keys.");
        return;
    }

    ###############################
    $c->stash->{'navigation'} = "";
    Thruk::Utils::Menu::read_navigation($c);

    ###############################
    $c->stats->profile(end => "AddDefaults::add_defaults(".$flags_name.")");
    return 1;
}

########################################

=head2 add_safe_defaults

    same like add_defaults() but does not redirect to error page on backend errors

=cut

sub add_safe_defaults {
    my ($c) = @_;
    eval {
        add_defaults($c, ADD_SAFE_DEFAULTS);
    };
    print STDERR $@ if($@ && Thruk::Base->debug);
    return;
}

########################################

=head2 add_cached_defaults

    same like AddDefaults but trys to use cached things

=cut

sub add_cached_defaults {
    my ($c) = @_;
    my $rc = add_defaults($c, ADD_CACHED_DEFAULTS);
    # make sure process info is not getting too old
    if(!$c->stash->{'processinfo_time'} || $c->stash->{'processinfo_time'} < time() - 90) {
        Thruk::Action::AddDefaults::delayed_proc_info_update($c);
    }
    return $rc;
}

########################################

=head2 delayed_proc_info_update

    run process info update after the main page has been served

=cut
sub delayed_proc_info_update {
    my($c) = @_;
    my $cached_data = $c->cache->get->{'global'} || {};
    set_processinfo($c, ADD_SAFE_DEFAULTS, $cached_data);
    return;
}

########################################

=head2 set_configs_stash

  set_configs_stash($c)

  set some config variables directly into the stash for faster access

=cut
sub set_configs_stash {
    my($c) = @_;
    my $config = $c->config;
    my $stash  = $c->stash;
    # make some configs available in stash
    for my $key (@stash_config_keys) {
        $stash->{$key} = $config->{$key};
    }
    return;
}

########################################

=head2 set_possible_backends

  set_possible_backends($c, $disabled_backends)

  possible values are:
    0 = reachable                           REACHABLE
    1 = unreachable                         UNREACHABLE
    2 = hidden by user                      HIDDEN_USER
    3 = hidden by backend param             HIDDEN_PARAM
    4 = disabled by missing group auth      DISABLED_AUTH

   override by the config tool
    5 = disabled (overide by config tool)   DISABLED_CONF
    6 = hidden   (overide by config tool)   HIDDEN_CONF
    7 = up       (overide by config tool)   UP_CONF

   override by LMD clients
    8 = disabled (overide by lmd)           HIDDEN_LMD_PARENT

=cut
sub set_possible_backends {
    my ($c,$disabled_backends) = @_;

    my @possible_backends;
    for my $b (@{$c->db->get_peers($c->stash->{'config_backends_only'} || 0)}) {
        push @possible_backends, $b->{'key'};
    }

    my %backend_detail;
    my @new_possible_backends;

    for my $back (@possible_backends) {
        if(defined $disabled_backends->{$back} && $disabled_backends->{$back} == DISABLED_AUTH) {
            $c->db->disable_backend($back);
            next;
        }
        my $peer = $c->db->get_peer_by_key($back);
        if($peer->{disabled} && $peer->{disabled} == HIDDEN_LMD_PARENT) {
            $c->db->disable_backend($back);
            next;
        }
        $backend_detail{$back} = {
            'name'        => $peer->{'name'},
            'addr'        => $peer->{'addr'},
            'type'        => $peer->{'type'},
            'disabled'    => $disabled_backends->{$back} || REACHABLE,
            'running'     => 0,
            'last_error'  => defined $peer->{'last_error'} ? $peer->{'last_error'} : '',
            'section'     => $peer->{'section'} || 'Default',
        };
        $backend_detail{$back}->{'fed_info'} = $peer->{'fed_info'} if $peer->{'fed_info'};
        if(ref $c->stash->{'pi_detail'} eq 'HASH' and defined $c->stash->{'pi_detail'}->{$back}->{'program_start'}) {
            $backend_detail{$back}->{'running'} = 1;
        }
        # set combined state
        $backend_detail{$back}->{'state'} = UNREACHABLE; # down
        if($backend_detail{$back}->{'running'})                  { $backend_detail{$back}->{'state'} = REACHABLE;    } # up
        if($backend_detail{$back}->{'disabled'} == HIDDEN_USER)  { $backend_detail{$back}->{'state'} = HIDDEN_USER;  } # hidden
        if($backend_detail{$back}->{'disabled'} == HIDDEN_PARAM) { $backend_detail{$back}->{'state'} = HIDDEN_PARAM; } # unused
        push @new_possible_backends, $back;
    }

    $c->stash->{'backends'}         = \@new_possible_backends;
    $c->stash->{'backend_detail'}   = \%backend_detail;

    return;
}

########################################

=head2 update_site_panel_hashes

  update_site_panel_hashes($c)

=cut
sub update_site_panel_hashes {
    my($c, $selected_backends) = @_;

    if($selected_backends) {
        set_enabled_backends($c, $selected_backends);
    }

    my $initial_backends = {};
    my $backends         = $c->stash->{'backends'};
    my $backend_detail   = $c->stash->{'backend_detail'};

    return unless $backends;
    return if scalar @{$backends} == 0;

    # create flat list of backend hashes used in javascript
    for my $back (@{$backends}) {
        my $peer = $c->db->get_peer_by_key($back);
        $initial_backends->{$back} = {
            key              => $back,
            name             => $peer->{'name'} || 'unknown',
            state            => $backend_detail->{$back}->{'state'},
            version          => '',
            data_src_version => '',
            program_start    => '',
            section          => $backend_detail->{$back}->{'section'},
        };
        if($peer->{'last_online'}) {
            $initial_backends->{$back}->{'last_online'} = time() - $peer->{'last_online'};
        }
        if(ref $c->stash->{'pi_detail'} eq 'HASH' and defined $c->stash->{'pi_detail'}->{$back}) {
            $initial_backends->{$back}->{'version'}          = $c->stash->{'pi_detail'}->{$back}->{'program_version'};
            $initial_backends->{$back}->{'data_src_version'} = $c->stash->{'pi_detail'}->{$back}->{'data_source_version'};
            $initial_backends->{$back}->{'program_start'}    = $c->stash->{'pi_detail'}->{$back}->{'program_start'};
            $initial_backends->{$back}->{'local'}            = $peer->is_local();
        }
    }

    # create sections and subsection for site panel
    $c->db->update_sections(); # need to recalculate, using the config tool removes sections without config backends
    _calculate_section_totals($c, $c->db->{'sections'}, $backend_detail, $initial_backends);

    my $show_sitepanel = 'list';
       if($c->config->{'sitepanel'} eq 'list')      { $show_sitepanel = 'list'; }
    elsif($c->config->{'sitepanel'} eq 'compact')   { $show_sitepanel = 'panel'; }
    elsif($c->config->{'sitepanel'} eq 'collapsed') { $show_sitepanel = 'collapsed'; }
    elsif($c->config->{'sitepanel'} eq 'tree')      { $show_sitepanel = 'tree'; }
    elsif($c->config->{'sitepanel'} eq 'off')       { $show_sitepanel = 'off'; }
    elsif($c->config->{'sitepanel'} eq 'auto') {
        if($c->db->{'sections_depth'} > 1 || scalar @{$backends} >= 100)   { $show_sitepanel = 'tree'; }
        elsif($c->db->{'sections_depth'} > 1 || scalar @{$backends} >= 50) { $show_sitepanel = 'collapsed'; }
        elsif($c->db->{'sections'}->{'sub'} || scalar @{$backends} >= 10)  { $show_sitepanel = 'panel'; }
        elsif(scalar @{$backends} == 1) { $show_sitepanel = 'off'; }
        else { $show_sitepanel = 'list'; }
    }

    $c->stash->{'initial_backends'} = $initial_backends;
    $c->stash->{'show_sitepanel'}   = $show_sitepanel;
    $c->stash->{'sites'}            = $c->db->{'sections'};

    # merge all panel in a Default section
    if($show_sitepanel eq 'panel' || $show_sitepanel eq 'list') {
        my $sites = $c->stash->{'sites'};
        if(!$sites->{'sub'} || !$sites->{'sub'}->{'Default'}) {
            $sites->{'sub'}->{'Default'} = { peers => delete $sites->{'peers'} || [] };
        }
        delete $sites->{'sub'}->{'Default'} if scalar @{$sites->{'sub'}->{'Default'}->{'peers'}} == 0;
    }

    return;
}

########################################
sub _calculate_section_totals {
    my($c, $section, $backend_detail, $initial_backends) = @_;
    for my $key (qw/up disabled down total/) {
        $section->{$key} = 0;
    }

    if($section->{'sub'}) {
        for my $n (keys %{$section->{'sub'}}) {
            my $s = $section->{'sub'}->{$n};
            _calculate_section_totals($c, $s, $backend_detail, $initial_backends);
            for my $key (qw/up disabled down total/) {
                $section->{$key} += $s->{$key};
            }
            delete $section->{'sub'}->{$n} if($s->{'total'} == 0);
        }
    }

    if($section->{'peers'}) {
        for my $pd (@{$section->{'peers'}}) {
            next if(!$backend_detail->{$pd} || $backend_detail->{$pd}->{'disabled'} == DISABLED_CONF);
            my $class = 'DOWN';
            $class = 'UP'   if $backend_detail->{$pd}->{'running'};
            $class = 'DOWN' if $c->stash->{'failed_backends'}->{$pd};
            $class = 'DIS'  if $backend_detail->{$pd}->{'disabled'} == HIDDEN_USER;
            $class = 'HID'  if $backend_detail->{$pd}->{'disabled'} == HIDDEN_PARAM;
            $class = 'HID'  if $c->stash->{'param_backend'} && !(grep {/\Q$pd\E/mx} @{Thruk::Base::list($c->stash->{'param_backend'})});
            $class = 'DIS'  if $backend_detail->{$pd}->{'disabled'} == HIDDEN_CONF;
            $class = 'UP'   if($backend_detail->{$pd}->{'disabled'} == UP_CONF && $class ne 'DOWN');
            $backend_detail->{$pd}->{'class'} = $class;
            my $total_key = lc $class;
            if($class eq 'DIS' || $class eq 'HID') {
                $total_key = 'disabled';
            }
            $section->{$total_key}++;
            $section->{'total'}++;
            $initial_backends->{$pd}->{'cls'} = $class;
            my $last_error =  'OK';
            if($c->stash->{'failed_backends'}->{$pd}) {
                $last_error = $c->stash->{'failed_backends'}->{$pd};
            }
            if($backend_detail->{$pd}->{'last_error'}) {
                $last_error = $backend_detail->{$pd}->{'last_error'};
            }
            $initial_backends->{$pd}->{'last_error'} = $last_error;
        }
    }
    return;
}

########################################
sub _any_backend_enabled {
    my ($c) = @_;
    for my $peer_key (keys %{$c->stash->{'backend_detail'}}) {
        return 1 if(
             $c->stash->{'backend_detail'}->{$peer_key}->{'disabled'} == REACHABLE
          or $c->stash->{'backend_detail'}->{$peer_key}->{'disabled'} == DISABLED_CONF);

    }
    return;
}

########################################

=head2 set_processinfo

  set_processinfo($c, [$safe, $cached_data])

set process info into stash

=cut
sub set_processinfo {
    my($c, $flags, $cached_data) = @_;
    my $last_program_restart = 0;
    my($flags_hash, $flags_name) = _get_flags($flags);

    $c->stats->profile(begin => "AddDefaults::set_processinfo(".$flags_name.")");

    # cached process info?
    my $processinfo;
    $cached_data->{'processinfo'} = {} unless defined $cached_data->{'processinfo'};
    my $fetch = 0;
    my($selected) = $c->db->select_backends('get_status');
    if($flags) { # cached or safe
        $processinfo = $cached_data->{'processinfo'};
        for my $key (@{$selected}) {
            if(!defined $processinfo->{$key} || !defined $processinfo->{$key}->{'program_start'}) {
                $fetch = 1;
                last;
            }
        }
    } else {
        $fetch = 1;
    }
    $fetch = 1 if $ENV{'THRUK_USE_LMD'} && !$flags_hash->{ADD_CACHED_DEFAULTS};
    $fetch = 1 if $c->config->{'lmd_remote'};
    $c->stash->{'processinfo_time'} = $cached_data->{'processinfo_time'} if $cached_data->{'processinfo_time'};

    if($fetch) {
        $c->stats->profile(begin => "AddDefaults::set_processinfo fetch");
        $processinfo = $c->db->get_processinfo(debug_hint => 'set_processinfo') unless $c->config->{'lmd_remote'};
        if(ref $processinfo eq 'ARRAY' && scalar @{$processinfo} == 0) {
            # may happen when no backends are selected or the current selected backends comes from a federation http
            $processinfo = {};
        }
        if(ref $processinfo eq 'HASH' || $c->config->{'lmd_remote'}) {
            if($ENV{'THRUK_USE_LMD'}) {
                ($processinfo, $cached_data) = check_federation_peers($c, $processinfo, $cached_data);
            }
        }
        $cached_data->{'processinfo_time'} = time();
        $c->stash->{'processinfo_time'}    = $cached_data->{'processinfo_time'};
        $c->cache->set('global', $cached_data);
        $c->stats->profile(end => "AddDefaults::set_processinfo fetch");
    }

    $processinfo                 = {} unless defined $processinfo;
    $processinfo                 = {} if(ref $processinfo eq 'ARRAY' && scalar @{$processinfo} == 0);
    my $overall_processinfo      = Thruk::Utils::calculate_overall_processinfo($processinfo, $selected);
    $c->stash->{'pi'}            = $overall_processinfo;
    $c->stash->{'pi_detail'}     = $processinfo;
    $c->stash->{'has_proc_info'} = 1;

    # set last programm restart
    if(ref $processinfo eq 'HASH') {
        for my $backend (keys %{$processinfo}) {
            next if !defined $processinfo->{$backend}->{'program_start'};
            $last_program_restart = $processinfo->{$backend}->{'program_start'} if $last_program_restart < $processinfo->{$backend}->{'program_start'};
            $c->db->{'last_program_starts'}->{$backend} = $processinfo->{$backend}->{'program_start'};
        }
    }

    # check our backends uptime
    if(defined $c->config->{'delay_pages_after_backend_reload'} and $c->config->{'delay_pages_after_backend_reload'} > 0) {
        my $delay_pages_after_backend_reload = $c->config->{'delay_pages_after_backend_reload'} || 0;
        for my $backend (keys %{$processinfo}) {
            next unless($processinfo->{$backend} and $processinfo->{$backend}->{'program_start'});
            my $delay = int($processinfo->{$backend}->{'program_start'} + $delay_pages_after_backend_reload - time());
            if($delay > 0) {
                _debug("delaying page delivery by $delay seconds...");
                sleep($delay);
            }
        }
    }

    $c->stats->profile(end => "AddDefaults::set_processinfo(".$flags_name.")");

    return($last_program_restart);
}

########################################

=head2 set_enabled_backends

  set_enabled_backends($c, [$backends])

set enabled backends from environment or given list

=cut
sub set_enabled_backends {
    my($c, $backends) = @_;

    # first all backends are enabled
    if(defined $c->db()) {
        $c->db->enable_backends();
    }

    if($c->req->parameters->{'backend'} && $c->req->parameters->{'backends'}) {
        confess("'backend' and 'backends' parameter set!");
    }
    if($c->req->parameters->{'be'} && !$c->req->parameters->{'backend'}) {
        $c->req->parameters->{'backend'} = delete $c->req->parameters->{'be'};
    }
    my $backend  = $c->req->parameters->{'backend'} || $c->req->parameters->{'backends'};
    $c->stash->{'param_backend'} = $backend || '';
    my $disabled_backends = {};
    my $num_backends      = @{$c->db->get_peers()};
    $c->stash->{'num_backends'} = $num_backends;
    my $cookie_src = $c->stash->{'backend_cookie_src'} // 'thruk_backends';

    ###############################
    # by args
    if(defined $backends) {
        _debug('set_enabled_backends() by args') if Thruk::Base->debug;
        # reset
        for my $peer (@{$c->db->get_peers()}) {
            $disabled_backends->{$peer->{'key'}} = HIDDEN_USER; # set all hidden
        }
        for my $str (@{Thruk::Base::list($backends)}) {
            for my $b (split(/\s*,\s*/mx, $str)) {
                # peer key can be name too
                if($b eq 'ALL') {
                    for my $peer (@{$c->db->get_peers()}) {
                        $disabled_backends->{$peer->{'key'}} = 0;
                    }
                }
                elsif($b eq 'LOCAL') {
                    for my $peer (@{$c->db->get_local_peers()}) {
                        $disabled_backends->{$peer->{'key'}} = 0;
                    }
                }
                elsif($b =~ m|\/|mx) {
                    if(!_set_disabled_by_section($c, $b, $disabled_backends)) {
                        _warn(sprintf("no backend found for section: %s", $b));
                    }
                } else {
                    my $peer = $c->db->get_peer_by_key($b);
                    if($peer) {
                        $disabled_backends->{$peer->{'key'}} = 0;
                    } else {
                        if(!_set_disabled_by_section($c, $b, $disabled_backends)) {
                            _warn(sprintf("no backend found for: %s", $b));
                        }
                    }
                }
            }
        }
    }
    ###############################
    # by env
    elsif(defined $ENV{'THRUK_BACKENDS'}) {
        _debug('set_enabled_backends() by env: '.Dumper($ENV{'THRUK_BACKENDS'})) if Thruk::Base->debug;
        # reset
        for my $peer (@{$c->db->get_peers()}) {
            $disabled_backends->{$peer->{'key'}} = HIDDEN_USER; # set all hidden
        }
        for my $b (split(/;/mx, $ENV{'THRUK_BACKENDS'})) {
            # peer key can be name too
            if($b eq 'ALL') {
                for my $peer (@{$c->db->get_peers()}) {
                    $disabled_backends->{$peer->{'key'}} = 0;
                }
            }
            elsif($b eq 'LOCAL') {
                for my $peer (@{$c->db->get_local_peers()}) {
                    $disabled_backends->{$peer->{'key'}} = 0;
                }
            }
            elsif($b =~ m|\/|mx) {
                if(!_set_disabled_by_section($c, $b, $disabled_backends)) {
                    _warn(sprintf("no backend found for section: %s", $b));
                }
            } else {
                my $peer = $c->db->get_peer_by_key($b);
                if($peer) {
                    $disabled_backends->{$peer->{'key'}} = 0;
                } else {
                    if(!_set_disabled_by_section($c, $b, $disabled_backends)) {
                        # silently ignore, leads to hen/egg problem when using federation peers
                        #die("got no peer for: ".$b);
                        #_warn(sprintf("no backend found for: %s", $b));
                    }
                }
            }
        }
    }

    ###############################
    # by param
    elsif($num_backends > 1 and defined $backend) {
        _debug('set_enabled_backends() by param') if Thruk::Base->debug;
        # reset
        for my $peer (@{$c->db->get_peers()}) {
            $disabled_backends->{$peer->{'key'}} = HIDDEN_USER;  # set all hidden
        }
        if($backend eq 'ALL') {
            my @keys;
            for my $peer (@{$c->db->get_peers()}) {
                $disabled_backends->{$peer->{'key'}} = 0;
                push @keys, $peer->{'key'};
            }
            $c->stash->{'param_backend'} = join(",", @keys);
        }
        elsif($backend eq 'LOCAL') {
            my @keys;
            for my $peer (@{$c->db->get_local_peers()}) {
                $disabled_backends->{$peer->{'key'}} = 0;
                push @keys, $peer->{'key'};
            }
            $c->stash->{'param_backend'} = join(",", @keys);
        }
        elsif($backend =~ m|\/|mx) {
            if(!_set_disabled_by_section($c, $backend, $disabled_backends)) {
                _warn(sprintf("no backend found for section: %s", $backend));
            }
        } else {
            for my $b (ref $backend eq 'ARRAY' ? @{$backend} : split/,/mx, $backend) {
                $disabled_backends->{$b} = 0;
            }
        }
    }

    ###############################
    # by cookie
    elsif($num_backends > 1 && defined $c->cookies($cookie_src)) {
        _debug('set_enabled_backends() by cookie (%s)', $cookie_src) if Thruk::Base->debug;
        my @cookie_backends = $c->cookies($cookie_src);
        for my $val (@cookie_backends) {
            my($key, $value) = split/=/mx, $val;
            next unless defined $value;
            $disabled_backends->{$key} = $value;
        }
    }
    elsif(defined $c->db()) {
        _debug('set_enabled_backends() using defaults') if Thruk::Base->debug;
        my $display_too = 0;
        if(defined $c->req->header('user-agent') and $c->req->header('user-agent') !~ m/thruk/mxi) {
            $display_too = 1;
        }
        $disabled_backends = $c->db->disable_hidden_backends($disabled_backends, $display_too);
    }

    ###############################
    # groups affected?
    if(defined $c->db()) {
        for my $peer (@{$c->db->get_peers()}) {
            if(defined $peer->{'groups'}) {
                my $access = 0;
                for my $grp (Thruk::Base::comma_separated_list($peer->{'groups'})) {
                    if($c->user->has_group($grp)) {
                        $access = 1;
                        last;
                    }
                }
                if(!$access) {
                    $disabled_backends->{$peer->{'key'}} = DISABLED_AUTH;  # completly hidden
                }
            }
        }
        $c->db->disable_backends($disabled_backends);
    }

    # when set by args, update
    if(defined $backends) {
        set_possible_backends($c, $disabled_backends);
    }
    _debug('disabled_backends: '.Dumper($disabled_backends)) if Thruk::Base->debug;
    return($disabled_backends);
}

########################################

=head2 has_backends_set

  has_backends_set($c)

    returns 1 if user has set custom backends

=cut
sub has_backends_set {
    my($c) = @_;
    my $num_backends = scalar @{$c->db->get_peers()};
    my $cookie_src   = $c->stash->{'backend_cookie_src'} // 'thruk_backends';
    if($num_backends <= 1) {
        return;
    }
    if(defined $c->cookies($cookie_src)) {
        return(1);
    }
    my $backend  = $c->req->parameters->{'backend'} || $c->req->parameters->{'backends'};
    if(defined $backend) {
        return(1);
    }
    if(defined $ENV{'THRUK_BACKENDS'}) {
        return(1);
    }

    return;
}

########################################
sub _set_disabled_by_section {
    my($c, $backend, $disabled_backends) = @_;
    $backend =~ s/\/$//gmx;
    $backend =~ s/^\///gmx;
    $backend = '/'.$backend.'/';
    my $found;
    for my $peer (@{$c->db->get_peers()}) {
        my $test = '/'.$peer->{'section'}.'/';
        if($test =~ m|^\Q$backend\E|mx) {
            $disabled_backends->{$peer->{'key'}} = 0;
            $found++;
        }
    }
    return($found);
}

########################################

=head2 die_when_no_backends

    die unless there are any backeds defined and enabled

=cut
sub die_when_no_backends {
    my($c) = @_;
    if(!defined $c->stash->{'pi_detail'} && _any_backend_enabled($c)) {
        _error("got no result from any backend, please check backend connection and logfiles");
        return $c->detach('/error/index/9');
    }
    return;
}

########################################

=head2 save_debug_information_to_tmp_file

    save debug information to a temp file

=cut
sub save_debug_information_to_tmp_file {
    my($c) = @_;

    $c->stats->profile(begin => "save_debug_information_to_tmp_file");
    my $tmp = $c->config->{'tmp_path'}.'/debug';
    Thruk::Utils::IO::mkdir_r($tmp);
    my $tmpfile = $tmp.'/'.POSIX::strftime('%Y-%m-%d_%H_%M_%S', localtime).'.log';
    open(my $fh, '>', $tmpfile);
    print $fh 'Uri: '.Thruk::Utils::Filter::full_uri($c)."\n";
    print $fh "*************************************\n";
    print $fh "version: ".Thruk::Utils::Filter::fullversion($c)."\n";
    print $fh "user:    ".$c->stash->{'remote_user'}."\n";
    print $fh "parameters:\n";
    print $fh Dumper($c->req->parameters);
    print $fh "debug info:\n";
    print $fh Thruk::Config::get_debug_details($c);
    if($c->stash->{'original_url'}) {
        print $fh "*************************************\n";
        print $fh "job:\n";
        print $fh 'Uri: '.$c->stash->{'original_url'}."\n";
    }
    print $fh "*************************************\n";
    print $fh "\n";
    print $fh $c->stash->{'debug_info'};
    Thruk::Utils::IO::close($fh, $tmpfile);
    $c->stash->{'debug_info_file'} = $tmpfile;
    Thruk::Utils::set_message($c, 'success_message js-no-auto-hide', 'Debug information written to: '.$tmpfile);
    $c->stats->profile(end => "save_debug_information_to_tmp_file");
    return($tmpfile);
}

########################################

=head2 check_federation_peers

    expand peers if a single backend returns more than one site,
    for example with lmd federation

=cut
sub check_federation_peers {
    my($c, $processinfo, $cached_data) = @_;
    return($processinfo, $cached_data) if $ENV{'THRUK_USE_LMD_FEDERATION_FAILED'};
    my $all_sites_info;
    eval {
        $all_sites_info = $c->db->get_sites(backend => ["ALL"], sort => {'ASC' => 'peer_name'}, debug_hint => "check_federation_peers");
    };
    if($@) {
        # may fail for older lmd releases which don't have parent or section information
        if($@ =~ m/\Qbad request: table sites has no column\E/mx) {
            _info("cannot check lmd federation mode, please update LMD.");
            ## no critic
            $ENV{'THRUK_USE_LMD_FEDERATION_FAILED'} = 1;
            ## use critic
        }
    }
    return($processinfo, $cached_data) unless $all_sites_info;

    # add sub federated backends
    my $check_lmd_config;
    my $existing =  {};
    my $changed  = 0;
    for my $row (@{$all_sites_info}) {
        my $key = $row->{'key'};
        $existing->{$key} = 1;
        $existing->{$row->{'parent'}} = 1 if $row->{'parent'};
        if(!$c->db->peers->{$key}) {
            $row->{'parent'} = 'LMD' if(!$row->{'parent'} && $c->config->{'lmd_remote'});
            my $parent = $c->db->peers->{$row->{'parent'}};
            if(!$parent) {
                _warn("got unknown peer key, recheck lmd config: %s(%s)", $row->{'name'}, $row->{'peer_key'});
                $check_lmd_config = 1; # got unknown peer key, recheck lmd config
                next;
            }
            my $section = "";
            if($c->config->{'lmd_remote'}) {
                    $section = $row->{'section'};
            } else {
                if($row->{'section'}) {
                    $section = $parent->peer_name().'/'.$row->{'section'};
                } else {
                    $section = $parent->peer_name();
                }
            }
            my $subpeerconfig = {
                name    => $row->{'name'},
                id      => $key,
                type    => $parent->{'peer_config'}->{'type'},
                section => $section,
                options => $parent->{'peer_config'}->{'type'} eq 'http' ? Thruk::Utils::IO::dclone($parent->{'peer_config'}->{'options'}) : {},
            };
            delete $subpeerconfig->{'options'}->{'name'};
            delete $subpeerconfig->{'options'}->{'peer'};
            $subpeerconfig->{'options'}->{'peer'} = $row->{'addr'};
            $subpeerconfig->{'options'}->{'remote_name'} = $row->{'name'};
            require Thruk::Backend::Peer;
            my $subpeer = Thruk::Backend::Peer->new($subpeerconfig, $c->config, {});
            $subpeer->{'federation'} = $parent->{'key'};
            $subpeer->{'fed_info'} = {
                key        => [$parent->{'key'}, @{Thruk::Base::list($row->{'federation_key'})}],
                name       => [$parent->{'name'}, @{Thruk::Base::list($row->{'federation_name'})}],
                addr       => [$parent->{'addr'}, @{Thruk::Base::list($row->{'federation_addr'})}],
                type       => [$parent->{'type'}, @{Thruk::Base::list($row->{'federation_type'})}],
            };
            # inherit disabled configtool from parent
            if($parent->{'peer_config'}->{'configtool'}->{'disable'}) {
                $subpeer->{'peer_config'}->{'configtool'}->{'disable'} = 1;
            }
            $c->db->pool->peer_add($subpeer);
            $parent->{'disabled'} = HIDDEN_LMD_PARENT;
            $changed++;
        }
    }
    # remove exceeding backends
    for my $key (@{$c->db->peer_order}) {
        my $peer = $c->db->peers->{$key};
        if(!$peer->{'federation'}) {
            if(!$existing->{$key}) {
                _warn("peer key not found, recheck lmd config: %s(%s)", $peer->{'name'}, $key);
                $check_lmd_config = 1; # got unknown peer key, recheck lmd config
            }
            next;
        }
        if(!$existing->{$key}) {
            delete $cached_data->{'processinfo'}->{$key};
            $c->db->pool->peer_remove($key);
            $changed++;
            next;
        }
    }
    if($changed || !$processinfo) {
        $c->db->update_sections();
        # fetch missing processinfo
        $processinfo = $c->db->get_processinfo();
        for my $key (keys %{$processinfo}) {
            $cached_data->{'processinfo'}->{$key} = $processinfo->{$key};
        }
    }
    # set a few extra infos
    for my $d (@{$all_sites_info}) {
        my $key = $d->{'key'};
        my $peer = $c->db->peers->{$key};
        next unless $peer;
        for my $col (qw/last_online last_update last_error/) {
            $peer->{$col} = $d->{$col};
        }
    }
    $c->config->{'_lmd_federation_checked'} = time();

    if($check_lmd_config && !$c->config->{'lmd_remote'}) {
        require Thruk::Utils::LMD;
        Thruk::Utils::LMD::check_changed_lmd_config($c, $c->config);
    }
    return($processinfo, $cached_data);
}

########################################

=head2 set_custom_title

  set_custom_title($c)

sets page title based on http parameters

=cut
sub set_custom_title {
    my($c) = @_;
    $c->stash->{custom_title} = '';
    if( exists $c->req->parameters->{'title'} ) {
        my $custom_title          = $c->req->parameters->{'title'};
        if(ref $custom_title eq 'ARRAY') { $custom_title = pop @{$custom_title}; }
        $custom_title             =~ s/\+/\ /gmx;
        $c->stash->{custom_title} = Thruk::Utils::Filter::escape_html($custom_title);
        $c->stash->{title}        = $custom_title;
        return 1;
    }
    return;
}

########################################
sub _get_flags {
    my($flags) = @_;
    my $flags_hash = {};
    $flags = ADD_DEFAULTS unless defined $flags;
    $flags = Thruk::Utils::list($flags);
    my $flags_name = [];
    for my $s (@{$flags}) {
        for my $name (keys %Thruk::Constants::add_defaults) {
            if($Thruk::Constants::add_defaults{$name} == $s) {
                $flags_hash->{$name} = 1;
                $name =~ s/ADD_(.+?)S/$1/gmx;
                push @{$flags_name}, $name;
                last;
            }
        }
    }
    $flags_name = join(",", @{$flags_name});
    return($flags_hash, $flags_name);
}

1;
