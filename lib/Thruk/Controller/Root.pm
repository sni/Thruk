package Thruk::Controller::Root;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';
use Data::Dumper;
use URI::Escape;
use Thruk::Utils::Livestatus;

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

    # Prefix
    $c->stash->{'url_prefix'} = Thruk->config->{'url_prefix'} || '/';

    # frame options
    my $use_frames = Thruk->config->{'use_frames'};
    $use_frames = 1 unless defined $use_frames;
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
    if( Thruk->config->{'use_frames'} == 1 ) {
        $show_nav_button = 0;
    }
    $c->stash->{'use_frames'}      = $use_frames;
    $c->stash->{'show_nav_button'} = $show_nav_button;
    $c->stash->{'reload_nav'}      = $c->{'request'}->{'parameters'}->{'reload_nav'} || '';

    # use pager?
    $c->stash->{'use_pager'}         = Thruk->config->{'use_pager'}         || 1;
    $c->stash->{'default_page_size'} = Thruk->config->{'default_page_size'} || 100;
    $c->stash->{'paging_steps'}      = Thruk->config->{'paging_steps'}      || [ '100', '500', '1000', '5000', 'all' ];

    $c->stash->{'start_page'}         = Thruk->config->{'start_page'}         || $c->stash->{'url_prefix'}.'thruk/main.html';
    $c->stash->{'documentation_link'} = Thruk->config->{'documentation_link'} || $c->stash->{'url_prefix'}.'thruk/docs/index.html';

    # these features are not implemented yet
    $c->stash->{'use_feature_statusmap'} = Thruk->config->{'use_feature_statusmap'} || 0;
    $c->stash->{'use_feature_statuswrl'} = Thruk->config->{'use_feature_statuswrl'} || 0;
    $c->stash->{'use_feature_histogram'} = Thruk->config->{'use_feature_histogram'} || 0;

    # enable trends if gd loaded
    if( $c->config->{'has_gd'} ) {
        $c->stash->{'use_feature_trends'} = 1;
    }

    $c->stash->{'datetime_format'}       = Thruk->config->{'datetime_format'};
    $c->stash->{'datetime_format_today'} = Thruk->config->{'datetime_format_today'};
    $c->stash->{'datetime_format_long'}  = Thruk->config->{'datetime_format_long'};
    $c->stash->{'datetime_format_log'}   = Thruk->config->{'datetime_format_log'};

    # which theme?
    my($param_theme, $cookie_theme);
    if( $c->{'request'}->{'parameters'}->{'theme'} ) {
        $param_theme = $c->{'request'}->{'parameters'}->{'theme'};
    }
    elsif( defined $c->request->cookie('thruk_theme') ) {
        my $theme_cookie = $c->request->cookie('thruk_theme');
        $cookie_theme = $theme_cookie->value if defined $theme_cookie->value and grep $theme_cookie->value, $c->config->{'themes'};
    }
    my $theme = $param_theme || $cookie_theme || Thruk->config->{'default_theme'} || 'Classic';
    if( defined $c->config->{templates_paths} ) {
        $c->stash->{additional_template_paths} = [ @{ $c->config->{templates_paths} }, $c->config->{root} . '/thruk/themes/' . $theme . '/templates' ];
    }
    else {
        $c->stash->{additional_template_paths} = [ $c->config->{root} . '/thruk/themes/' . $theme . '/templates' ];
    }
    $c->stash->{'theme'} = $theme;

    # new or classic search?
    my $use_new_search = Thruk->config->{'use_new_search'};
    $use_new_search = 1 unless defined $use_new_search;
    $c->stash->{'use_new_search'} = $use_new_search;

    # all problems link?
    my $all_problems_link = Thruk->config->{'all_problems_link'};
    if( !defined $all_problems_link ) {
        $all_problems_link = $c->stash->{'url_prefix'}."thruk/cgi-bin/status.cgi?style=detail&amp;hidesearch=1&amp;s0_hoststatustypes=12&amp;s0_servicestatustypes=31&amp;s0_hostprops=10&amp;s0_serviceprops=0&amp;s1_hoststatustypes=15&amp;s1_servicestatustypes=28&amp;s1_hostprops=10&amp;s1_serviceprops=10&amp;s1_hostprop=2&amp;s1_hostprop=8&amp;title=All%20Unhandled%20Problems";
    }
    $c->stash->{'all_problems_link'} = $all_problems_link;

    if(exists $c->{'request'}->{'parameters'}->{'noheader'}) {
        $c->{'request'}->{'parameters'}->{'hidetop'}  = 1;
    }
    $c->stash->{hidetop} = $c->{'request'}->{'parameters'}->{'hidetop'} || '';

    $c->stash->{'ajax_search'} = Thruk->config->{'use_ajax_search'} || 1;

    # status page settings
    $c->stash->{'show_notification_number'} = Thruk->config->{'show_notification_number'} || 1;

    # initialize our backends
    unless ( defined $c->{'db'} ) {
        $c->{'db'} = $c->model('Thruk');
        if( defined $c->{'db'} ) {
            $c->{'db'}->{'stats'}               = $c->stats;
            $c->{'db'}->{'log'}                 = $c->log;
            $c->{'db'}->set_passive_mode($c->config->{'strict_passive_mode'} || 0);
        }
    }
    $c->stash->{'strict_passive_mode'} = $c->config->{'strict_passive_mode'} || 0;

    # redirect to error page unless we have a connection
    if( !defined $c->{'db'} and $c->request->action !~ m|thruk/\w+\.html|mx and $c->request->action ne 'thruk/docs' ) {

        # do we have a deprecated config in use?
        my $deprecated_conf = Thruk::Utils::Livestatus::get_livestatus_conf();
        if( defined $deprecated_conf ) {
            $c->log->error( "The <Component Monitoring::Livestatus> configuration is deprecated, please use '<Component Thruk::Backend>' instead.\nYour converted config would be:\n\n" . Thruk::Utils::Livestatus::convert_config($deprecated_conf) . "\nplease update your thruk_local.conf" );
            return $c->detach("/error/index/20");
        }

        return $c->detach("/error/index/14");
    }

    my $target = $c->{'request'}->{'parameters'}->{'target'};
    if( !$c->stash->{'use_frames'} and defined $target and $target eq '_parent' ) {
        $c->stash->{'target'} = '_parent';
    }
    $c->stash->{'navigation'} = "";
    if( Thruk->config->{'use_frames'} == 0 ) {
        Thruk::Utils::Menu::read_navigation($c);
    }

    return 1;
}

