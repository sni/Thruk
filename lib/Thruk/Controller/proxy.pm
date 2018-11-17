package Thruk::Controller::proxy;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::proxy - Proxy interface

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=head2 index

=cut

use HTTP::Request;
use LWP::UserAgent;

##########################################################
sub index {
    my($c, $path_info) = @_;

    my($site, $url);
    if($path_info =~ m%^.*/thruk/cgi-bin/proxy.cgi/([^/]+)(/.*)$%mx) {
        $site = $1;
        $url  = $2;
    }
    if(!$url) {
        return $c->detach('/error/index/25');
    }
    if(!$c->config->{'graph_proxy_enabled'} || !$site) {
        return $c->redirect_to($url);
    }

    my $peer = $c->{'db'}->get_peer_by_key($site);
    if(!$peer || $peer->{'type'} ne 'http') {
        return $c->redirect_to($url);
    }

    my $session_id  = $c->req->cookies->{'thruk_auth'} || $peer->{'class'}->propagate_session_file($c);
    my $request_url = Thruk::Utils::absolute_url($peer->{'addr'}, $url);
    if($c->req->{'env'}->{'QUERY_STRING'}) {
        $request_url = $request_url.'?'.$c->req->{'env'}->{'QUERY_STRING'};
    }
    my $req = HTTP::Request->new($c->req->method, $request_url, $c->req->headers->clone);
    $req->content($c->req->content());
    # cleanup a few headers
    for my $h (qw/host via x-forwarded-for referer/) {
        $req->header($h, undef);
    }
    my $ua = LWP::UserAgent->new;
    $ua->max_redirect(0);

    $req->header('cookie', 'thruk_auth='.$session_id);
    $c->stats->profile(begin => "req: ".$request_url);
    my $res = $ua->request($req);
    $c->stats->profile(end => "req: ".$request_url);
    $c->stats->profile(comment => sprintf('code: %s%s', $res->code, $res->header('location') ? "redirect: ".$res->header('location') : ''));

    # check if we need to login
    if($res->header('location') && $res->header('location') =~ m%\Q/cgi-bin/login.cgi?\E%mx) {
        # propagate session and try again
        $session_id = $peer->{'class'}->propagate_session_file($c);
        $req->header('cookie', 'thruk_auth='.$session_id);
        $res = $ua->request($req);
    }

    _cleanup_response($c, $site, $url, $res);
    $c->res->status($res->code);
    $c->res->headers($res->headers);
    $c->res->body($res->content);
    $c->{'rendered'} = 1;
    return;
}

##########################################################
sub _cleanup_response {
    my($c, $site, $url, $res) = @_;

    my $replace_prefix;
    if($url =~ s%^(.*/(pnp|pnp4nagios|grafana)/)%%mx) {
        $replace_prefix = $1;
    }
    my $url_prefix   = $c->stash->{'url_prefix'};
    my $proxy_prefix = $url_prefix.'cgi-bin/proxy.cgi/'.$site;

    # replace url in redirects
    if($res->header('location')) {
        my $loc = $res->header('location');
        $loc =~ s%^https?://[^/]+/%/%mx;
        $res->header('location', $proxy_prefix.$loc);
    }

    if($res->header('content-type') =~ m/^(text\/html|application\/json)/mx) {
        my $body = $res->content;
        if($replace_prefix) {
            # make thruk links work
            $body =~ s%("|')/[^/]+/thruk/cgi-bin/%$1${url_prefix}cgi-bin/%gmx;
            # send other links to our proxy
            $body =~ s%("|')$replace_prefix%$1$proxy_prefix$replace_prefix%gmx;

            # length has changed
            $res->headers()->remove_header('content-length');
        }
        $res->content($body);
    }

    return;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
