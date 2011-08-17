package Thruk::Controller::Root;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';
use Data::Dumper;
use URI::Escape;

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
        use_ajax_search                 => 1,
        ajax_search_hosts               => 1,
        ajax_search_hostgroups          => 1,
        ajax_search_services            => 1,
        ajax_search_servicegroups       => 1,
        shown_inline_pnp                => 1,
        use_wait_feature                => 1,
        wait_timeout                    => 10,
        use_frames                      => 1,
        use_strict_host_authorization   => 0,
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
        use_feature_statusmap           => 0,
        use_feature_statuswrl           => 0,
        use_feature_histogram           => 0,
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
        },
        command_disabled                    => [],
        var_path                            => './var',
        priorities                      => {
                    5                       => 'Business Critical',
                    4                       => 'Top Production',
                    3                       => 'Production',
                    2                       => 'Standard',
                    1                       => 'Testing',
                    0                       => 'Development',
        },
    };
    for my $key (keys %{$defaults}) {
        $c->config->{$key} = exists $c->config->{$key} ? $c->config->{$key} : $defaults->{$key};
    }

    # make some configs available in stash
    for my $key (qw/url_prefix title_prefix use_pager start_page documentation_link
                  use_feature_statusmap use_feature_statuswrl use_feature_histogram
                  datetime_format datetime_format_today datetime_format_long datetime_format_log
                  use_new_search ajax_search show_notification_number strict_passive_mode
                  show_full_commandline all_problems_link use_ajax_search show_long_plugin_output
                  priorities
                /) {
        $c->stash->{$key} = $c->config->{$key};
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

    # use pager?
    Thruk::Utils::set_paging_steps($c, $c->config->{'paging_steps'});

    # enable trends if gd loaded
    if( $c->config->{'has_gd'} ) {
        $c->stash->{'use_feature_trends'} = 1;
    }

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
        $c->stash->{additional_template_paths} = [ @{ $c->config->{templates_paths} }, $c->config->{root} . '/thruk/themes/' . $theme . '/templates' ];
    }
    else {
        $c->stash->{additional_template_paths} = [ $c->config->{root} . '/thruk/themes/' . $theme . '/templates' ];
    }
    $c->stash->{all_in_one_css} = 1 if $theme eq 'Thruk';

    if(exists $c->{'request'}->{'parameters'}->{'noheader'}) {
        $c->{'request'}->{'parameters'}->{'hidetop'}  = 1;
    }
    $c->stash->{hidetop} = $c->{'request'}->{'parameters'}->{'hidetop'} || '';

    # initialize our backends
    unless ( defined $c->{'db'} ) {
        $c->{'db'} = $c->model('Thruk');
        if( defined $c->{'db'} ) {
            $c->{'db'}->init(
                'stats'               => $c->stats,
                'log'                 => $c->log,
                'config'              => $c->config,
            );
        }
    }

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
           or $c->request->action eq 'thruk$'
           or $c->request->action eq 'thruk\\/docs\\/' ) {
            $c->stash->{'no_auto_reload'} = 1;
            return;
        }
        return $c->detach("/error/index/14");

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
        return $c->redirect($c->stash->{'url_prefix'}."thruk/frame.html?link=".uri_escape($path));
    }

    # icon image path
    $c->config->{'logo_path_prefix'} = exists $c->config->{'logo_path_prefix'} ? $c->config->{'logo_path_prefix'} : $c->stash->{'url_prefix'}.'thruk/themes/'.$c->stash->{'theme'}.'/images/logos/';
    $c->stash->{'logo_path_prefix'}  = $c->config->{'logo_path_prefix'};

    return 1;
}

######################################

=head2 auto

auto, runs on every request

redirects mobile browser to mobile cgis if enabled

=cut

sub auto : Private {
    my( $self, $c ) = @_;

    if( !defined $c->config->{'use_feature_mobile'} or $c->config->{'use_feature_mobile'} != 1 ) {
        return 1;
    }

    if(     defined $c->{'request'}->{'headers'}->{'user-agent'}
        and $c->{'request'}->{'headers'}->{'user-agent'} =~ m/iPhone/mx
        and defined $c->{'request'}->{'action'}
        and $c->{'request'}->{'action'} =~ m/^(\/|thruk|)$/mx )
    {
        return $c->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/mobile.cgi");
    }
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
    return $c->redirect($c->stash->{'url_prefix'}."thruk/");
}

######################################

=head2 index_html

redirect from /index.html

beacuse we dont want index.html in the url

=cut

sub index_html : Path('/index.html') {
    my( $self, $c ) = @_;
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
        $c->log->debug( $c->redirect( $c->stash->{'url_prefix'}."thruk/frame.html?link=" . $start_page ) );
        return $c->redirect( $c->stash->{'url_prefix'}."thruk/frame.html?link=" . $start_page );
    }
    elsif ( $c->stash->{'start_page'} ne $c->stash->{'url_prefix'}.'thruk/main.html' ) {

        # internal link, no need to put in frames
        $c->log->debug( "redirecting to default start page: '" . $c->stash->{'start_page'} . "'" );
        return $c->redirect( $c->stash->{'start_page'} );
    }

    return $c->detach("thruk_main_html");
}

######################################

=head2 thruk_index_html

page: /thruk/index.html

=cut

sub thruk_index_html : Regex('thruk\/index\.html$') :MyAction('AddDefaults') {
    my( $self, $c ) = @_;
    unless ( $c->stash->{'use_frames'} ) {
        return $c->detach("thruk_main_html");
    }

    if(-f "templates/index.tt") {
        my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("templates/index.tt");
        if(defined $c->{'request'}->{'headers'}->{'if-modified-since'}
           and $c->req->headers->if_modified_since == $mtime) {
            # set not modified status
            $c->response->status(304);
            return 1;
        }
        $c->response->headers->last_modified($mtime);
    }

    $c->response->header( 'Cache-Control' => 'max-age=7200, public' );
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

sub thruk_side_html : Regex('thruk\/side\.html$') :MyAction('AddDefaults') {
    my( $self, $c ) = @_;

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

sub thruk_frame_html : Regex('thruk\/frame\.html$') {
    my( $self, $c ) = @_;

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
                $c->stash->{'target'}   = '_parent';
                $c->stash->{'main'}     = $link;
                $c->stash->{'title'}    = $c->config->{'name'};
                $c->stash->{'template'} = 'index.tt';

                $c->response->header( 'Cache-Control' => 'max-age=7200, public' );

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

sub thruk_main_html : Regex('thruk\/main\.html$') :MyAction('AddDefaults') {
    my( $self, $c ) = @_;
    $c->stash->{'title'}                 = 'Thruk Monitoring Webinterface';
    $c->stash->{'page'}                  = 'splashpage';
    $c->stash->{'template'}              = 'main.tt';
    $c->stash->{'hide_backends_chooser'} = 1;
    $c->stash->{'no_auto_reload'}        = 1;

    return 1;
}

######################################

=head2 thruk_changes_html

page: /thruk/changes.html

=cut

sub thruk_changes_html : Regex('thruk\/changes\.html') :MyAction('AddDefaults') {
    my( $self, $c ) = @_;
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

=head2 error

page: /error/

internal use only

=cut

sub error : Regex('error/') {
    my( $self, $c ) = @_;
    if( scalar @{ $c->request->args } < 1 ) {
        return $c->detach("default");
    }
    return $c->detach( '/error/' . join( '/', @{ $c->request->args } ) );
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

1;