######################################

=head2 auto

auto, runs on every request

redirects mobile browser to mobile cgis if enabled

=cut

sub auto : Private {
    my( $self, $c ) = @_;

    if( !defined Thruk->config->{'use_feature_mobile'} or Thruk->config->{'use_feature_mobile'} != 1 ) {
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
# but if used not via fastcgi/apache, there is no way around

=cut

sub thruk_index_html : Regex('thruk\/index\.html$') {
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
    $c->stash->{'main'}     = '';
    $c->stash->{'target'}   = '';
    $c->stash->{'template'} = 'index.tt';

    return 1;
}

######################################

=head2 thruk_side_html

page: /thruk/side.html

=cut

sub thruk_side_html : Regex('thruk\/side\.html$') {
    my( $self, $c ) = @_;

    # reset navigatio cache
    $c->cache->set('menu_conf_stat', undef);
    Thruk::Utils::Menu::read_navigation($c);

    $c->stash->{'use_frames'} = 1;
    $c->stash->{'template'}   = 'side.tt';

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
    my $valid_links = [ quotemeta( $c->stash->{'documentation_link'} ), quotemeta( $c->stash->{'start_page'} ), ];
    my $additional_links = Thruk->config->{'allowed_frame_links'};
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
                $c->stash->{'template'} = 'index.tt';

                return 1;
            }
        }
    }

    # no link or none matched, display the usual index.html
    return $c->detach("thruk_index_html");
}

