package Thruk::Utils::CookieAuth;

=head1 NAME

Thruk::Utils::CookieAuth - Utilities Collection for Cookie Authentication

=head1 DESCRIPTION

Cookie Authentication offers a nice login mask and makes it possible
to logout again.

=cut

use warnings;
use strict;
use Thruk::UserAgent;
use Thruk::Authentication::User;
use Thruk::Utils;
use Thruk::Utils::IO;
use Data::Dumper;
use Encode qw/encode_utf8/;
use Digest ();
use File::Slurp qw/read_file/;
use Carp qw/confess/;
use File::Copy qw/move/;

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

my $supported_digests = {
    "1"  => 'SHA-256',
};
my $default_digest        = 1;
my $hashed_key_file_regex = qr/^([a-zA-Z0-9]+)(\.[A-Z]+\-\d+|)$/mx;
my $session_key_regex     = qr/^([a-zA-Z0-9]+)(|_\d{1})$/mx;

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
    local $ENV{'HTTP_PROXY'}  = undef if exists $ENV{'HTTP_PROXY'};
    # bypass ssl host verfication on localhost
    $ua->ssl_opts('verify_hostname' => 0 ) if($authurl =~ m/^(http|https):\/\/localhost/mx or $authurl =~ m/^(http|https):\/\/127\./mx);
    $stats->profile(begin => "ext::auth: post1 ".$authurl) if $stats;
    my $res      = $ua->post($authurl);
    $stats->profile(end   => "ext::auth: post1 ".$authurl) if $stats;
    if($res->code == 302 && $authurl =~ m|^http:|mx) {
        (my $authurl_https = $authurl) =~ s|^http:|https:|gmx;
        if($res->{'_headers'}->{'location'} eq $authurl_https) {
            $config->{'cookie_auth_restricted_url'} = $authurl_https;
            return(external_authentication($config, $login, $pass, $address, $stats));
        }
    }
    if($res->code == 401) {
        my $realm = $res->header('www-authenticate');
        if($realm =~ m/Basic\ realm=\"([^"]+)\"/mx) {
            $realm = $1;
            # LWP requires perl internal format
            if(ref $login eq 'HASH') {
                for my $header (keys %{$login}) {
                    $ua->default_header( $header => $login->{$header} );
                }
            } else {
                $login = encode_utf8(Thruk::Utils::ensure_utf8($login));
                $pass  = encode_utf8(Thruk::Utils::ensure_utf8($pass));
                $ua->credentials( $netloc, $realm, $login, $pass );
            }
            $stats->profile(begin => "ext::auth: post2 ".$authurl) if $stats;
            $res = $ua->post($authurl);
            $stats->profile(end   => "ext::auth: post2 ".$authurl) if $stats;
            if($res->code == 200 and $res->request->header('authorization') and $res->decoded_content =~ m/^OK:\ (.*)$/mx) {
                if(ref $login eq 'HASH') { $login = $1; }
                if($1 eq Thruk::Authentication::User::transform_username($config, $login)) {
                    my $hash = $res->request->header('authorization');
                    $hash =~ s/^Basic\ //mx;
                    $hash = 'none' if $config->{'cookie_auth_session_cache_timeout'} == 0;
                    my($sessionid, undef) = store_session($config, undef, {
                        hash     => $hash,
                        address  => $address,
                        username => $login,
                    });
                    return $sessionid;
                }
            } else {
                $login = '(unknown)' if ref $login eq 'HASH';
                print STDERR 'authorization failed for user ', $login,' got rc ', $res->code, "\n";
                return 0;
            }
        } else {
            print STDERR 'auth: realm does not match, got ', $realm, "\n";
        }
    } else {
        print STDERR 'auth: expected code 401, got ', $res->code, "\n", Dumper($res);
    }
    return -1;
}

##############################################

=head2 verify_basic_auth

    verify_basic_auth($config, $basic_auth)

verify authentication by sending request with basic auth header.

returns  1 if authentication was successfull
returns -1 on timeout error
returns  0 if unsuccessful

