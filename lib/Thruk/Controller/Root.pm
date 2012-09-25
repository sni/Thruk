package Thruk::Controller::Root;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';
use Data::Dumper;
use URI::Escape;
use File::Slurp;
use JSON::XS;

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

Thruk::Controller::Root - Root Controller for Thruk

=head1 DESCRIPTION

Root Controller of the Thruk Monitoring Webinterface

=head1 METHODS

=cut

######################################

=head2 begin

sets the doc link and decides if frames are used
begin, running at the begin of every req

=cut

sub begin : Private {
    my( $self, $c ) = @_;

    # defaults
    $c->config->{'url_prefix'} = exists $c->config->{'url_prefix'} ? $c->config->{'url_prefix'} : '/';
    my $defaults = {
        backend_debug                   => 0,
        use_ajax_search                 => 1,
        ajax_search_hosts               => 1,
        ajax_search_hostgroups          => 1,
        ajax_search_services            => 1,
        ajax_search_servicegroups       => 1,
        ajax_search_timeperiods         => 1,
        shown_inline_pnp                => 1,
        use_feature_trends              => 1,
        use_wait_feature                => 1,
        wait_timeout                    => 10,
        use_frames                      => 1,
        use_strict_host_authorization   => 0,
        make_auth_user_lowercase        => 0,
        make_auth_user_uppercase        => 0,
        can_submit_commands             => 1,
        group_paging_overview           => '*3, 10, 100, all',
        group_paging_grid               => '*5, 10, 50, all',
        group_paging_summary            => '*10, 50, 100, all',
        default_theme                   => 'Thruk',
        datetime_format                 => '%Y-%m-%d  %H:%M:%S',
        datetime_format_long            => '%a %b %e %H:%M:%S %Z %Y',
        datetime_format_today           => '%H:%M:%S',
        datetime_format_log             => '%B %d, %Y  %H',
        datetime_format_trends          => '%a %b %e %H:%M:%S %Y',
        title_prefix                    => '',
        use_pager                       => 1,
        start_page                      => $c->config->{'url_prefix'}.'thruk/main.html',
        documentation_link              => $c->config->{'url_prefix'}.'thruk/docs/index.html',
        show_notification_number        => 1,
        strict_passive_mode             => 1,
        show_full_commandline           => 1,
        show_modified_attributes        => 1,
        show_config_edit_buttons        => 0,
        show_backends_in_table          => 0,
        backends_with_obj_config        => {},
        use_feature_statusmap           => 0,
        use_feature_statuswrl           => 0,
        use_feature_histogram           => 0,
        use_feature_configtool          => 0,
        use_new_search                  => 1,
        use_new_command_box             => 1,
        all_problems_link               => $c->config->{'url_prefix'}."thruk/cgi-bin/status.cgi?style=combined&amp;hst_s0_hoststatustypes=4&amp;hst_s0_servicestatustypes=31&amp;hst_s0_hostprops=10&amp;hst_s0_serviceprops=0&amp;svc_s0_hoststatustypes=3&amp;svc_s0_servicestatustypes=28&amp;svc_s0_hostprops=10&amp;svc_s0_serviceprops=10&amp;svc_s0_hostprop=2&amp;svc_s0_hostprop=8&amp;title=All+Unhandled+Problems",
        statusmap_default_groupby       => 'address',
        statusmap_default_type          => 'table',
        show_long_plugin_output         => 'popup',
        info_popup_event_type           => 'onclick',
        info_popup_options              => 'STICKY,CLOSECLICK,HAUTO,MOUSEOFF',
        cmd_quick_status                => {
                    reschedule             => 1,
                    downtime               => 1,
                    comment                => 1,
                    acknowledgement        => 1,
                    active_checks          => 1,
                    notifications          => 1,
                    submit_result          => 1,
                    reset_attributes       => 1,
        },
        cmd_defaults                    => {
                    ahas                   => 0,
                    broadcast_notification => 0,
                    force_check            => 0,
                    force_notification     => 0,
                    send_notification      => 1,
                    sticky_ack             => 1,
                    persistent_comments    => 1,
                    persistent_ack         => 0,
                    ptc                    => 0,
                    use_expire             => 0,
        },
        command_disabled                    => {},
        downtime_duration                   => 7200,
        expire_ack_duration                 => 86400,
        show_custom_vars                    => [],
        themes_path                         => './themes',
        priorities                      => {
                    5                       => 'Business Critical',
                    4                       => 'Top Production',
                    3                       => 'Production',
                    2                       => 'Standard',
                    1                       => 'Testing',
                    0                       => 'Development',
        },
        no_external_job_forks               => 0,
        host_action_icon                    => 'action.gif',
        service_action_icon                 => 'action.gif',
        cookie_path                         => $c->config->{'url_prefix'}.'thruk',
        thruk_bin                           => '/usr/bin/thruk',
        thruk_init                          => '/etc/init.d/thruk',
        thruk_shell                         => '/bin/bash -l -c',
        report_nice_level                   => 5,
        weekdays                        => {
                    '0'                     => 'Sunday',
                    '1'                     => 'Monday',
                    '2'                     => 'Tuesday',
                    '3'                     => 'Wednesday',
                    '4'                     => 'Thursday',
                    '5'                     => 'Friday',
                    '6'                     => 'Saterday',
                    '7'                     => 'Sunday',
                                           },
        'mobile_agent'                  => 'iPhone,Android,IEMobile',
        'show_error_reports'            => 1,
        'skip_js_errors'                => [ 'cluetip is not a function' ],
    };
    $defaults->{'thruk_bin'} = 'script/thruk' if -f 'script/thruk';
    for my $key (keys %{$defaults}) {
        $c->config->{$key} = exists $c->config->{$key} ? $c->config->{$key} : $defaults->{$key};
    }

    # make a nice path
    for my $key (qw/tmp_path var_path/) {
        $c->config->{$key} =~ s/\/$//mx;
    }

    for my $key (qw/cmd_quick_status cmd_defaults/) {
        for my $key2 ( %{$defaults->{$key}} ) {
            $c->config->{$key}->{$key2} = $defaults->{$key}->{$key2} unless defined $c->config->{$key}->{$key2};
        }
    }

    # make some configs available in stash
    for my $key (qw/url_prefix title_prefix use_pager start_page documentation_link
                  use_feature_statusmap use_feature_statuswrl use_feature_histogram use_feature_configtool
                  datetime_format datetime_format_today datetime_format_long datetime_format_log
                  use_new_search ajax_search show_notification_number strict_passive_mode
                  show_full_commandline all_problems_link use_ajax_search show_long_plugin_output
                  priorities show_modified_attributes downtime_duration expire_ack_duration
                  show_backends_in_table host_action_icon service_action_icon cookie_path
                  use_feature_trends show_error_reports skip_js_errors
                /) {
        $c->stash->{$key} = $c->config->{$key};
    }

    # command disabled should be a hash
    if(ref $c->config->{'command_disabled'} ne 'HASH') {
        $c->config->{'command_disabled'} = Thruk::Utils::array2hash(Thruk::Utils::expand_numeric_list($c, $c->config->{'command_disabled'}));
    }

    # external jobs can be disabled by env
    if(defined $ENV{'NO_EXTERNAL_JOBS'}) {
        $c->config->{'no_external_job_forks'} = 1;
    }

    # username?
    if($c->user_exists) {
        $c->stash->{'remote_user'}  = $c->user->get('username');
    }
    $c->stash->{'user_data'} = { bookmarks => {} };

    # frame options
    my $use_frames = $c->config->{'use_frames'};
    my $show_nav_button = 1;
    if( exists $c->{'request'}->{'parameters'}->{'nav'} and $c->{'request'}->{'parameters'}->{'nav'} ne '' ) {
        if( $c->{'request'}->{'parameters'}->{'nav'} ne '1' ) {
            $show_nav_button = 1;
        }
        $use_frames = 1;
        if( $c->{'request'}->{'parameters'}->{'nav'} eq '1' ) {
            $use_frames = 0;
        }
    }
    if( $c->config->{'use_frames'} == 1 ) {
        $show_nav_button = 0;
    }
    $c->stash->{'use_frames'}         = $use_frames;
    $c->stash->{'show_nav_button'}    = $show_nav_button;
    $c->stash->{'reload_nav'}         = $c->{'request'}->{'parameters'}->{'reload_nav'} || '';
    $c->stash->{'show_sounds'}        = 0;

    # use pager?
    Thruk::Utils::set_paging_steps($c, $c->config->{'paging_steps'});

    # which theme?
    my($param_theme, $cookie_theme);
    if( $c->{'request'}->{'parameters'}->{'theme'} ) {
        $param_theme = $c->{'request'}->{'parameters'}->{'theme'};
    }
    elsif( defined $c->request->cookie('thruk_theme') ) {
        my $theme_cookie = $c->request->cookie('thruk_theme');
        $cookie_theme = $theme_cookie->value if defined $theme_cookie->value and grep $theme_cookie->value, $c->config->{'themes'};
    }
    my $theme = $param_theme || $cookie_theme || $c->config->{'default_theme'};
    my $available_themes = Thruk::Utils::array2hash($c->config->{'View::TT'}->{'PRE_DEFINE'}->{'themes'});
    $theme = $c->config->{'default_theme'} unless defined $available_themes->{$theme};
    $c->stash->{'theme'} = $theme;
    if( defined $c->config->{templates_paths} ) {
        $c->stash->{additional_template_paths} = [ @{ $c->config->{templates_paths} }, $c->config->{themes_path}.'/themes-enabled/'.$theme.'/templates' ];
    }
    else {
        $c->stash->{additional_template_paths} = [ $c->config->{themes_path}.'/themes-enabled/'.$theme.'/templates' ];
    }
    $c->stash->{all_in_one_css} = 1 if $theme eq 'Thruk';

    if(exists $c->{'request'}->{'parameters'}->{'noheader'}) {
        $c->{'request'}->{'parameters'}->{'hidetop'}  = 1;
    }
    $c->stash->{hidetop} = $c->{'request'}->{'parameters'}->{'hidetop'} || '';

    # minmal custom monitor screen
    $c->stash->{minimal}               = $c->{'request'}->{'parameters'}->{'minimal'} || '';
    $c->stash->{show_nav_button}       = 0 if $c->stash->{minimal};
    $c->stash->{hide_backends_chooser} = 1 if $c->stash->{minimal};

    # initialize our backends
    unless ( defined $c->{'db'} ) {
        $c->{'db'} = $c->model('Thruk');
        if( defined $c->{'db'} ) {
            $c->{'db'}->init(
                'stats'               => $c->stats,
                'log'                 => $c->log,
                'config'              => $c->config,
                'backend_debug'       => $c->config->{'backend_debug'},
            );
        }
    }
    # needed for the autoload methods
    $Thruk::Backend::Manager::stats = $c->stats;

    my $target = $c->{'request'}->{'parameters'}->{'target'};
    if( !$c->stash->{'use_frames'} and defined $target and $target eq '_parent' ) {
        $c->stash->{'target'} = '_parent';
    }

    # redirect to error page unless we have a connection
    if(    !defined $c->{'db'}
        or !defined $c->{'db'}->{'backends'}
        or ref $c->{'db'}->{'backends'} ne 'ARRAY'
        or scalar @{$c->{'db'}->{'backends'}} == 0 ) {

        # return here for static content, no backend needed
        if(   $c->request->action =~ m|thruk/\w+\.html|mx
           or $c->request->action =~ m|thruk\\\/\w+\\.html|mx
           or $c->request->action =~ m|thruk\\/cgi\\-bin\\/conf\\.cgi\?sub=backends|mx
           or $c->request->action =~ m|thruk\\/cgi\\-bin\\/remote\\.cgi|mx
           or $c->request->action eq 'thruk$'
           or $c->request->action eq 'thruk\\/docs\\/' ) {
            $c->stash->{'no_auto_reload'} = 1;
            return;
        }
        # redirect to backends manager if admin user
        if( $c->config->{'use_feature_configtool'} ) {
            $c->{'request'}->{'parameters'}->{'sub'} = 'backends';
            return $c->detach('/conf/index');
        } else {
            return $c->detach("/error/index/14");
        }
    }

    # set check_local_states
    unless(defined $c->config->{'check_local_states'}) {
        $c->config->{'check_local_states'} = 0;
        if(scalar @{$c->{'db'}->{'backends'}} > 1) {
            $c->config->{'check_local_states'} = 1;
        }
    }

    # when adding nav=1 to a url in frame mode, redirect to frame.html with this url
    if( defined $c->{'request'}->{'parameters'}->{'nav'}
            and $c->{'request'}->{'parameters'}->{'nav'} eq '1'
            and $c->config->{'use_frames'} == 1 ) {
        my $path = $c->request->uri->path_query;
        $path =~ s/nav=1//gmx;
        return $c->response->redirect($c->stash->{'url_prefix'}."thruk/frame.html?link=".uri_escape($path));
    }

    # icon image path
    $c->config->{'logo_path_prefix'} = exists $c->config->{'logo_path_prefix'} ? $c->config->{'logo_path_prefix'} : $c->stash->{'url_prefix'}.'thruk/themes/'.$c->stash->{'theme'}.'/images/logos/';
    $c->stash->{'logo_path_prefix'}  = $c->config->{'logo_path_prefix'};

    # additional views on status pages
    $c->stash->{'additional_views'} = $Thruk::Utils::Status::additional_views || {};

    # sound cookie set?
    if(defined $c->request->cookie('thruk_sounds')) {
        my $sound_cookie = $c->request->cookie('thruk_sounds');
        if(defined $sound_cookie->value and $sound_cookie->value eq 'off') {
            $c->stash->{'play_sounds'} = 0;
        }
        if(defined $sound_cookie->value and $sound_cookie->value eq 'on') {
            $c->stash->{'play_sounds'} = 1;
        }
    }

    # favicon cookie set?
    if(defined $c->request->cookie('thruk_favicon')) {
        my $favicon_cookie = $c->request->cookie('thruk_favicon');
        if(defined $favicon_cookie->value and $favicon_cookie->value eq 'off') {
            $c->stash->{'fav_counter'} = 0;
        }
        if(defined $favicon_cookie->value and $favicon_cookie->value eq 'on') {
            $c->stash->{'fav_counter'} = 1;
        }
    }

    # menu cookie set?
    my $menu_states = {};
    if( defined $c->request->cookie('thruk_side') ) {
        my $cookie_val = $c->request->cookie('thruk_side')->{'value'};
        if(ref $cookie_val ne 'ARRAY') { $cookie_val = [$cookie_val]; }
        for my $state (@{$cookie_val}) {
            my($k,$v) = split(/=/mx,$state,2);
            $menu_states->{$k} = $v;
        }
    }
    $c->stash->{'menu_states'}      = $menu_states;
    $c->stash->{'menu_states_json'} = encode_json($menu_states);

    # make private _ hash keys available
    $Template::Stash::PRIVATE = undef;

    return 1;
}

