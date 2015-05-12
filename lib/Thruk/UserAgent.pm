package Thruk::UserAgent;

=head1 NAME

Thruk::UserAgent - UserAgent wrapper for Thruk

=head1 DESCRIPTION

UserAgent wrapper for Thruk

=cut

use strict;
use warnings;
use utf8;
use Carp;
use IPC::Open3;
use HTTP::Response;

##############################################
=head1 METHODS

=head2 new

  my $lwp = Thruk::UserAgent->new($config)

returns new UserAgent object

=cut
sub new {
    my($class, $config) = @_;
    confess("no config") unless $config;
    if(!$config->{'use_curl'}) {
        require LWP::UserAgent;
        my $ua = LWP::UserAgent->new;
        return $ua;
    }
    my $self = {
        'timeout'               => 180,
        'agent'                 => 'thruk',
        'ssl_opts'              => {},
        'default_header'        => {},
        'max_redirect'          => 7,
        'protocols_allowed'     => ['http', 'https'],
        'requests_redirectable' => [ 'GET' ],           # not used
    };
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
    my $cmd = $self->_get_cmd_line();
    my $res = $self->_request($url, $cmd);
    return $res;
}

##############################################

=head2 post

  post($options)

do a post request

=cut
sub post {
    my($self, $url, $data) = @_;
    my $cmd = $self->_get_cmd_line();
    for my $key (keys %{$data}) {
        push @{$cmd}, '-d', $key.'='.$data->{$key};
    }
    my $res = $self->_request($url, $cmd);
    return $res;
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
        $self->{'ssl_opts'} = \%ssl_opts;
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
    my($self, $default_header) = @_;
    if(defined $default_header) {
        for my $key (keys %{$default_header}) {
            $self->{'default_header'}->{$key} = $default_header->{$key};
        }
    }
    return $self->{'default_header'};
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
    ];
    if($self->{'credentials'}) {
        push @{$cmd}, '--user', $self->{'credentials'}->[2].':'.$self->{'credentials'}->[3];
    }
    for my $key (keys %{$self->{'default_header'}}) {
        push @{$cmd}, '--header', $key.': '.$self->{'default_header'}->{$key};
    }
    if(defined $self->{'ssl_opts'}->{'verify_hostname'} and $self->{'ssl_opts'}->{'verify_hostname'} == 0) {
        push @{$cmd}, '--insecure';
    }
    return $cmd;
}

##############################################
sub _request {
    my($self, $url, $cmd) = @_;
    push @{$cmd}, $url;
    my $prog = shift @{$cmd};
    my($rc, $pid, $wtr, $rdr);
    $pid = open3($wtr, $rdr, $rdr, $prog, @{$cmd});
    waitpid( $pid, 0 );
    $rc = $?;
    my $output = '';
    while(my $line = <$rdr>) { $output .= $line; }
    my $r = HTTP::Response->parse($output);
    $r->{'_request'}->{'_uri'} = $url;
    return($r);
}

##############################################

1;

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