=cut
sub verify_basic_auth {
    my($config, $basic_auth, $login, $timeout) = @_;
    my $authurl  = $config->{'cookie_auth_restricted_url'};

    # unset proxy which eventually has been set from https backends
    local $ENV{'HTTPS_PROXY'} = undef if exists $ENV{'HTTPS_PROXY'};
    local $ENV{'HTTP_PROXY'}  = undef if exists $ENV{'HTTP_PROXY'};

    my $ua = get_user_agent($config);
    $ua->timeout($timeout) if $timeout;
    # bypass ssl host verfication on localhost
    $ua->ssl_opts('verify_hostname' => 0 ) if($authurl =~ m/^(http|https):\/\/localhost/mx or $authurl =~ m/^(http|https):\/\/127\./mx);
    $ua->default_header( 'Authorization' => 'Basic '.$basic_auth );
    printf(STDERR "thruk_auth: basic auth request for %s to %s\n", $login, $authurl) if ($ENV{'THRUK_COOKIE_AUTH_VERBOSE'} && $ENV{'THRUK_COOKIE_AUTH_VERBOSE'} > 1);
    my $res = $ua->post($authurl);
    if($res->code == 302 && $authurl =~ m|^http:|mx) {
        (my $authurl_https = $authurl) =~ s|^http:|https:|gmx;
        if($res->{'_headers'}->{'location'} eq $authurl_https) {
            printf(STDERR "thruk_auth: basic auth redirects to %s\n", $authurl_https) if ($ENV{'THRUK_COOKIE_AUTH_VERBOSE'} && $ENV{'THRUK_COOKIE_AUTH_VERBOSE'} > 1);
            $config->{'cookie_auth_restricted_url'} = $authurl_https;
            return(verify_basic_auth($config, $basic_auth, $login));
        }
    }
    printf(STDERR "thruk_auth: basic auth code: %d\n", $res->code) if ($ENV{'THRUK_COOKIE_AUTH_VERBOSE'} && $ENV{'THRUK_COOKIE_AUTH_VERBOSE'} > 2);
    if($res->code == 200 and $res->decoded_content =~ m/^OK:\ (.*)$/mx) {
        if($1 eq Thruk::Authentication::User::transform_username($config, $login)) {
            return 1;
        }
    }
    printf(STDERR "thruk_auth: basic auth result: %s\n", $res->decoded_content) if ($ENV{'THRUK_COOKIE_AUTH_VERBOSE'} && $ENV{'THRUK_COOKIE_AUTH_VERBOSE'} > 3);
    if($res->code == 500 and $res->decoded_content =~ m/\Qtimeout during auth check\E/mx) {
        return -1;
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
    my $cookie_auth_session_timeout = $config->{'cookie_auth_session_timeout'};
    if($cookie_auth_session_timeout <= 0) {
        # clean old unused sessions after one year, even if they don't expire
        $cookie_auth_session_timeout = 365 * 86400;
    }
    my $timeout = time() - $cookie_auth_session_timeout;
    Thruk::Utils::IO::mkdir($sdir);
    opendir( my $dh, $sdir) or die "can't opendir '$sdir': $!";
    for my $entry (readdir($dh)) {
        next if $entry eq '.' or $entry eq '..';
        my $file = $sdir.'/'.$entry;
        my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
           $atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
        if($mtime && $mtime < $timeout) {
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
        $host = $host.':'.$port;
        return($host);
    }
    if($url =~ m/^(http|https):\/\/([^\/:]+):(\d+)\//mx) {
        my $port = $3;
        my $host = $2;
        $host = $host.':'.$port unless CORE::index($host, ':') != -1;
        return($host);
    }
    return('localhost:80');
}

##############################################

=head2 store_session

  store_session($config, $sessionid, $data)

store session data

=cut

sub store_session {
    my($config, $sessionid, $data) = @_;

    # store session key hashed
    my $type = $supported_digests->{$default_digest};
    my $digest = Digest->new($type);
    if(!$sessionid) {
        $digest->add(rand(1000000));
        $digest->add(time());
        $sessionid = $digest->hexdigest()."_".$default_digest;
        if(length($sessionid) != 66) { die("creating session id failed.") }
        $digest->reset();
    }
    $digest->add($sessionid);
    my $hashed_key = $digest->hexdigest();

    my $sdir = $config->{'var_path'}.'/sessions';
    die("only letters and numbers allowed") if $sessionid !~ m/^[a-z0-9_]+$/mx;
    my $sessionfile = $sdir.'/'.$hashed_key.'.'.$type;
    Thruk::Utils::IO::mkdir_r($sdir);
    Thruk::Utils::IO::json_lock_store($sessionfile, $data);
    return($sessionid, $sessionfile);
}

##############################################

=head2 retrieve_session

  retrieve_session(file => $sessionfile, config => $config)
  retrieve_session(id   => $sessionid,   config => $config)

returns session data as hash

    {
        id       => session id (if known),
        file     => session data file name,
        username => login name,
        active   => timestamp of last activity
        address  => remote address of user (optional)
        hash     => login hash from basic auth (optional)
        roles    => extra session roles (optional)
    }

=cut

sub retrieve_session {
    my(%args) = @_;
    my($sessionfile, $sessionid);
    my $config = $args{'config'} or confess("missing config");
    my($type, $hashed_key);
    if($args{'file'}) {
        $sessionfile = Thruk::Utils::basename($args{'file'});
        # REMOVE AFTER: 01.01.2020
        if($sessionfile =~ $hashed_key_file_regex) {
            $hashed_key = $1;
            $type       = substr($2, 1) if $2;
        } else {
            return;
        }
        if(!$type && length($hashed_key) < 64) {
            my($new_hashed_key, $newfile) = _upgrade_session_file($config, $hashed_key);
            if($newfile) {
                $sessionfile = Thruk::Utils::basename($newfile);
                $type        = $supported_digests->{$default_digest};
                $hashed_key  = $new_hashed_key;
            }
        }
    } else {
        my $nr;
        $sessionid = $args{'id'};
        if($sessionid =~ $session_key_regex) {
            $nr = substr($2, 1) if $2;
        } else {
            return;
        }
        if(!$nr) {
            # REMOVE AFTER: 01.01.2020
            if(length($sessionid) < 64) {
                _upgrade_session_file($config, $sessionid);
                $nr = $default_digest;
            }
            # /REMOVE AFTER
            else {
                return;
            }
        }
        $type = $supported_digests->{$nr};
    }
    return unless $type;

    if(!$hashed_key) {
        my $digest = Digest->new($type);
        $digest->add($sessionid);
        $hashed_key = $digest->hexdigest();
    }
    my $sdir = $config->{'var_path'}.'/sessions';
    $sessionfile = $sdir.'/'.$hashed_key.'.'.$type;

    my $data;
    return unless -e $sessionfile;
    my @stat = stat(_);
    eval {
        $data = Thruk::Utils::IO::json_lock_retrieve($sessionfile);
    };
    # REMOVE AFTER: 01.01.2020
    if(!$data) {
        my $raw = scalar read_file($sessionfile);
        chomp($raw);
        my($auth,$ip,$username,$roles) = split(/~~~/mx, $raw, 4);
        return unless defined $username;
        my @roles = defined $roles ? split(/,/mx,$roles) : ();
        $data = {
            address  => $ip,
            username => $username,
            hash     => $auth,
            roles    => \@roles,
        };
    }
    return unless defined $data;
    $data->{file}       = $sessionfile;
    $data->{hashed_key} = $hashed_key;
    $data->{digest}     = $type;
    $data->{active}     = $stat[9];
    $data->{roles}      = [] unless $data->{roles};
    return($data);
}

##############################################
# migrate session from old md5hex to current format
# REMOVE AFTER: 01.01.2020
sub _upgrade_session_file {
    my($config, $sessionid) = @_;
    my $folder = $config->{'var_path'}.'/sessions';
    return unless -e $folder.'/'.$sessionid;
    my $type   = $supported_digests->{$default_digest};
    my $digest = Digest->new($type);
    $digest->add($sessionid);
    my $hashed_key = $digest->hexdigest();
    my $newfile = $folder.'/'.$hashed_key.'.'.$type;
    move($folder.'/'.$sessionid, $newfile);
    return($hashed_key, $newfile);
}

1;