######################################

=head2 default

show our 404 error page

=cut

sub default : Path {
    my( $self, $c ) = @_;
    $c->response->body('Page not found');
    return $c->response->status(404);
}

######################################

=head2 index

redirect from /

=cut

sub index : Path('/') {
    my( $self, $c ) = @_;
    if( scalar @{ $c->request->args } > 0 and $c->request->args->[0] ne 'index.html' ) {
        return $c->detach("default");
    }
    return $c->response->redirect($c->stash->{'url_prefix'}."thruk/");
}

######################################

=head2 index_html

redirect from /index.html

beacuse we dont want index.html in the url

=cut

sub index_html : Path('/index.html') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return if Thruk::Utils::choose_mobile($c, $c->stash->{'url_prefix'}."thruk/cgi-bin/mobile.cgi");
    if( $c->stash->{'use_frames'} ) {
        return $c->detach("thruk_index_html");
    }
    else {
        return $c->detach("thruk_main_html");
    }
}

######################################

=head2 thruk_index

redirect from /thruk/
but if used not via fastcgi/apache, there is no way around

=cut

sub thruk_index : Regex('thruk$') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return if Thruk::Utils::choose_mobile($c, $c->stash->{'url_prefix'}."thruk/cgi-bin/mobile.cgi");
    if( scalar @{ $c->request->args } > 0 and $c->request->args->[0] ne 'index.html' ) {
        return $c->detach("default");
    }
    if( $c->stash->{'use_frames'} and !$c->stash->{'show_nav_button'} ) {
        return $c->detach("thruk_index_html");
    }

    # custom start page?
    $c->stash->{'start_page'} = $c->stash->{'url_prefix'}.'thruk/main.html' unless defined $c->stash->{'start_page'};
    if( CORE::index($c->stash->{'start_page'}, $c->stash->{'url_prefix'}.'thruk/') != 0 ) {

        # external link, put in frames
        my $start_page = uri_escape( $c->stash->{'start_page'} );
        $c->log->debug( "redirecting to framed start page: '".$c->stash->{'url_prefix'}."thruk/frame.html?link=" . $start_page . "'" );
        return $c->response->redirect( $c->stash->{'url_prefix'}."thruk/frame.html?link=" . $start_page );
    }
    elsif ( $c->stash->{'start_page'} ne $c->stash->{'url_prefix'}.'thruk/main.html' ) {

        # internal link, no need to put in frames
        $c->log->debug( "redirecting to default start page: '" . $c->stash->{'start_page'} . "'" );
        return $c->response->redirect( $c->stash->{'start_page'} );
    }

    return $c->detach("thruk_main_html");
}