######################################

=head2 thruk_main_html

page: /thruk/main.html

=cut

sub thruk_main_html : Regex('thruk\/main\.html$') {
    my( $self, $c ) = @_;
    $c->stash->{'title'}    = 'Thruk Monitoring Webinterface';
    $c->stash->{'page'}     = 'splashpage';
    $c->stash->{'template'} = 'main.tt';

    return 1;
}

######################################

=head2 thruk_changes_html

page: /thruk/changes.html

=cut

sub thruk_changes_html : Regex('thruk\/changes\.html') : MyAction('AddDefaults') {
    my( $self, $c ) = @_;
    $c->stash->{infoBoxTitle}     = 'Change Log';
    $c->stash->{'title'}          = 'Change Log';
    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{'template'}       = 'changes.tt';

    return 1;
}

######################################

=head2 thruk_docs

page: /thruk/docs/

=cut

sub thruk_docs : Regex('thruk\/docs\/') {
    my( $self, $c ) = @_;
    if( scalar @{ $c->request->args } > 0 and $c->request->args->[0] ne 'index.html' ) {
        return $c->detach("default");
    }
    $c->stash->{'title'}          = 'Documentation';
    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{'template'}       = 'docs.tt';

    return 1;
}

######################################

=head2 tac_cgi

page: /thruk/cgi-bin/tac.cgi

=cut

sub tac_cgi : Regex('thruk\/cgi\-bin\/tac\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/tac/index');
}

######################################

=head2 status_cgi

page: /thruk/cgi-bin/status.cgi

=cut

sub status_cgi : Regex('thruk\/cgi\-bin\/status\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/status/index');
}

######################################

=head2 cmd_cgi

page: /thruk/cgi-bin/cmd.cgi

=cut

sub cmd_cgi : Regex('thruk\/cgi\-bin\/cmd\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/cmd/index');
}

######################################

=head2 outages_cgi

page: /thruk/cgi-bin/outages.cgi

=cut

sub outages_cgi : Regex('thruk\/cgi\-bin\/outages\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/outages/index');
}

######################################

=head2 avail_cgi

page: /thruk/cgi-bin/avail.cgi

=cut

sub avail_cgi : Regex('thruk\/cgi\-bin\/avail\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/avail/index');
}

######################################

=head2 trends_cgi

page: /thruk/cgi-bin/trends.cgi

=cut

sub trends_cgi : Regex('thruk\/cgi\-bin\/trends\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/trends/index');
}

######################################

=head2 history_cgi

page: /thruk/cgi-bin/history.cgi

=cut

sub history_cgi : Regex('thruk\/cgi\-bin\/history\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/history/index');
}

######################################

=head2 summary_cgi

page: /thruk/cgi-bin/summary.cgi

=cut

sub summary_cgi : Regex('thruk\/cgi\-bin\/summary\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/summary/index');
}

######################################

=head2 histogram_cgi

page: /thruk/cgi-bin/histogram.cgi

=cut

sub histogram_cgi : Regex('thruk\/cgi\-bin\/histogram\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/histogram/index');
}

######################################

=head2 notifications_cgi

page: /thruk/cgi-bin/notifications.cgi

=cut

sub notifications_cgi : Regex('thruk\/cgi\-bin\/notifications\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/notifications/index');
}

######################################

=head2 showlog_cgi

page: /thruk/cgi-bin/showlog.cgi

=cut

sub showlog_cgi : Regex('thruk\/cgi\-bin\/showlog\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/showlog/index');
}

######################################

=head2 extinfo_cgi

page: /thruk/cgi-bin/extinfo.cgi

=cut

sub extinfo_cgi : Regex('thruk\/cgi\-bin\/extinfo\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/extinfo/index');
}

######################################

=head2 config_cgi

page: /thruk/cgi-bin/config.cgi

=cut

sub config_cgi : Regex('thruk\/cgi\-bin\/config\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'cancled'};
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
