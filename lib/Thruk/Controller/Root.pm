package Thruk::Controller::Root;

use strict;
use warnings;
use URI::Escape qw/uri_escape/;
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::Controller::Root - Root Controller for Thruk

=head1 DESCRIPTION

Root Controller of the Thruk Monitoring Webinterface

=head1 METHODS

=cut

######################################

=head2 index

redirect from /

=cut

sub index {
    my( $c ) = @_;
    return $c->redirect_to($c->stash->{'url_prefix'});
}

######################################

=head2 index_html

redirect from /index.html

because we dont want index.html in the url

=cut

sub index_html {
    my( $c ) = @_;
    return if Thruk::Utils::choose_mobile($c, $c->stash->{'url_prefix'}."cgi-bin/mobile.cgi");
    if( $c->stash->{'use_frames'} ) {
        return(thruk_index_html($c));
    }
    else {
        return(thruk_main_html($c));
    }
}

######################################

=head2 thruk_index

redirect from /thruk/
but if used not via fastcgi/apache, there is no way around

=cut

sub thruk_index {
    my( $c ) = @_;
    # redirect from /thruk to /thruk/
    if($c->req->path !~ /\/$/mx) {
        return $c->redirect_to($c->stash->{'url_prefix'});
    }
    return if Thruk::Utils::choose_mobile($c, $c->stash->{'url_prefix'}."cgi-bin/mobile.cgi");

    if( $c->stash->{'use_frames'} && !$c->stash->{'show_nav_button'} ) {
        return(thruk_index_html($c));
    }

    # custom start page?
    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_SAFE_DEFAULTS);
    $c->stash->{'start_page'} = $c->stash->{'url_prefix'}.'main.html' unless defined $c->stash->{'start_page'};
    if( CORE::index($c->stash->{'start_page'}, $c->stash->{'url_prefix'}) != 0 ) {

        # external link, put in frames
        my $start_page = uri_escape( $c->stash->{'start_page'} );
        _debug( "redirecting to framed start page: '".$c->stash->{'url_prefix'}."frame.html?link=" . $start_page . "'" );
        return $c->redirect_to( $c->stash->{'url_prefix'}."frame.html?link=" . $start_page );
    }
    elsif ( $c->stash->{'start_page'} ne $c->stash->{'url_prefix'}.'main.html' ) {

        # internal link, no need to put in frames
        _debug( "redirecting to default start page: '" . $c->stash->{'start_page'} . "'" );
        return $c->redirect_to( $c->stash->{'start_page'} );
    }

    return(thruk_main_html($c));
}

######################################

=head2 thruk_index_html

page: /thruk/index.html

=cut

sub thruk_index_html {
    my( $c ) = @_;
    return if Thruk::Utils::choose_mobile($c, $c->stash->{'url_prefix'}."cgi-bin/mobile.cgi");
    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_SAFE_DEFAULTS);
    if(!$c->stash->{'use_frames'}) {
        return(thruk_main_html($c));
    }

    # if index page is requested, this usually means this is a user $session and no script, unset fake flag to enable csrf protection
    if($c->{'session'} && $c->{'session'}->{'fake'} && $c->{'session'}->{'file'}) {
        Thruk::Utils::IO::json_lock_patch($c->{'session'}->{'file'}, { fake => undef });
    }

    $c->stash->{'title'}           = $c->config->{'name'};
    $c->stash->{'main'}            = '';
    $c->stash->{'target'}          = '';
    $c->stash->{'template'}        = 'index.tt';
    $c->stash->{'no_auto_reload'}  = 1;
    $c->stash->{'skip_navigation'} = 1;
    $c->stash->{'inject_stats'}    = 0;

    return 1;
}

######################################

=head2 thruk_side_html

page: /thruk/side.html

=cut

sub thruk_side_html {
    my( $c ) = @_;
    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_SAFE_DEFAULTS);
    Thruk::Utils::check_pid_file($c);
    Thruk::Utils::Menu::read_navigation($c) unless defined $c->stash->{'navigation'} and $c->stash->{'navigation'} ne '';

    $c->stash->{'use_frames'}     = 1;
    $c->stash->{'title'}          = $c->config->{'name'};
    $c->stash->{'template'}       = 'side.tt';
    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{'inject_stats'}   = 0;

    return 1;
}

######################################

=head2 thruk_frame_html

page: /thruk/frame.html
# creates frame for external pages

=cut

sub thruk_frame_html {
    my( $c ) = @_;
    # allowed links to be framed
    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_SAFE_DEFAULTS);
    my $valid_links = [ quotemeta( $c->stash->{'url_prefix'}."cgi-bin" ), quotemeta( $c->stash->{'documentation_link'} ), quotemeta( $c->stash->{'start_page'} ), ];
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
    my $link = $c->req->parameters->{'link'};
    if( defined $link ) {
        for my $pattern ( @{$valid_links} ) {
            if( $link =~ m/$pattern/mx ) {
                if($c->stash->{'use_frames'}) {
                    return $c->redirect_to($c->stash->{'url_prefix'}.'#'.$link);
                }
                $c->stash->{'target'}    = '_parent';
                $c->stash->{'main'}      = $link;
                $c->stash->{'title'}     = $c->config->{'name'};
                $c->stash->{'template'}  = 'index.tt';

                return 1;
            }
        }
    }

    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{'navigation'}     = 'off'; # would be useless here, so set it non-empty, otherwise AddDefaults::end would read it again
    $c->stash->{'inject_stats'}   = 0;

    # no link or none matched, display the usual index.html
    return(thruk_index_html($c));
}