######################################

=head2 thruk_index_html

page: /thruk/index.html

=cut

sub thruk_index_html : Regex('thruk\/index\.html$') :MyAction('AddSafeDefaults') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return if Thruk::Utils::choose_mobile($c, $c->stash->{'url_prefix'}."thruk/cgi-bin/mobile.cgi");
    unless ( $c->stash->{'use_frames'} ) {
        return $c->detach("thruk_main_html");
    }

    $c->stash->{'title'}          = $c->config->{'name'};
    $c->stash->{'main'}           = '';
    $c->stash->{'target'}         = '';
    $c->stash->{'template'}       = 'index.tt';
    $c->stash->{'no_auto_reload'} = 1;

    return 1;
}

######################################

=head2 thruk_side_html

page: /thruk/side.html

=cut

sub thruk_side_html : Regex('thruk\/side\.html$') :MyAction('AddSafeDefaults') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    Thruk::Utils::check_pid_file($c);
    Thruk::Utils::Menu::read_navigation($c) unless defined $c->stash->{'navigation'} and $c->stash->{'navigation'} ne '';

    $c->stash->{'use_frames'}     = 1;
    $c->stash->{'title'}          = $c->config->{'name'};
    $c->stash->{'template'}       = 'side.tt';
    $c->stash->{'no_auto_reload'} = 1;

    return 1;
}

