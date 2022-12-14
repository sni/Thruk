package Thruk::Controller::Root;

use warnings;
use strict;

use Thruk::Action::AddDefaults ();
use Thruk::Utils::Auth ();
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
    return(thruk_main_html($c));
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

    return(thruk_main_html($c));
}

######################################

=head2 thruk_index_html

page: /thruk/index.html

=cut

sub thruk_index_html {
    my( $c ) = @_;

    # if index page is requested, this usually means this is a user $session and no script, unset fake flag to enable csrf protection
    if($c->{'session'} && $c->{'session'}->{'fake'} && $c->{'session'}->{'file'}) {
        Thruk::Utils::IO::json_lock_patch($c->{'session'}->{'file'}, { fake => undef });
    }

    return(thruk_main_html($c));
}

######################################

=head2 thruk_main_html

page: /thruk/main.html

=cut

sub thruk_main_html {
    my( $c ) = @_;

    $c->stash->{'hide_backends_chooser'}   = 1;
    Thruk::Action::AddDefaults::add_defaults($c, Thruk::Constants::ADD_SAFE_DEFAULTS);
    $c->stash->{'title'}                   = 'Thruk Monitoring Webinterface';
    $c->stash->{'page'}                    = 'splashpage';
    $c->stash->{'template'}                = 'main_legacy.tt';
    $c->stash->{'no_auto_reload'}          = 1;
    $c->stash->{'inject_stats'}            = 0;
    $c->stash->{'allowed_frame_links'}     = [@{$c->config->{'allowed_frame_links'}//[]}, $c->config->{'documentation_link'}];
    return 1;
}

######################################

=head2 thruk_changes_html

page: /thruk/changes.html

=cut

sub thruk_changes_html {
    my( $c ) = @_;
    $c->stash->{'hide_backends_chooser'} = 1;
    Thruk::Action::AddDefaults::add_defaults($c, Thruk::Constants::ADD_SAFE_DEFAULTS);
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
    Thruk::Action::AddDefaults::add_defaults($c, Thruk::Constants::ADD_SAFE_DEFAULTS);
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

=head2 thruk_theme_preview

page: /thruk/cgi-bin/themes.cgi

=cut

sub thruk_theme_preview {
    my( $c ) = @_;
    Thruk::Action::AddDefaults::add_defaults($c, Thruk::Constants::ADD_SAFE_DEFAULTS);
    $c->stash->{infoBoxTitle}            = 'Themes';
    $c->stash->{'title'}                 = 'Themes';
    $c->stash->{'no_auto_reload'}        = 1;
    $c->stash->{'template'}              = 'theme_preview.tt';
    $c->stash->{page}                    = 'status';

    return 1;
}

######################################

=head2 empty_page

page: /thruk/cgi-bin/void.cgi

=cut

sub empty_page {
    my( $c ) = @_;
    $c->stash->{'template'} = 'void.tt';
    $c->stash->{page}       = 'void';
    $c->stash->{minimal}    = '1';

    return 1;
}

######################################

=head2 job_cgi

page: /thruk/cgi-bin/job.cgi

=cut

sub job_cgi {
    my( $c ) = @_;
    # use cached and safe defaults
    eval {
        Thruk::Action::AddDefaults::add_defaults($c, Thruk::Constants::ADD_CACHED_DEFAULTS);
    };
    _debug("adding defaults failed: ".$@) if $@;
    require Thruk::Utils::External;
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
        Thruk::Action::AddDefaults::add_defaults($c, Thruk::Constants::ADD_SAFE_DEFAULTS);
        $c->stash->{'template'} = '_header_prefs.tt';
        return;
    }

    Thruk::Action::AddDefaults::add_defaults($c, Thruk::Constants::ADD_CACHED_DEFAULTS);
    if($part eq '_host_comments') {
        my $host = $c->req->parameters->{'host'};
        $c->stash->{'comments'}  = $c->db->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { host_name => $host, service_description => '' } ] );
        $c->stash->{'type'}      = 'host';
        $c->stash->{'template'}  = '_parts_comments.tt';
        return;
    }

    if($part eq '_host_downtimes') {
        my $host = $c->req->parameters->{'host'};
        $c->stash->{'downtimes'} = $c->db->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { host_name => $host, service_description => '' } ] );
        $c->stash->{'type'}      = 'host';
        $c->stash->{'template'}  = '_parts_downtimes.tt';
        return;
    }

    if($part eq '_service_comments') {
        my $host = $c->req->parameters->{'host'};
        my $svc  = $c->req->parameters->{'service'};
        $c->stash->{'comments'}  = $c->db->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { host_name => $host, service_description => $svc } ] );
        $c->stash->{'type'}      = 'service';
        $c->stash->{'template'}  = '_parts_comments.tt';
        return;
    }

    if($part eq '_service_downtimes') {
        my $host = $c->req->parameters->{'host'};
        my $svc  = $c->req->parameters->{'service'};
        $c->stash->{'downtimes'} = $c->db->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { host_name => $host, service_description => $svc } ] );
        $c->stash->{'type'}      = 'service';
        $c->stash->{'template'}  = '_parts_downtimes.tt';
        return;
    }

    if($part eq '_service_info_popup') {
        my $host     = $c->req->parameters->{'host'};
        my $svc      = $c->req->parameters->{'service'};
        my $services = $c->db->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { host_name => $host, description => $svc } ], extra_columns => [qw/long_plugin_output/] );
        return $c->detach('/error/index/18') unless $services->[0];
        $c->stash->{'obj'}       = $services->[0];
        $c->stash->{'template'}  = '_parts_host_service_info_popup.tt';
        return;
    }

    if($part eq '_host_info_popup') {
        my $host  = $c->req->parameters->{'host'};
        my $hosts = $c->db->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), { host_name => $host } ], extra_columns => [qw/long_plugin_output/] );
        return $c->detach('/error/index/18') unless $hosts->[0];
        $c->stash->{'obj'}       = $hosts->[0];
        $c->stash->{'template'}  = '_parts_host_service_info_popup.tt';
        return;
    }

    return $c->detach('/error/index/25');
}

######################################

1;
