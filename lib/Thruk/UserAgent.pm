package Thruk::UserAgent;

=head1 NAME

Thruk::UserAgent - UserAgent wrapper for Thruk

=head1 DESCRIPTION

UserAgent wrapper for Thruk

=cut

use strict;
use warnings;
use Carp qw/confess/;
use File::Temp qw/tempfile/;
use HTTP::Response ();
use HTTP::Request::Common;
use Thruk::Utils::IO ();
use Thruk::Utils::Log qw/:all/;

use constant SSL_verify_mode_NONE => 0; # Net::SSLeay::VERIFY_NONE(),

## no critic
$ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "IO::Socket::SSL";
## use critic

##############################################
=head1 METHODS

=head2 new

  my $lwp = Thruk::UserAgent->new($config)

returns new UserAgent object

=cut
sub new {
    my($class, $config, $thruk_config) = @_;
    confess("no config") unless $config;
    my $verify_hostnames = $thruk_config->{'ssl_verify_hostnames'} // 1;
    my $self = {
        'timeout'               => 180,
        'agent'                 => 'thruk',
        'ssl_opts'              => {},
        'max_redirect'          => 7,
        'protocols_allowed'     => ['http', 'https'],
        'requests_redirectable' => [ 'GET' ],           # not used
    };
    if(!$verify_hostnames || (defined $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} && !$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'})) {
        ## no critic
        $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0; # required for older IO::Socket::SSLs
        ## use critic
        $self->{'ssl_opts'}->{'verify_hostname'} = 0;
        $self->{'ssl_opts'}->{'SSL_verify_mode'} = SSL_verify_mode_NONE;
        _debug("SSL verify_hostname is disabled");
    }
    # ca settings
    if($thruk_config->{ssl_ca_path}) {
        $self->{'ssl_opts'}->{'SSL_ca_path'} = $thruk_config->{ssl_ca_path};
        _debug(sprintf("using SSL_ca_path: %s (from configuration)", $self->{'ssl_opts'}->{'SSL_ca_path'}));
    } elsif($thruk_config->{ssl_ca_file}) {
        $self->{'ssl_opts'}->{'SSL_ca_file'} = $thruk_config->{ssl_ca_file};
        _debug(sprintf("using SSL_ca_file: %s (from configuration)", $self->{'ssl_opts'}->{'SSL_ca_file'}));
    } else {
        ## no critic
        eval "use Mozilla::CA;";
        ## use critic
        if($@) {
            _trace(sprintf("failed to load Mozilla::CA: %s", $@));
            $self->{'ssl_opts'}->{'SSL_ca_path'} = "/etc/ssl/certs";
            _debug(sprintf("using default SSL_ca_path: %s (no Mozilla::CA module installed)", $self->{'ssl_opts'}->{'SSL_ca_path'}));
        } else {
            $self->{'ssl_opts'}->{'SSL_ca_file'} = Mozilla::CA::SSL_ca_file();
            _debug(sprintf("using SSL_ca_file: %s (from Mozilla::CA::SSL_ca_file)", $self->{'ssl_opts'}->{'SSL_ca_file'}));
        }
    }

    for my $key (sort keys %{$config}) {
        $self->{$key} = $config->{$key};
    }
    if(!$thruk_config || !$thruk_config->{'use_curl'}) {
        require LWP::UserAgent;
        my $ua = LWP::UserAgent->new(%{$self});
        $ua->no_proxy('127.0.0.1', 'localhost');
        return $ua;
    }
    bless($self, $class);
    return $self;
}

##############################################

=head2 get

  get($options)

do a get request

=cut
sub get {
    my($self, $url) = @_;
    my $request = GET($url);
    return($self->request($request));
}

##############################################

=head2 post

  post($options)

do a post request

=cut
sub post {
    my($self, $url, $data) = @_;
    my $request = POST($url, $data);
    return($self->request($request));
}

##############################################

=head2 agent

  agent([$agent])

get/set agent

=cut
sub agent {
    my($self, $agent) = @_;
    if(defined $agent) {
        $self->{'agent'} = $agent;
    }
    return $self->{'agent'};
}

##############################################

=head2 timeout

  timeout([$timeout])

get/set timeout

=cut
sub timeout {
    my($self, $timeout) = @_;
    if(defined $timeout) {
        $self->{'timeout'} = $timeout;
    }
    return $self->{'timeout'};
}

##############################################

=head2 ssl_opts

  ssl_opts([$ssl_opts])

get/set ssl_opts

=cut
sub ssl_opts {
    my($self, %ssl_opts) = @_;
    if(%ssl_opts) {
        $self->{'ssl_opts'} = {%ssl_opts, %{$self->{'ssl_opts'}}};
    }
    return $self->{'ssl_opts'};
}

##############################################

=head2 credentials

  credentials()

get/set basic auth credentials

=cut
sub credentials {
    my($self, $netloc, $realm, $login, $pass) = @_;
    if(defined $login) {
        $self->{'credentials'} = [$netloc, $realm, $login, $pass];
    }
    return $self->{'credentials'};
}

##############################################

=head2 default_header

  default_header()

get/set default_header

=cut
sub default_header {
    my($self, %default_header) = @_;
    for my $key (keys %default_header) {
        $self->{'default_header'}->{$key} = $default_header{$key};
    }
    return $self->{'default_header'};
}

##############################################

=head2 header

  header()

get/set header

=cut
sub header {
    my($self, %header) = @_;
    for my $key (keys %header) {
        $self->{'header'}->{$key} = $header{$key};
    }
    return $self->{'header'};
}

