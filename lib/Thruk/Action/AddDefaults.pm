package Thruk::Action::AddDefaults;

=head1 NAME

Thruk::Action::AddDefaults - Add Defaults to the context

=head1 DESCRIPTION

loads cgi.cfg

creates backend manager

=head1 METHODS

=cut


use strict;
use warnings;
use Carp qw/confess/;
use Data::Dumper qw/Dumper/;
use Cpanel::JSON::XS qw/encode_json/;
use Scalar::Util qw/weaken/;
use POSIX ();
use Thruk::Utils::Filter ();

our @stash_config_keys = qw/
    url_prefix product_prefix title_prefix use_pager start_page documentation_link
    use_feature_statusmap use_feature_statuswrl use_feature_histogram use_feature_configtool
    datetime_format datetime_format_today datetime_format_long datetime_format_log
    use_new_search show_notification_number strict_passive_mode hide_passive_icon
    show_full_commandline all_problems_link use_ajax_search show_long_plugin_output
    priorities show_modified_attributes downtime_duration expire_ack_duration show_contacts
    show_backends_in_table host_action_icon service_action_icon cookie_path
    use_feature_trends show_error_reports skip_js_errors perf_bar_mode
    bug_email_rcpt home_link first_day_of_week sitepanel perf_bar_pnp_popup
    status_color_background show_logout_button use_feature_recurring_downtime
    use_service_description force_sticky_ack force_send_notification force_persistent_ack
    force_persistent_comments use_bookmark_titles use_dynamic_titles use_feature_bp
/;