######################################

=head2 thruk_frame_html

page: /thruk/frame.html
# creates frame for external pages

=cut

sub thruk_frame_html : Regex('thruk\/frame\.html') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    # allowed links to be framed
    my $valid_links = [ quotemeta( $c->stash->{'url_prefix'}."thruk/cgi-bin" ), quotemeta( $c->stash->{'documentation_link'} ), quotemeta( $c->stash->{'start_page'} ), ];
    my $additional_links = $c->config->{'allowed_frame_links'};
    if( defined $additional_links ) {
        if( ref $additional_links eq 'ARRAY' ) {
            $valid_links = [ @{$valid_links}, @{$additional_links} ];
        }
        else {
            $valid_links = [ @{$valid_links}, $additional_links ];
        }
    }

    # check if any of the allowed links match
    my $link = $c->{'request'}->{'parameters'}->{'link'};
    if( defined $link ) {
        for my $pattern ( @{$valid_links} ) {
            if( $link =~ m/$pattern/mx ) {
                if($c->stash->{'use_frames'}) {
                    return $c->response->redirect($c->stash->{'url_prefix'}."thruk/#".$link);
                }
                $c->stash->{'target'}   = '_parent';
                $c->stash->{'main'}     = $link;
                $c->stash->{'title'}    = $c->config->{'name'};
                $c->stash->{'template'} = 'index.tt';

                return 1;
            }
        }
    }

    $c->stash->{'no_auto_reload'} = 1;

    # no link or none matched, display the usual index.html
    return $c->detach("thruk_index_html");
}