##############################################

=head2 max_redirect

  max_redirect()

get/set max_redirect

=cut
sub max_redirect {
    my($self, $max_redirect) = @_;
    if(defined $max_redirect) {
        $self->{'max_redirect'} = $max_redirect;
    }
    return $self->{'max_redirect'};
}

##############################################

=head2 protocols_allowed

  protocols_allowed()

get/set protocols_allowed

=cut
sub protocols_allowed {
    my($self, $protocols_allowed) = @_;
    if(defined $protocols_allowed) {
        $self->{'protocols_allowed'} = $protocols_allowed;
    }
    return $self->{'protocols_allowed'};
}

##############################################

=head2 requests_redirectable

  requests_redirectable()

get/set requests_redirectable

=cut
sub requests_redirectable {
    my($self, $requests_redirectable) = @_;
    if(defined $requests_redirectable) {
        $self->{'requests_redirectable'} = $requests_redirectable;
    }
    return $self->{'requests_redirectable'};
}

##############################################

=head2 env_proxy

  env_proxy()

set proxy from env

=cut
sub env_proxy {
    my($self) = @_;
    # no to do, env proxy is automatically honored
    return;
}

##############################################

=head2 cookie_jar

  cookie_jar()

get/set cookie_jar

=cut
sub cookie_jar {
    my($self, $jar) = @_;
    if($jar) {
        if(ref $jar) {
            $self->{'cookie_jar'} = $jar->{'file'};
        } else {
            $self->{'cookie_jar'} = $jar;
        }
    }
    return($self->{'cookie_jar'});
}

##############################################

=head2 request

  request()

request from given HTTP::Request

=cut
sub request {
    my($self, $req) = @_;
    my %headers = $req->headers()->flatten();
    for my $key (sort keys %headers) {
        $self->header($key, $headers{$key});
    }
    my $cmd = $self->_get_cmd_line();
    push @{$cmd}, '--request', $req->method();
    my $content = $req->content();
    my $tempfile;
    if($content ne "") {
        if(length($content) > 100) {
            (undef, $tempfile) = tempfile(TEMPLATE => 'postdataXXXXX', UNLINK => 1);
            Thruk::Utils::IO::write($tempfile, $content);
            push @{$cmd}, '--data-binary', '@'.$tempfile;
        } else {
            push @{$cmd}, '--data-binary', $content;
        }
        # disable 100-continue header logic
        push @{$cmd}, '-H', "Expect:";
    }
    my $url = "".$req->uri();
    $url =~ s/\#.*$//gmx; # hash must not be send to server
    push @{$cmd}, $url;
    my $res = $self->_get_response($cmd);
    $res->request($req); # set request object in our result
    unlink($tempfile) if $tempfile;
    return($res);
}

##############################################
sub _get_cmd_line {
    my($self) = @_;
    my $cmd = [
        'curl',
        '-A',                $self->{'agent'},
        '--connect-timeout', $self->{'ssl_opts'}->{'timeout'} || $self->{'timeout'},
        '--max-time',        ($self->{'ssl_opts'}->{'timeout'} || $self->{'timeout'}) + 2,
        '--max-redirs',      $self->{'max_redirect'},
        '--proto',           '-all,'.join(',', @{$self->{'protocols_allowed'}}),
        '--dump-header',     '-',
        '--silent',
        '--show-error',
    ];
    if($self->{'credentials'}) {
        push @{$cmd}, '--user', $self->{'credentials'}->[2].':'.$self->{'credentials'}->[3];
    }
    if($self->{'cookie_jar'}) {
        push @{$cmd}, '--cookie-jar', $self->{'cookie_jar'};
        push @{$cmd}, '--cookie',     $self->{'cookie_jar'};
    }
    for my $key (keys %{$self->{'default_header'}}) {
        push @{$cmd}, '--header', $key.': '.$self->{'default_header'}->{$key};
    }
    for my $key (keys %{$self->{'header'}}) {
        push @{$cmd}, '--header', $key.': '.$self->{'header'}->{$key};
    }
    if(   (defined $self->{'ssl_opts'}->{'verify_hostname'} && $self->{'ssl_opts'}->{'verify_hostname'} == 0)
       || (defined $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} && !$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'})
    ) {
        push @{$cmd}, '--insecure';
    }
    return $cmd;
}

##############################################
sub _get_response {
    my($self, $cmd) = @_;
    my($rc, $output) = Thruk::Utils::IO::cmd(undef, $cmd, undef, undef, undef, 1);
    if($rc != 0 || $output !~ m|^HTTP/|mx) {
        my $res = HTTP::Response->new(500);
        $res->content($output);
        return($res);
    }
    return(HTTP::Response->parse($output));
}

##############################################

=head2 disable_verify_hostname

  disable_verify_hostname($ua)

disable ssl checks for this user agent

=cut
sub disable_verify_hostname {
    my($ua) = @_;
    $ua->ssl_opts(
        verify_hostname => 0,
        SSL_verify_mode => SSL_verify_mode_NONE,
    );
    return;
}

##############################################

=head2 disable_verify_hostname_by_url

  disable_verify_hostname_by_url($ua, $url)

disable ssl checks for this user agent if url matches localhost pattern

=cut
sub disable_verify_hostname_by_url {
    my($ua, $url) = @_;
    if($url =~ m%^https?://(localhost|127\.0)%mx) {
        disable_verify_hostname($ua);
    }
    return;
}

1;
