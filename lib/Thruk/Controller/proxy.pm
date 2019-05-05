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

use HTTP::Request 6.12 ();
use LWP::UserAgent ();

##########################################################
sub index {
    my($c, $path_info) = @_;

    # workaround for centos7 apache segfaulting on too long requests urls
    if($c->req->header('X-Thruk-Passthrough')) {
        $path_info = $c->req->header('X-Thruk-Passthrough');
    }

    my($site, $url);
    if($path_info =~ m%^.*/thruk/cgi-bin/proxy.cgi/([^/]+)(/.*)$%mx) {
        $site = $1;
        $url  = $2;
    }
    if(!$url || !$site) {
        return $c->detach('/error/index/25');
    }
    if(!$c->config->{'http_backend_reverse_proxy'}) {
        return $c->redirect_to($url);
    }

    my $peer = $c->{'db'}->get_peer_by_key($site);
    if(!$peer) {
        # might be a not yet be populated federated backend
        Thruk::Action::AddDefaults::add_defaults($c);
        $peer = $c->{'db'}->get_peer_by_key($site);
        die("no such peer: ".$site) unless $peer;
    }
    if($peer->{'type'} ne 'http') {
        die("peer has type: ".$peer->{'type'});
    }

    my $session_id  = $c->req->cookies->{'thruk_auth'} || $peer->{'class'}->propagate_session_file($c);
    my $request_url = Thruk::Utils::absolute_url($peer->{'addr'}, $url, 1);

    # federated peers forward to the next hop
    my $passthrough;
    if($peer->{'federation'} && scalar @{$peer->{'fed_info'}->{'type'}} >= 2 && $peer->{'fed_info'}->{'type'}->[1] eq 'http') {
        $request_url = $peer->{'addr'};
        $request_url =~ s|/cgi\-bin/remote\.cgi$||gmx;
        $request_url =~ s|/thruk/?$||gmx;
        $request_url = $request_url.'/thruk/cgi-bin/proxy.cgi/'.$peer->{'key'};
        $passthrough = '/thruk/cgi-bin/proxy.cgi/'.$peer->{'key'}.$url;
    }

    if($c->req->{'env'}->{'QUERY_STRING'}) {
        $request_url = $request_url.'?'.$c->req->{'env'}->{'QUERY_STRING'};
    }
    my $req = HTTP::Request->new($c->req->method, $request_url, $c->req->headers->clone);
    $req->content($c->req->content());
    # cleanup a few headers
    for my $h (qw/host via x-forwarded-for referer/) {
        $req->header($h, undef);
    }
    if($passthrough) {
        $req->header('X-Thruk-Passthrough', $passthrough);
    }
    my $ua = LWP::UserAgent->new;
    $ua->max_redirect(0);
    $ua->ssl_opts('verify_hostname' => 0 ) if($request_url =~ m/^(http|https):\/\/localhost/mx || $request_url =~ m/^(http|https):\/\/127\./mx);
    if(!$c->config->{'ssl_verify_hostnames'}) {
        eval {
            # required for new IO::Socket::SSL versions
            require IO::Socket::SSL;
            IO::Socket::SSL::set_ctx_defaults( SSL_verify_mode => 0 );
        };
        $ua->ssl_opts('verify_hostname' => 0 );
    }

    $req->header('X-Thruk-Proxy', 1);
    _add_cookie($req, 'thruk_auth', $session_id);
    $c->stats->profile(begin => "req: ".$request_url);
    my $res = $ua->request($req);
    $c->stats->profile(end => "req: ".$request_url);
    $c->stats->profile(comment => sprintf('code: %s%s', $res->code, $res->header('location') ? "redirect: ".$res->header('location') : ''));

    # check if we need to login
    if($res->header('location') && $res->header('location') =~ m%\Q/cgi-bin/login.cgi?\E%mx) {
        # propagate session and try again
        $session_id = $peer->{'class'}->propagate_session_file($c);
        _add_cookie($req, 'thruk_auth', $session_id);
        $res = $ua->request($req);
    }

    # in case we don't have a cookie yet, set the last session_id, so it can be reused
    if(!$c->req->cookies->{'thruk_auth'}) {
        $c->res->cookies->{'thruk_auth'} = {value => $session_id, path => $c->stash->{'cookie_path'}, 'httponly' => 1 };
    }

    _cleanup_response($c, $peer, $url, $res);
    $c->res->status($res->code);
    $c->res->headers($res->headers);
    $c->res->body($res->content);
    $c->{'rendered'} = 1;
    $c->stash->{'inject_stats'} = 0;
    return;
}

##########################################################
sub _cleanup_response {
    my($c, $peer, $url, $res) = @_;

    if($c->req->header('X-Thruk-Passthrough')) {
        return;
    }

    my $replace_prefix;
    if($url =~ m%^(.*/(pnp|pnp4nagios|grafana|thruk)/)%mx) {
        $replace_prefix = $1;
    }
    my $site         = $peer->{'key'};
    my $url_prefix   = $c->stash->{'url_prefix'};
    my $proxy_prefix = $url_prefix.'cgi-bin/proxy.cgi/'.$site;

    # replace url in redirects
    if($res->header('location')) {
        my $loc = $res->header('location');
        $loc =~ s%^https?://[^/]+/%/%mx;
        if($loc !~ m/^\//mx) {
            my $newloc = $url;
            $newloc =~ s/[^\/]+$//gmx;
            $newloc = $newloc.$loc;
            $loc = $newloc;
        }
        $res->header('location', $proxy_prefix.$loc);
    }

    # replace path in cookies
    if($res->header("set-cookie")) {
        my $newcookie = $res->header("set-cookie");
        $newcookie =~ s%path=(.*?)(\s|$|;)%path=$proxy_prefix$1;%gmx;
        $res->header("set-cookie", $newcookie);
    }

    if($res->header('content-type') && $res->header('content-type') =~ m/^(text\/html|application\/json)/mxi) {
        my $body = $res->decoded_content || $res->content;
        if($replace_prefix) {
            # make thruk links work, but only if we are not proxying thruk itself
            if($url !~ m|/thruk/|mx) {
                $body =~ s%("|')/[^/]+/thruk/cgi-bin/%$1${url_prefix}cgi-bin/%gmx;
            } else {
                # if its thruk itself, insert a message at the top
                if($body =~ m/site_panel_container/mx) {
                    my $header = "";
                    $c->stash->{'proxy_peer'} = $peer;
                    Thruk::Views::ToolkitRenderer::render($c, "_proxy_header.tt", $c->stash, \$header);
                    $body =~ s/<\/body>/$header<\/body>/gmx;
                }
                # fix cookie path
                $body =~ s%^var\s+cookie_path\s*=\s+'([^']+)';%var cookie_path = '$proxy_prefix$1';%gmx;
            }

            # send other links to our proxy
            $body =~ s%("|')$replace_prefix%$1$proxy_prefix$replace_prefix%gmx;

            # length has changed
            $res->headers()->remove_header('content-length');

            # unset content encoding header, because its no longer gziped content but plain text
            $res->headers()->remove_header('content-encoding');

            # replace content
            $res->content(undef);
            $res->add_content_utf8($body);
        }
    }

    return;
}

##########################################################
sub _add_cookie {
    my($req, $name, $val) = @_;
    my $cookies = $req->header('cookie');
    if(!$cookies) {
        $req->header('cookie', $name.'='.$val.'; HttpOnly');
        return;
    }
    $cookies =~ s%$name=.*?(;\s*|$)%%gmx;
    $cookies = $cookies.'; '.$name.'='.$val.';';
    $req->header('cookie', $cookies);
    return;
}
##########################################################

1;