######################################

=head2 thruk_main_html

page: /thruk/main.html

=cut

sub thruk_main_html : Regex('thruk\/main\.html$') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};

    # add defaults when not using frames, otherwise the menu would be incomplete
    if(!defined $c->stash->{'defaults_added'} and !$c->stash->{'use_frames'}) {
        Thruk::Action::AddDefaults::add_defaults(0, undef, $self, $c);
    }

    $c->stash->{'title'}                   = 'Thruk Monitoring Webinterface';
    $c->stash->{'page'}                    = 'splashpage';
    $c->stash->{'template'}                = 'main.tt';
    $c->stash->{'hide_backends_chooser'}   = 1;
    $c->stash->{'no_auto_reload'}          = 1;
    $c->stash->{'enable_shinken_features'} = 0;

    return 1;
}

######################################

=head2 thruk_changes_html

page: /thruk/changes.html

=cut

sub thruk_changes_html : Regex('thruk\/changes\.html') :MyAction('AddDefaults') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    $c->stash->{infoBoxTitle}            = 'Change Log';
    $c->stash->{'title'}                 = 'Change Log';
    $c->stash->{'no_auto_reload'}        = 1;
    $c->stash->{'hide_backends_chooser'} = 1;
    $c->stash->{'template'}              = 'changes.tt';
    $c->stash->{page}                    = 'splashpage';

    return 1;
}