use constant {
    REACHABLE        => 0,
    UNREACHABLE      => 1,
    HIDDEN_USER      => 2,
    HIDDEN_PARAM     => 3,
    DISABLED_AUTH    => 4,

    DISABLED_CONF    => 5,
    HIDDEN_CONF      => 6,
    UP_CONF          => 7,

    HIDDEN_LMD_PARENT => 8,
};

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

    Thruk::Action::AddDefaults::set_configs_stash($c);
    $c->stash->{'root_begin'} = 1;

    $c->stash->{'c'} = $c;
    weaken($c->stash->{'c'});

    # user data
    $c->stash->{'user_data'} = { bookmarks => {} };

    # frame options
    my $use_frames = $c->config->{'use_frames'};
    my $show_nav_button = 1;
    if( exists $c->req->parameters->{'nav'} and $c->req->parameters->{'nav'} ne '' ) {
        if( $c->req->parameters->{'nav'} ne '1' ) {
            $show_nav_button = 1;
        }
        $use_frames = 1;
        if( $c->req->parameters->{'nav'} eq '1' ) {
            $use_frames = 0;
        }
    }
    if( $c->config->{'use_frames'} == 1 ) {
        $show_nav_button = 0;
    }
    $c->stash->{'use_frames'}         = $use_frames;
    $c->stash->{'show_nav_button'}    = $show_nav_button;
    $c->stash->{'reload_nav'}         = $c->req->parameters->{'reload_nav'} || '';
    $c->stash->{'show_sounds'}        = 0;
    $c->stash->{'has_debug_options'}  = $c->req->parameters->{'debug'} || 0;

    # use pager?
    Thruk::Utils::set_paging_steps($c, $c->config->{'paging_steps'});

    # which theme?
    my($param_theme, $cookie_theme);
    if( $c->req->parameters->{'theme'} ) {
        $param_theme = $c->req->parameters->{'theme'};
    }
    elsif( defined $c->cookie('thruk_theme') ) {
        my $theme_cookie = $c->cookie('thruk_theme');
        $cookie_theme = $theme_cookie->value if defined $theme_cookie->value and grep $theme_cookie->value, $c->config->{'themes'};
    }
    my $theme = $param_theme || $cookie_theme || $c->config->{'default_theme'};
    my $available_themes = Thruk::Utils::array2hash($c->config->{'View::TT'}->{'PRE_DEFINE'}->{'themes'});
    $theme = $c->config->{'default_theme'} unless defined $available_themes->{$theme};
    $c->stash->{'theme'} = $theme;
    if( defined $c->config->{templates_paths} ) {
        # themes have to override plugins templates
        $c->stash->{additional_template_paths} = [ $c->config->{themes_path}.'/themes-enabled/'.$theme.'/templates', @{ $c->config->{templates_paths} } ];
    }
    else {
        $c->stash->{additional_template_paths} = [ $c->config->{themes_path}.'/themes-enabled/'.$theme.'/templates' ];
    }
    $c->stash->{all_in_one_css} = 0;
    if($theme eq 'Thruk' || $theme eq 'Thruk2') {
        $c->stash->{all_in_one_css} = 1;
    }

    if(exists $c->req->parameters->{'noheader'}) {
        $c->req->parameters->{'hidetop'}  = 1;
    }
    $c->stash->{hidetop} = $c->req->parameters->{'hidetop'} || '';

    # minmal custom monitor screen
    $c->stash->{minimal}               = $c->req->parameters->{'minimal'} || '';
    $c->stash->{show_nav_button}       = 0 if $c->stash->{minimal};

    # menu cookie set?
    my $menu_states = {};
    for my $key (keys %{$c->config->{'initial_menu_state'}}) {
        my $val = $c->config->{'initial_menu_state'}->{$key};
        $key = lc $key;
        $key =~ s/\ /_/gmx;
        $menu_states->{$key} = $val;
    }
    if( defined $c->cookie('thruk_side') ) {
        for my $state (@{$c->cookies('thruk_side')->{'value'}}) {
            my($k,$v) = split(/=/mx,$state,2);
            $k = lc $k;
            $k =~ s/\ /_/gmx;
            $menu_states->{$k} = $v;
        }
    }

    $c->stash->{'menu_states'}      = $menu_states;
    $c->stash->{'menu_states_json'} = encode_json($menu_states);

    my $target = $c->req->parameters->{'target'};
    if( !$c->stash->{'use_frames'} && defined $target && $target eq '_parent' ) {
        $c->stash->{'target'} = '_parent';
    }

    $c->stash->{'iframed'} = $c->req->parameters->{'iframed'} || 0;

    # additional views on status pages
    $c->stash->{'additional_views'} = $Thruk::Utils::Status::additional_views || {};

    # icon image path
    $c->config->{'logo_path_prefix'} = exists $c->config->{'logo_path_prefix'} ? $c->config->{'logo_path_prefix'} : $c->stash->{'url_prefix'}.'themes/'.$c->stash->{'theme'}.'/images/logos/';
    $c->stash->{'logo_path_prefix'}  = $c->config->{'logo_path_prefix'};

    # make private _ hash keys available
    $Template::Stash::PRIVATE = undef;

    if(defined $c->cookie('thruk_auth')) {
        $c->stash->{'cookie_auth'} = 1;
    }

    # view mode must be a scalar
    for my $key (qw/view_mode hidesearch hidetop style/) {
        if($c->req->parameters->{$key}) {
            if(ref $c->req->parameters->{$key} eq 'ARRAY') {
                $c->req->parameters->{$key} = pop(@{$c->req->parameters->{$key}});
            }
        }
    }

    ###############################
    # parse cgi.cfg
    Thruk::Utils::read_cgi_cfg($c);

    ###############################
    # Authentication
    $c->log->debug("checking auth") if Thruk->verbose;
    if($c->req->path_info =~ m~cgi-bin/remote\.cgi~mx) {
        $c->log->debug("remote.cgi does not use authentication") if Thruk->debug;
    }
    elsif($c->req->path_info =~ m~cgi-bin/login\.cgi~mx) {
        $c->log->debug("login.cgi does not use authentication");
    } else {
        unless($c->user_exists) {
            $c->log->debug("user not authenticated yet") if Thruk->verbose;
            unless ($c->authenticate()) {
                # return 403 forbidden or kick out the user in other way
                $c->log->debug("user is not authenticated") if Thruk->verbose;
                return $c->detach('/error/index/10');
            }
        }
        if($c->user_exists) {
            $c->log->debug("user authenticated as: ".$c->user->get('username')) if Thruk->verbose;
            $c->stash->{'remote_user'}= $c->user->get('username');
        }
    }

    # when adding nav=1 to a url in frame mode, redirect to frame.html with this url
    if( defined $c->req->parameters->{'nav'}
            and $c->req->parameters->{'nav'} eq '1'
            and $c->config->{'use_frames'} == 1 ) {
        my $path = $c->req->uri->path_query;
        $path =~ s/nav=1//gmx;
        return $c->redirect_to($c->stash->{'url_prefix'}."frame.html?link=".uri_escape($path));
    }

    # sound cookie set?
    if(defined $c->cookie('thruk_sounds')) {
        my $sound_cookie = $c->cookie('thruk_sounds');
        if(defined $sound_cookie->value and $sound_cookie->value eq 'off') {
            $c->stash->{'play_sounds'} = 0;
        }
        if(defined $sound_cookie->value and $sound_cookie->value eq 'on') {
            $c->stash->{'play_sounds'} = 1;
        }
    }

    # favicon cookie set?
    if(defined $c->cookie('thruk_favicon')) {
        my $favicon_cookie = $c->cookie('thruk_favicon');
        if(defined $favicon_cookie->value and $favicon_cookie->value eq 'off') {
            $c->stash->{'fav_counter'} = 0;
        }
        if(defined $favicon_cookie->value and $favicon_cookie->value eq 'on') {
            $c->stash->{'fav_counter'} = 1;
        }
    }

    $c->stash->{'usercontent_folder'} = $c->config->{'home'}.'/root/thruk/usercontent';
    # make usercontent folder based on env var if set. But only if it exists. Fallback to standard folder
    # otherwise except it doesn't exist either. Then better take the later if both do not exist.
    if($ENV{'THRUK_CONFIG'} && (-d $ENV{'THRUK_CONFIG'}.'/usercontent/.' || !-d $c->stash->{'usercontent_folder'}.'/.')) {
        $c->stash->{'usercontent_folder'} = $ENV{'THRUK_CONFIG'}.'/usercontent';
    }

    # initialize our backends
    if(!$c->{'db'} ) {
        $c->{'db'} = $c->app->{'db'};
        if(defined $c->{'db'}) {
            $c->{'db'}->init(
                'backend_debug' => $c->config->{'backend_debug'},
            );
        }
    }

    $c->stash->{global_user_data} = Thruk::Utils::get_global_user_data($c);
    $c->stash->{user_data}        = Thruk::Utils::get_user_data($c);

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
            # we need the navigation only if we don't use frames or its the side.html
            if($c->req->path =~ m/\/side\.html/mx || !$c->stash->{'use_frames'}) {
                Thruk::Utils::Menu::read_navigation($c);
            }
        }
    }

    my @errors = @{ $c->error };
    if( scalar @errors > 0 ) {
        for my $error (@errors) {
            $c->log->error($error);
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
                if($Thruk::COUNT >= 2 && scalar keys %{$res} > 0) {
                    $c->log->info("request: ".$Thruk::COUNT." (".$c->req->path."):");
                    for my $key (sort { ($res->{$b} <=> $res->{$a}) } keys %{$res}) {
                        $c->log->info(sprintf("+%-10i %30s  -  total %10i\n", $res->{$key}, $key, $c->config->{'arena'}->{$key}));
                    }
                }
            }
            for my $key (keys %{$refs}) {
                if(!$c->config->{'arena'}->{$key} || $c->config->{'arena'}->{$key} < $refs->{$key}) {
                    $c->config->{'arena'}->{$key} = $refs->{$key};
                }
            }
        };
        print STDERR $@ if $@ && $c->config->{'thruk_debug'};
    }

    # figure out intelligent titles
    # only if use_dynamic_titles is true
    # we haven't found a bookmark title
    # and a custom title wasn't set
    if(!Thruk::Utils::Status::set_custom_title($c) && $c->stash->{'use_dynamic_titles'} && $c->stash->{page}) {
        # titles for status.cgi
        if($c->stash->{page} eq 'status') {
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

    if(defined $c->config->{'cgi_cfg'}->{'refresh_rate'} && (!defined $c->stash->{'no_auto_reload'} || $c->stash->{'no_auto_reload'} == 0)) {
        $c->stash->{'refresh_rate'} = $c->config->{'cgi_cfg'}->{'refresh_rate'};
    }
    $c->stash->{'refresh_rate'} = $c->req->parameters->{'refresh'} if(defined $c->req->parameters->{'refresh'} and $c->req->parameters->{'refresh'} =~ m/^\d+$/mx);
    if(defined $c->stash->{'refresh_rate'} and $c->stash->{'refresh_rate'} == 0) {
        $c->stash->{'no_auto_reload'} = 1;
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
    my ($c, $safe, $no_config_adjustments) = @_;
    $safe = Thruk::ADD_DEFAULTS unless defined $safe;

    confess("no c?") unless defined $c;
    $c->stats->profile(begin => "AddDefaults::add_defaults");

    $c->stash->{'defaults_added'} = 1;

    ###############################
    # timezone settings
    my $user_tz = $c->stash->{user_data}->{'tz'} || $c->config->{'default_user_timezone'} || "Server Setting";
    my $timezone;
    if($user_tz ne 'Server Setting') {
        if($user_tz eq 'Local Browser') {
            $timezone = $c->req->cookies->{'thruk_tz'};
        } else {
            $timezone = $user_tz;
        }
        if($timezone =~ m/^UTC(.+)$/mx) {
            my $offset = $1*3600;
            for my $tz (@{Thruk::Utils::get_timezone_data($c)}) {
                if($tz->{'offset'} == $offset) {
                    $timezone = $tz->{'text'};
                    last;
                }
            }
        }
    }
    ## no critic
    if($timezone) {
        # set users timezone
        $ENV{'TZ'} = $timezone;
        POSIX::tzset();
    } else {
        # set back to server timezone
        $c->app->set_timezone();
    }
    ## use critic
    $c->stash->{'user_tz'} = $user_tz;

    ###############################
    $c->stash->{'escape_html_tags'}      = exists $c->config->{'cgi_cfg'}->{'escape_html_tags'}  ? $c->config->{'cgi_cfg'}->{'escape_html_tags'}  : 1;
    $c->stash->{'show_context_help'}     = exists $c->config->{'cgi_cfg'}->{'show_context_help'} ? $c->config->{'cgi_cfg'}->{'show_context_help'} : 0;
    $c->stash->{'info_popup_event_type'} = $c->config->{'info_popup_event_type'} || 'onmouseover';

    ###############################
    $c->stash->{'enable_shinken_features'} = $c->config->{'enable_shinken_features'} || 0;
    $c->stash->{'enable_icinga_features'}  = $c->config->{'enable_icinga_features'}  || 0;

    ###############################
    # redirect to error page unless we have a connection
    if(    !$c->{'db'}
        || !defined $c->{'db'}->{'backends'}
        || ref $c->{'db'}->{'backends'} ne 'ARRAY'
        || scalar @{$c->{'db'}->{'backends'}} == 0 ) {

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
            Thruk::Utils::set_message( $c, 'fail_message fixed', 'Please setup backend(s) connections first.');
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/conf.cgi?sub=backends");
        } else {
            return $c->detach("/error/index/14");
        }
    }

    ###############################
    # no backend?
    return unless $c->{'db'};

    # set check_local_states
    unless(defined $c->config->{'check_local_states'}) {
        $c->config->{'check_local_states'} = 0;
        if(scalar @{$c->{'db'}->{'backends'}} > 1) {
            $c->config->{'check_local_states'} = 1;
        }
    }

    ###############################
    # read cached data
    my $cached_user_data = {};
    if(defined $c->stash->{'remote_user'} and $c->stash->{'remote_user'} ne '?') {
        $cached_user_data = $c->cache->get->{'users'}->{$c->stash->{'remote_user'}};
    }
    my $cached_data = $c->cache->get->{'global'} || {};

    ###############################
    my($disabled_backends,$has_groups) = _set_enabled_backends($c, undef, $safe, $cached_data);

    ###############################
    # add program status
    # this is also the first query on every page, so do the
    # backend availability checks here
    $c->stats->profile(begin => "AddDefaults::get_proc_info");
    my $last_program_restart = 0;
    my $retrys = 1;
    # try 3 times if all cores are local
    $retrys = 3 if scalar keys %{$c->{'db'}->{'state_hosts'}} == 0;
    $retrys = 1 if $safe; # but only once on safe/cached pages

    for my $x (1..$retrys) {
        # reset failed states, otherwise retry would be useless
        $c->{'db'}->reset_failed_backends($c);

        eval {
            $last_program_restart = set_processinfo($c, $cached_user_data, $safe, $cached_data);
        };
        last unless $@;
        $c->log->debug("retry $x, data source error: $@") if Thruk->debug;
        last if $x == $retrys;
        sleep 1;
    }
    if($@) {
        # side.html and some other pages should not be redirect to the error page on backend errors
        _set_possible_backends($c, $disabled_backends);
        print STDERR $@ if $c->config->{'thruk_debug'};
        return 1 if $safe == Thruk::ADD_SAFE_DEFAULTS;
        $c->log->debug("data source error: $@");
        return $c->detach('/error/index/9');
    }
    $c->stash->{'last_program_restart'} = $last_program_restart;

    ###############################
    # read cached data again, groups could have changed
    $cached_user_data = $c->cache->get->{'users'}->{$c->stash->{'remote_user'}} if defined $c->stash->{'remote_user'};

    ###############################
    # disable backends by groups
    if(!defined $ENV{'THRUK_BACKENDS'} && $has_groups && defined $c->{'db'}) {
        $disabled_backends = _disable_backends_by_group($c, $disabled_backends, $cached_user_data);
    }
    _set_possible_backends($c, $disabled_backends);

    $c->stats->profile(end => "AddDefaults::get_proc_info");

    ###############################
    # set some more roles
    Thruk::Utils::set_dynamic_roles($c);

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

    ###############################
    # expire acks?
    $c->stash->{'has_expire_acks'} = 0;
    $c->stash->{'has_expire_acks'} = 1 if $c->stash->{'enable_icinga_features'}
                                       or $c->stash->{'enable_shinken_features'};

    $c->stash->{'navigation'} = "";
    if( $c->config->{'use_frames'} == 0 ) {
        Thruk::Utils::Menu::read_navigation($c);
    }

    # config edit buttons?
    $c->stash->{'show_config_edit_buttons'} = 0;
    if($c->config->{'use_feature_configtool'} && $c->check_user_roles("admin")) {
        # get backends with object config
        for my $peer (@{$c->{'db'}->get_peers(1)}) {
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
        if(defined $c->config->{'cgi_cfg'}->{$key."_sound"}) {
            $c->stash->{'has_cgi_sounds'} = 1;
            last;
        }
    }

    ###############################
    $c->stash->{'require_comments_for_disable_cmds'} = $c->config->{'require_comments_for_disable_cmds'} || 0;

    ###############################
    # user / group specific config?
    $c->stash->{'contactgroups'} = $c->stash->{'remote_user'} ? [sort keys %{$c->cache->get->{'users'}->{$c->stash->{'remote_user'}}->{'contactgroups'}}] : [];
    if(!$no_config_adjustments && $c->stash->{'remote_user'}) {
        $c->stash->{'config_adjustments'} = {};
        for my $group (@{$c->stash->{'contactgroups'}}) {
            if(defined $c->config->{'Group'}->{$group}) {
                # move components one level up
                if($c->config->{'Group'}->{$group}->{'Component'}) {
                    for my $key (keys %{$c->config->{'Group'}->{$group}->{'Component'}}) {
                        if($key eq 'Thruk::Backend' and defined $c->config->{'Group'}->{$group}->{'Component'}->{$key}->{'peer'}) {
                            my $peers = $c->config->{'Group'}->{$group}->{'Component'}->{$key}->{'peer'};
                            $peers = ref $peers eq 'HASH' ? [$peers] : $peers;
                            push @{$c->stash->{'config_adjustments'}->{'extra_backends'}}, @{$peers};
                        }
                        $c->config->{'Group'}->{$group}->{$key} = $c->config->{'Group'}->{$group}->{'Component'}->{$key};
                    }
                }
                for my $key (keys %{$c->config->{'Group'}->{$group}}) {
                    $c->stash->{'config_adjustments'}->{$key} = $c->config->{$key} unless defined $c->stash->{'config_adjustments'}->{$key};
                    $c->config->{$key} = $c->config->{'Group'}->{$group}->{$key};
                }
            }
        }
        if(defined $c->config->{'User'}->{$c->stash->{'remote_user'}}) {
            if($c->config->{'User'}->{$c->stash->{'remote_user'}}->{'Component'}) {
                for my $key (keys %{$c->config->{'User'}->{$c->stash->{'remote_user'}}->{'Component'}}) {
                    if($key eq 'Thruk::Backend' and defined $c->config->{'User'}->{$c->stash->{'remote_user'}}->{'Component'}->{$key}->{'peer'}) {
                        my $peers = $c->config->{'User'}->{$c->stash->{'remote_user'}}->{'Component'}->{$key}->{'peer'};
                        $peers = ref $peers eq 'HASH' ? [$peers] : $peers;
                        push @{$c->stash->{'config_adjustments'}->{'extra_backends'}}, @{$peers};
                    }
                    $c->config->{'User'}->{$c->stash->{'remote_user'}}->{$key} = $c->config->{'User'}->{$c->stash->{'remote_user'}}->{'Component'}->{$key};
                }
            }
            for my $key (keys %{$c->config->{'User'}->{$c->stash->{'remote_user'}}}) {
                $c->stash->{'config_adjustments'}->{$key} = $c->config->{$key} unless defined $c->stash->{'config_adjustments'}->{$key};
                $c->config->{$key} = $c->config->{'User'}->{$c->stash->{'remote_user'}}->{$key};
            }
        }

        # reapply config defaults and config conversions
        if(scalar keys %{$c->stash->{'config_adjustments'}} > 0) {
            Thruk::Config::set_default_config($c->config);
            set_configs_stash($c);
            if($c->stash->{'config_adjustments'}->{'extra_backends'}) {
                $c->stash->{'config_adjustments_extra'} = {
                    peer_order  => $Thruk::Backend::Pool::peer_order,
                    peers       => $Thruk::Backend::Pool::peers,
                    pool        => $Thruk::Backend::Pool::pool,
                    pool_size   => $Thruk::Backend::Pool::pool_size,
                    xs          => $Thruk::Backend::Pool::xs,
                };
                Thruk::Backend::Pool::init_backend_thread_pool($c->stash->{'config_adjustments'}->{'extra_backends'});
                $c->{'db'} = Thruk::Backend::Manager->new();
                $c->{'db'}->init();
            }
            add_defaults($c, $safe, 1);
        }
    }

    ###############################
    $c->stats->profile(end => "AddDefaults::add_defaults");
    return 1;
}

########################################

=head2 add_safe_defaults

    same like add_defaults() but does not redirect to error page on backend errors

=cut

sub add_safe_defaults {
    my ($c) = @_;
    eval {
        add_defaults($c, Thruk::ADD_SAFE_DEFAULTS);
    };
    print STDERR $@ if($@ and $c->config->{'thruk_debug'});
    return;
}

########################################

=head2 add_cached_defaults

    same like AddDefaults but trys to use cached things

=cut

sub add_cached_defaults {
    my ($c) = @_;
    add_defaults($c, Thruk::ADD_CACHED_DEFAULTS);
    # make sure process info is not getting too old
    if(!$c->stash->{'processinfo_time'} || $c->stash->{'processinfo_time'} < time() - 90) {
        Thruk::Action::AddDefaults::delayed_proc_info_update($c);
    }
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

=head2 _set_possible_backends

  _set_possible_backends($c, $disabled_backends)

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
sub _set_possible_backends {
    my ($c,$disabled_backends) = @_;

    my @possible_backends;
    for my $b (@{$c->{'db'}->get_peers($c->stash->{'config_backends_only'} || 0)}) {
        push @possible_backends, $b->{'key'};
    }

    my %backend_detail;
    my @new_possible_backends;

    for my $back (@possible_backends) {
        if(defined $disabled_backends->{$back} && $disabled_backends->{$back} == DISABLED_AUTH) {
            $c->{'db'}->disable_backend($back);
            next;
        }
        my $peer = $c->{'db'}->get_peer_by_key($back);
        if($peer->{disabled} && $peer->{disabled} == HIDDEN_LMD_PARENT) {
            $c->{'db'}->disable_backend($back);
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
    my($c) = @_;

    my $initial_backends = {};
    my $backends         = $c->stash->{'backends'};
    my $backend_detail   = $c->stash->{'backend_detail'};

    return unless $backends;
    return if scalar @{$backends} == 0;

    # create flat list of backend hashes used in javascript
    for my $back (@{$backends}) {
        my $peer = $c->{'db'}->get_peer_by_key($back);
        $initial_backends->{$back} = {
            key              => $back,
            name             => $peer->{'name'} || 'unknown',
            state            => $backend_detail->{$back}->{'state'},
            version          => '',
            data_src_version => '',
            program_start    => '',
        };
        if($peer->{'last_online'}) {
            $initial_backends->{$back}->{'last_online'} = time() - $peer->{'last_online'};
        }
        if(ref $c->stash->{'pi_detail'} eq 'HASH' and defined $c->stash->{'pi_detail'}->{$back}) {
            $initial_backends->{$back}->{'version'}          = $c->stash->{'pi_detail'}->{$back}->{'program_version'};
            $initial_backends->{$back}->{'data_src_version'} = $c->stash->{'pi_detail'}->{$back}->{'data_source_version'};
            $initial_backends->{$back}->{'program_start'}    = $c->stash->{'pi_detail'}->{$back}->{'program_start'};
        }
    }

    # create sections and subsection for site panel
    _calculate_section_totals($c, $c->{'db'}->{'sections'}, $backend_detail, $initial_backends);

    my $show_sitepanel = 'list';
       if($c->stash->{'sitepanel'} eq 'list')      { $show_sitepanel = 'list'; }
    elsif($c->stash->{'sitepanel'} eq 'compact')   { $show_sitepanel = 'panel'; }
    elsif($c->stash->{'sitepanel'} eq 'collapsed') { $show_sitepanel = 'collapsed'; }
    elsif($c->stash->{'sitepanel'} eq 'off')       { $show_sitepanel = 'off'; }
    elsif($c->stash->{'sitepanel'} eq 'auto') {
        if($c->{'db'}->{'sections_depth'} > 1 || scalar @{$backends} >= 50) { $show_sitepanel = 'collapsed'; }
        elsif($c->{'db'}->{'sections'}->{'sub'} || scalar @{$backends} >= 10) { $show_sitepanel = 'panel'; }
        elsif(scalar @{$backends} == 1) { $show_sitepanel = 'off'; }
        else { $show_sitepanel = 'list'; }
    }

    $c->stash->{'initial_backends'} = $initial_backends;
    $c->stash->{'show_sitepanel'}   = $show_sitepanel;
    $c->stash->{'sites'}            = $c->{'db'}->{'sections'};

    # merge all panel in a Default section
    if($c->stash->{'show_sitepanel'} eq 'panel') {
        my $sites = $c->stash->{'sites'};
        if(!$sites->{'sub'} || !$sites->{'sub'}->{'Default'}) {
            $sites->{'sub'}->{'Default'} = { peers => delete $sites->{'peers'} || [] };
        }
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
        for my $s (values %{$section->{'sub'}}) {
            _calculate_section_totals($c, $s, $backend_detail, $initial_backends);
            for my $key (qw/up disabled down total/) {
                $section->{$key} += $s->{$key};
            }
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
            $class = 'HID'  if $c->stash->{'param_backend'} && !(grep {/\Q$pd\E/mx} @{Thruk::Utils::list($c->stash->{'param_backend'})});
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
sub _disable_backends_by_group {
    my ($c,$disabled_backends, $cached_user_data) = @_;

    my $contactgroups = $cached_user_data->{'contactgroups'};
    for my $peer (@{$c->{'db'}->get_peers()}) {
        if(defined $peer->{'groups'}) {
            for my $group (split/\s*,\s*/mx, $peer->{'groups'}) {
                if(defined $contactgroups->{$group}) {
                    $c->log->debug("found contact ".$c->user->get('username')." in contactgroup ".$group);
                    # delete old completly hidden state
                    delete $disabled_backends->{$peer->{'key'}};
                    # but disabled by cookie?
                    if(defined $c->cookie('thruk_backends')) {
                        for my $val (@{$c->cookies('thruk_backends')->{'value'}}) {
                            my($key, $value) = split/=/mx, $val;
                            if(defined $value and $key eq $peer->{'key'}) {
                                $disabled_backends->{$key} = $value;
                            }
                        }
                    }
                    last;
                }
            }
        }
    }

    return $disabled_backends;
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

  set_processinfo($c, [$cached_user_data, $safe, $cached_data,$skip_cache_update])

set process info into stash

=cut
sub set_processinfo {
    my($c, $cached_user_data, $safe, $cached_data, $skip_cache_update) = @_;
    my $last_program_restart = 0;
    $safe = Thruk::ADD_DEFAULTS unless defined $safe;

    $c->stats->profile(begin => "AddDefaults::set_processinfo");

    # cached process info?
    my $processinfo;
    $cached_data->{'processinfo'} = {} unless defined $cached_data->{'processinfo'};
    my $fetch = 0;
    my($selected) = $c->{'db'}->select_backends('get_status');
    if($safe) { # cached or safe
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
    $fetch = 1 if $ENV{'THRUK_USE_LMD'} && $safe == Thruk::ADD_CACHED_DEFAULTS;
    $c->stash->{'processinfo_time'} = $cached_data->{'processinfo_time'} if $cached_data->{'processinfo_time'};

    if($fetch) {
        $c->stats->profile(begin => "AddDefaults::set_processinfo fetch");
        $processinfo = $c->{'db'}->get_processinfo();
        if(ref $processinfo eq 'HASH') {
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
    $c->stash->{'real_pi_detail'} = $cached_data->{'real_processinfo'} || {};
    $c->stash->{'has_proc_info'} = 1;

    # set last programm restart
    if(ref $processinfo eq 'HASH') {
        for my $backend (keys %{$processinfo}) {
            next if !defined $processinfo->{$backend}->{'program_start'};
            $last_program_restart = $processinfo->{$backend}->{'program_start'} if $last_program_restart < $processinfo->{$backend}->{'program_start'};
            $c->{'db'}->{'last_program_starts'}->{$backend} = $processinfo->{$backend}->{'program_start'};
        }
    }

    # check if we have to build / clean our per user cache
    if(   !defined $cached_user_data
       || !defined $cached_user_data->{'prev_last_program_restart'}
       || $cached_user_data->{'prev_last_program_restart'} < $last_program_restart
       || $cached_user_data->{'prev_last_program_restart'} < time() - 600 # update at least every 10 minutes
       || ($ENV{THRUK_SRC} && $ENV{THRUK_SRC} eq 'CLI')
      ) {
        if(defined $c->stash->{'remote_user'} && !$skip_cache_update) {
            my $contactgroups = $c->{'db'}->get_contactgroups_by_contact($c, $c->stash->{'remote_user'}, 1);

            $cached_user_data = {
                'prev_last_program_restart' => time(),
                'contactgroups'             => $contactgroups,
            };
            $c->stash->{'contactgroups'} = [sort keys %{$contactgroups}];
            $c->cache->set('users', $c->stash->{'remote_user'}, $cached_user_data);
            $c->log->debug("creating new user cache for ".$c->stash->{'remote_user'});
        }
    }

    # check our backends uptime
    if(defined $c->config->{'delay_pages_after_backend_reload'} and $c->config->{'delay_pages_after_backend_reload'} > 0) {
        my $delay_pages_after_backend_reload = $c->config->{'delay_pages_after_backend_reload'} || 0;
        for my $backend (keys %{$processinfo}) {
            next unless($processinfo->{$backend} and $processinfo->{$backend}->{'program_start'});
            my $delay = int($processinfo->{$backend}->{'program_start'} + $delay_pages_after_backend_reload - time());
            if($delay > 0) {
                $c->log->debug("delaying page delivery by $delay seconds...");
                sleep($delay);
            }
        }
    }

    $c->stats->profile(end => "AddDefaults::set_processinfo");

    return($last_program_restart);
}

########################################
sub _set_enabled_backends {
    my($c, $backends, $safe, $cached_data) = @_;

    # first all backends are enabled
    if(defined $c->{'db'}) {
        $c->{'db'}->enable_backends();
    }

    if($c->req->parameters->{'backend'} && $c->req->parameters->{'backends'}) {
        confess("'backend' and 'backends' parameter set!");
    }
    my $backend  = $c->req->parameters->{'backend'} || $c->req->parameters->{'backends'};
    $c->stash->{'param_backend'} = $backend || '';
    my $disabled_backends = {};
    my $num_backends      = @{$c->{'db'}->get_peers()};

    ###############################
    # by args
    if(defined $backends) {
        $c->log->debug('_set_enabled_backends() by args') if Thruk->debug;
        # reset
        for my $peer (@{$c->{'db'}->get_peers()}) {
            $disabled_backends->{$peer->{'key'}} = HIDDEN_USER; # set all hidden
        }
        if(ref $backends eq '') {
            my @tmp = split(/\s*,\s*/mx, $backends);
            $backends = \@tmp;
        }
        for my $b (@{$backends}) {
            # peer key can be name too
            if($b eq 'ALL') {
                for my $peer (@{$c->{'db'}->get_peers()}) {
                    $disabled_backends->{$peer->{'key'}} = 0;
                }
            } else {
                my $peer = $c->{'db'}->get_peer_by_key($b);
                if($peer) {
                    $disabled_backends->{$peer->{'key'}} = 0;
                } else {
                    # silently ignore, this can happen if backends have changed but are saved in dashboards or reports
                    #die("got no peer for: ".$b)
                }
            }
        }
    }
    ###############################
    # by env
    elsif(defined $ENV{'THRUK_BACKENDS'}) {
        $c->log->debug('_set_enabled_backends() by env: '.Dumper($ENV{'THRUK_BACKENDS'})) if Thruk->debug;
        # reset
        for my $peer (@{$c->{'db'}->get_peers()}) {
            $disabled_backends->{$peer->{'key'}} = HIDDEN_USER; # set all hidden
        }
        for my $b (split(/;/mx, $ENV{'THRUK_BACKENDS'})) {
            # peer key can be name too
            if($b eq 'ALL') {
                for my $peer (@{$c->{'db'}->get_peers()}) {
                    $disabled_backends->{$peer->{'key'}} = 0;
                }
            } else {
                my $peer = $c->{'db'}->get_peer_by_key($b);
                die("got no peer for: ".$b) unless defined $peer;
                $disabled_backends->{$peer->{'key'}} = 0;
            }
        }
    }

    ###############################
    # by param
    elsif($num_backends > 1 and defined $backend) {
        $c->log->debug('_set_enabled_backends() by param') if Thruk->debug;
        # reset
        for my $peer (@{$c->{'db'}->get_peers()}) {
            $disabled_backends->{$peer->{'key'}} = HIDDEN_USER;  # set all hidden
        }
        for my $b (ref $backend eq 'ARRAY' ? @{$backend} : split/,/mx, $backend) {
            $disabled_backends->{$b} = 0;
        }
    }

    ###############################
    # by cookie
    elsif($num_backends > 1 and defined $c->cookie('thruk_backends')) {
        $c->log->debug('_set_enabled_backends() by cookie') if Thruk->debug;
        for my $val (@{$c->cookies('thruk_backends')->{'value'}}) {
            my($key, $value) = split/=/mx, $val;
            next unless defined $value;
            $disabled_backends->{$key} = $value;
        }
    }
    elsif(defined $c->{'db'}) {
        $c->log->debug('_set_enabled_backends() using defaults') if Thruk->debug;
        my $display_too = 0;
        if(defined $c->req->header('user-agent') and $c->req->header('user-agent') !~ m/thruk/mxi) {
            $display_too = 1;
        }
        $disabled_backends = $c->{'db'}->disable_hidden_backends($disabled_backends, $display_too);
    }

    ###############################
    # groups affected?
    my $has_groups = 0;
    if(defined $c->{'db'}) {
        for my $peer (@{$c->{'db'}->get_peers()}) {
            if(defined $peer->{'groups'}) {
                $has_groups = 1;
                $disabled_backends->{$peer->{'key'}} = DISABLED_AUTH;  # completly hidden
            }
        }
        $c->{'db'}->disable_backends($disabled_backends);
    }
    $c->log->debug("backend groups filter enabled") if $has_groups;

    # renew state of connections
    if($num_backends > 1 && $c->config->{'check_local_states'} && !$ENV{'THRUK_USE_LMD'}) {
        $disabled_backends = $c->{'db'}->set_backend_state_from_local_connections($disabled_backends, $safe, $cached_data);
    }

    # when set by args, update
    if(defined $backends) {
        _set_possible_backends($c, $disabled_backends);
    }
    $c->log->debug('disabled_backends: '.Dumper($disabled_backends)) if Thruk->debug;
    return($disabled_backends, $has_groups);
}

########################################

=head2 die_when_no_backends

    die unless there are any backeds defined and enabled

=cut
sub die_when_no_backends {
    my($c) = @_;
    if(!defined $c->stash->{'pi_detail'} && _any_backend_enabled($c)) {
        $c->log->error("got no result from any backend, please check backend connection and logfiles");
        return $c->detach('/error/index/9');
    }
    return;
}

########################################

=head2 delayed_proc_info_update

    run process info update after the main page has been served

=cut
sub delayed_proc_info_update {
    my($c) = @_;
    my $disabled_backends = $c->{'db'}->disable_hidden_backends();
    _set_possible_backends($c, $disabled_backends);
    my $cached_data = $c->cache->get->{'global'} || {};
    set_processinfo($c, undef, undef, $cached_data, 1);
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
    print $fh Thruk::Config::get_debug_details();
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
    Thruk::Utils::set_message( $c, 'success_message fixed', 'Debug Information written to: '.$tmpfile );
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
        $all_sites_info = $c->{'db'}->get_sites(backend => ["ALL"]);
    };
    if($@) {
        # may fail for older lmd releases which don't have parent or section information
        if($@ =~ m/\Qbad request: table sites has no column\E/mx) {
            $c->log->info("cannot check lmd federation mode, please update LMD.");
            ## no critic
            $ENV{'THRUK_USE_LMD_FEDERATION_FAILED'} = 1;
            ## use critic
        }
    }
    return($processinfo, $cached_data) unless $all_sites_info;

    # add sub federated backends
    my $existing =  {};
    my $changed  = 0;
    for my $row (@{$all_sites_info}) {
        my $key = $row->{'key'};
        $existing->{$key} = 1;
        if(!$Thruk::Backend::Pool::peers->{$key}) {
            my $parent = $Thruk::Backend::Pool::peers->{$row->{'parent'}};
            next unless $parent;
            my $peer = Thruk::Backend::Peer->new({
                name => $row->{'name'},
                id   => $key,
                type => "livestatus",
                section => $row->{'section'} ? $parent->peer_name().'/'.$row->{'section'} : $parent->peer_name(),
                options => {
                    peer => $row->{'addr'},
                },
            }, $c->config, {});
            $peer->{'lmd_fake_backend'} = 1;
            $Thruk::Backend::Pool::peers->{$peer->{'key'}} = $peer;
            push @{$Thruk::Backend::Pool::peer_order}, $peer->{'key'};
            $parent->{'disabled'} = HIDDEN_LMD_PARENT;
            $changed++;
        }
    }
    # remove exceeding backends
    my $new_order = [];
    for my $key (@{$Thruk::Backend::Pool::peer_order}) {
        my $peer = $Thruk::Backend::Pool::peers->{$key};
        if(!$peer->{'lmd_fake_backend'}) {
            push @{$new_order}, $key;
            next;
        }
        if(!$existing->{$key}) {
            delete $cached_data->{'processinfo'}->{$key};
            delete $Thruk::Backend::Pool::peers->{$key};
            $changed++;
            next;
        }
        push @{$new_order}, $key;
    }
    if($changed) {
        $Thruk::Backend::Pool::peer_order = $new_order;
        $c->db->{'initialized'} = 0;
        $c->db->init();
        # fetch missing processinfo
        $processinfo = $c->{'db'}->get_processinfo();
        for my $key (keys %{$processinfo}) {
            $cached_data->{'processinfo'}->{$key} = $processinfo->{$key};
        }
    }
    # set a few extra infos
    for my $d (@{$all_sites_info}) {
        my $key = $d->{'key'};
        my $peer = $Thruk::Backend::Pool::peers->{$key};
        next unless $peer;
        for my $col (qw/last_online last_update last_error/) {
            $peer->{$col} = $d->{$col};
        }
    }
    return($processinfo, $cached_data);
}

########################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