######################################

=head2 thruk_main_html

page: /thruk/main.html

=cut

sub thruk_main_html {
    my( $c ) = @_;

    $c->stash->{'hide_backends_chooser'}   = 1;
    Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_SAFE_DEFAULTS);
    $c->stash->{'title'}                   = 'Thruk Monitoring Webinterface';
    $c->stash->{'page'}                    = 'splashpage';
    $c->stash->{'template'}                = 'main.tt';
    $c->stash->{'no_auto_reload'}          = 1;
    $c->stash->{'inject_stats'}            = 0;

    return 1;
}

######################################

=head2 thruk_changes_html

page: /thruk/changes.html

=cut

sub thruk_changes_html {
    my( $c ) = @_;
    $c->stash->{'hide_backends_chooser'} = 1;
    Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_SAFE_DEFAULTS);
    $c->stash->{infoBoxTitle}            = 'Change Log';
    $c->stash->{'title'}                 = 'Change Log';
    $c->stash->{'no_auto_reload'}        = 1;
    $c->stash->{'template'}              = 'changes.tt';
    $c->stash->{page}                    = 'splashpage';
    $c->stash->{no_tt_trim}              = 1;
    $c->stash->{'inject_stats'}          = 0;

    return 1;
}

######################################

=head2 thruk_docs

page: /thruk/docs/

=cut

sub thruk_docs  {
    my( $c ) = @_;
    $c->stash->{'hide_backends_chooser'} = 1;
    Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_SAFE_DEFAULTS);
    $c->stash->{infoBoxTitle}            = 'Documentation';
    $c->stash->{'title'}                 = 'Documentation';
    $c->stash->{'no_auto_reload'}        = 1;
    $c->stash->{'template'}              = 'docs.tt';
    $c->stash->{'extrabodyclass'}        = 'docs';
    $c->stash->{'page'}                  = 'splashpage';
    $c->stash->{'inject_stats'}          = 0;

    return 1;
}

######################################

=head2 job_cgi

page: /thruk/cgi-bin/job.cgi

=cut

sub job_cgi {
    my( $c ) = @_;
    Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_SAFE_DEFAULTS);
    return Thruk::Utils::External::job_page($c);
}

######################################

=head2 parts_cgi

page: /thruk/cgi-bin/parts.cgi

=cut

sub parts_cgi {
    my($c) = @_;
    my $part = $c->req->parameters->{'part'};
    return $c->detach('/error/index/25') unless $part;

    if($part eq '_header_prefs') {
        Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_SAFE_DEFAULTS);
        $c->stash->{'template'} = '_header_prefs.tt';
        return;
    }

    Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_CACHED_DEFAULTS);
    if($part eq '_host_comments') {
        my $host = $c->req->parameters->{'host'};
        $c->stash->{'comments'}  = $c->{'db'}->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { host_name => $host, service_description => '' } ] );
        $c->stash->{'type'}      = 'host';
        $c->stash->{'template'}  = '_parts_comments.tt';
        return;
    }

    if($part eq '_host_downtimes') {
        my $host = $c->req->parameters->{'host'};
        $c->stash->{'downtimes'} = $c->{'db'}->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { host_name => $host, service_description => '' } ] );
        $c->stash->{'type'}      = 'host';
        $c->stash->{'template'}  = '_parts_downtimes.tt';
        return;
    }

    if($part eq '_service_comments') {
        my $host = $c->req->parameters->{'host'};
        my $svc  = $c->req->parameters->{'service'};
        $c->stash->{'comments'}  = $c->{'db'}->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { host_name => $host, service_description => $svc } ] );
        $c->stash->{'type'}      = 'service';
        $c->stash->{'template'}  = '_parts_comments.tt';
        return;
    }

    if($part eq '_service_downtimes') {
        my $host = $c->req->parameters->{'host'};
        my $svc  = $c->req->parameters->{'service'};
        $c->stash->{'downtimes'} = $c->{'db'}->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { host_name => $host, service_description => $svc } ] );
        $c->stash->{'type'}      = 'service';
        $c->stash->{'template'}  = '_parts_downtimes.tt';
        return;
    }

    if($part eq '_service_info_popup') {
        my $host     = $c->req->parameters->{'host'};
        my $svc      = $c->req->parameters->{'service'};
        my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { host_name => $host, description => $svc } ], extra_columns => [qw/long_plugin_output/] );
        return $c->detach('/error/index/18') unless $services->[0];
        $c->stash->{'s'}         = $services->[0];
        $c->stash->{'template'}  = '_parts_service_info_popup.tt';
        return;
    }

    return $c->detach('/error/index/25');
}

######################################

1;