######################################

=head2 thruk_docs

page: /thruk/docs/

=cut

sub thruk_docs : Regex('thruk\/docs\/') :MyAction('AddDefaults') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    if( scalar @{ $c->request->args } > 0 and $c->request->args->[0] ne 'index.html' ) {
        return $c->detach("default");
    }

    $c->stash->{infoBoxTitle}            = 'Documentation';
    $c->stash->{'title'}                 = 'Documentation';
    $c->stash->{'no_auto_reload'}        = 1;
    $c->stash->{'hide_backends_chooser'} = 1;
    $c->stash->{'template'}              = 'docs.tt';
    $c->stash->{page}                    = 'splashpage';

    return 1;
}

######################################

=head2 tac_cgi

page: /thruk/cgi-bin/tac.cgi

=cut

sub tac_cgi : Regex('thruk\/cgi\-bin\/tac\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/tac/index');
}

######################################

=head2 status_cgi

page: /thruk/cgi-bin/status.cgi

=cut

sub status_cgi : Regex('thruk\/cgi\-bin\/status\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/status/index');
}

######################################

=head2 cmd_cgi

page: /thruk/cgi-bin/cmd.cgi

=cut

sub cmd_cgi : Regex('thruk\/cgi\-bin\/cmd\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/cmd/index');
}

######################################

=head2 outages_cgi

page: /thruk/cgi-bin/outages.cgi

=cut

sub outages_cgi : Regex('thruk\/cgi\-bin\/outages\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/outages/index');
}

######################################

=head2 avail_cgi

page: /thruk/cgi-bin/avail.cgi

=cut

sub avail_cgi : Regex('thruk\/cgi\-bin\/avail\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/avail/index');
}

######################################

=head2 trends_cgi

page: /thruk/cgi-bin/trends.cgi

=cut

sub trends_cgi : Regex('thruk\/cgi\-bin\/trends\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/trends/index');
}

######################################

=head2 history_cgi

page: /thruk/cgi-bin/history.cgi

=cut

sub history_cgi : Regex('thruk\/cgi\-bin\/history\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/history/index');
}

######################################

=head2 summary_cgi

page: /thruk/cgi-bin/summary.cgi

=cut

sub summary_cgi : Regex('thruk\/cgi\-bin\/summary\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/summary/index');
}

######################################

=head2 histogram_cgi

page: /thruk/cgi-bin/histogram.cgi

=cut

sub histogram_cgi : Regex('thruk\/cgi\-bin\/histogram\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/histogram/index');
}

######################################

=head2 notifications_cgi

page: /thruk/cgi-bin/notifications.cgi

=cut

sub notifications_cgi : Regex('thruk\/cgi\-bin\/notifications\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/notifications/index');
}

######################################

=head2 showlog_cgi

page: /thruk/cgi-bin/showlog.cgi

=cut

sub showlog_cgi : Regex('thruk\/cgi\-bin\/showlog\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/showlog/index');
}

######################################

=head2 extinfo_cgi

page: /thruk/cgi-bin/extinfo.cgi

=cut

sub extinfo_cgi : Regex('thruk\/cgi\-bin\/extinfo\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/extinfo/index');
}

######################################

=head2 config_cgi

page: /thruk/cgi-bin/config.cgi

=cut

sub config_cgi : Regex('thruk\/cgi\-bin\/config\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/config/index');
}

######################################

=head2 job_cgi

page: /thruk/cgi-bin/job.cgi

=cut

sub job_cgi : Regex('thruk\/cgi\-bin\/job.cgi') :MyAction('AddSafeDefaults') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};

    return Thruk::Utils::External::job_page($c);
}

######################################

=head2 login_cgi

page: /thruk/cgi-bin/login.cgi

=cut

sub login_cgi : Regex('thruk\/cgi\-bin\/login\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/login/index');
}

######################################

=head2 end

check and display errors (if any)

=cut

sub end : ActionClass('RenderView') {
    my( $self, $c ) = @_;

    Thruk::Utils::Menu::read_navigation($c) unless defined $c->stash->{'navigation'} and $c->stash->{'navigation'} ne '';

    my @errors = @{ $c->error };
    if( scalar @errors > 0 ) {
        for my $error (@errors) {
            $c->log->error($error);
        }
        return $c->detach('/error/index/13');
    }

    return 1;
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
