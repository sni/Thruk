package Thruk::Utils::CookieAuth;

=head1 NAME

Thruk::Utils::CookieAuth - Utilities Collection for Cookie Authentication

=head1 DESCRIPTION

Cookie Authentication offers a nice login mask and makes it possible
to logout again.

=cut

use warnings;
use strict;
use Data::Dumper;
use Thruk::UserAgent;
use Digest::MD5 qw(md5_hex);
use Thruk::Utils;
use Thruk::Utils::IO;
use Encode qw/encode_utf8/;

##############################################
BEGIN {
    if(!defined $ENV{'THRUK_CURL'} || $ENV{'THRUK_CURL'} == 0) {
        ## no critic
        $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;
        ## use critic
        eval {
            # required for new IO::Socket::SSL versions
            require IO::Socket::SSL;
            IO::Socket::SSL->import();
            IO::Socket::SSL::set_ctx_defaults( SSL_verify_mode => 0 );
        };
    }
}

##############################################

=head1 METHODS

=head2 external_authentication

    external_authentication($config, $login, $pass, $address)

verify authentication by external login into external url

return:

    sid  if login was ok
    0    if login failed
   -1    on technical problems

=cut
sub external_authentication {
    my($config, $login, $pass, $address, $stats) = @_;
    my $authurl  = $config->{'cookie_auth_restricted_url'};
    my $sdir     = $config->{'var_path'}.'/sessions';
    Thruk::Utils::IO::mkdir($sdir);

    my $netloc   = Thruk::Utils::CookieAuth::get_netloc($authurl);
    my $ua       = get_user_agent($config);
    # unset proxy which eventually has been set from https backends
    local $ENV{'HTTPS_PROXY'} = undef if exists $ENV{'HTTPS_PROXY'};
    # bypass ssl host verfication on localhost
    $ua->ssl_opts('verify_hostname' => 0 ) if($authurl =~ m/^(http|https):\/\/localhost/mx or $authurl =~ m/^(http|https):\/\/127\./mx);
    $stats->profile(begin => "ext::auth: post1 ".$authurl) if $stats;
    my $res      = $ua->post($authurl);
    $stats->profile(end   => "ext::auth: post1 ".$authurl) if $stats;
    if($res->code == 401) {
        my $realm = $res->header('www-authenticate');
        if($realm =~ m/Basic\ realm=\"([^"]+)\"/mx) {
            $realm = $1;
            # LWP requires perl internal format
            $login = encode_utf8(Thruk::Utils::ensure_utf8($login));
            $pass  = encode_utf8(Thruk::Utils::ensure_utf8($pass));
            $ua->credentials( $netloc, $realm, $login, $pass );
            $stats->profile(begin => "ext::auth: post2 ".$authurl) if $stats;
            $res = $ua->post($authurl);
            $stats->profile(end   => "ext::auth: post2 ".$authurl) if $stats;
            if($res->code == 200 and $res->request->header('authorization') and $res->decoded_content =~ m/^OK:\ (.*)$/mx) {
                if($1 eq $login) {
                    my $sessionid = md5_hex(rand(1000).time());
                    chomp($sessionid);
                    my $hash = $res->request->header('authorization');
                    $hash =~ s/^Basic\ //mx;
                    $hash = 'none' if $config->{'cookie_auth_session_cache_timeout'} == 0;
                    my $sessionfile = $sdir.'/'.$sessionid;
                    open(my $fh, '>', $sessionfile) or die('failed to open session file: '.$sessionfile.' '.$!);
                    print $fh join('~~~', $hash, $address, $login), "\n";
                    Thruk::Utils::IO::close($fh, $sessionfile);
                    return $sessionid;
                }
            } else {
                print STDERR 'authorization failed for user ', $login,' got rc ', $res->code;
                return 0;
            }
        } else {
            print STDERR 'auth: realm does not match, got ', $realm;
        }
    } else {
        print STDERR 'auth: expected code 401, got ', $res->code, "\n", Dumper($res);
    }
    return -1;
}

##############################################

=head2 verify_basic_auth

    verify_basic_auth($config, $basic_auth)

verify authentication by sending request with basic auth header

=cut
sub verify_basic_auth {
    my($config, $basic_auth, $login) = @_;
    my $authurl  = $config->{'cookie_auth_restricted_url'};

    my $ua = get_user_agent($config);
    # bypass ssl host verfication on localhost
    $ua->ssl_opts('verify_hostname' => 0 ) if($authurl =~ m/^(http|https):\/\/localhost/mx or $authurl =~ m/^(http|https):\/\/127\./mx);
    $ua->default_header( 'Authorization' => 'Basic '.$basic_auth );
    my $res = $ua->post($authurl);
    if($res->code == 200 and $res->decoded_content =~ m/^OK:\ (.*)$/mx) {
        if($1 eq $login) {
            return 1;
        }
    }
    return 0;
}

##############################################

=head2 get_user_agent

    get_user_agent($config)

returns user agent used for external requests

=cut
sub get_user_agent {
    my($config) = @_;
    my $ua = Thruk::UserAgent->new($config);
    $ua->timeout(30);
    $ua->agent("thruk_auth");
    return $ua;
}

##############################################

=head2 clean_session_files

    clean_session_files($url)

clean up session files

=cut
sub clean_session_files {
    my($config) = @_;
    die("no config") unless $config;
    my $sdir    = $config->{'var_path'}.'/sessions';
    my $timeout = time() - $config->{'cookie_auth_session_timeout'};
    Thruk::Utils::IO::mkdir($sdir);
    opendir( my $dh, $sdir) or die "can't opendir '$sdir': $!";
    for my $entry (readdir($dh)) {
        next if $entry eq '.' or $entry eq '..';
        my $file = $sdir.'/'.$entry;
        my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
           $atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
        if($mtime < $timeout) {
            unlink($file);
        }
    }
    return;
}

##############################################

=head2 get_netloc

    get_netloc($url)

return netloc used by LWP::UserAgent credentials

=cut
sub get_netloc {
    my($url) = @_;
    if($url =~ m/^(http|https):\/\/([^\/:]+)\//mx) {
        my $port = $1 eq 'https' ? 443 : 80;
        my $host = $2;
        $host = $host.':'.$port unless CORE::index($host, ':') != -1;
        return($host);
    }
    return('localhost:80');
}

##############################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
