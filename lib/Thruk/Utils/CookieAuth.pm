package Thruk::Utils::CookieAuth;

=head1 NAME

Thruk::Utils::CookieAuth - Utilities Collection for Cookie Authentication

=head1 DESCRIPTION

Cookie Authentication offers a nice login mask and makes it possible
to logout again.

=cut

use warnings;
use strict;
use Carp qw/confess/;
use Encode qw/encode_utf8/;

use Thruk::Authentication::User ();
use Thruk::UserAgent ();
use Thruk::Utils ();
use Thruk::Utils::Crypt ();
use Thruk::Utils::Log qw/:all/;

##############################################
my $hashed_key_file_regex = qr/^([a-zA-Z0-9]+)(\.[A-Z]+\-\d+|)$/mx;
my $session_key_regex     = qr/^([a-zA-Z0-9]+)(|_\d{1})$/mx;

##############################################

=head1 METHODS

=head2 external_authentication

    external_authentication($config, $login, $pass, $address, [$stats], [$create_session_file])

verify authentication by external login into external url.

set $create_session_file to 0 to disabled creating a session file and only return session data itself.

return:

    sid  if login was ok
    0    if login failed
   -1    on technical problems

=cut
sub external_authentication {
    my($config, $login, $pass, $address, $stats, $create_session_file) = @_;
    my $authurl  = $config->{'cookie_auth_restricted_url'};
    my $sdir     = $config->{'var_path'}.'/sessions';
    Thruk::Utils::IO::mkdir($sdir);

    my $netloc = Thruk::Utils::CookieAuth::get_netloc($authurl);
    my $ua     = get_user_agent($config);
    # unset proxy which eventually has been set from https backends
    local $ENV{'HTTPS_PROXY'} = undef if exists $ENV{'HTTPS_PROXY'};
    local $ENV{'HTTP_PROXY'}  = undef if exists $ENV{'HTTP_PROXY'};
    # bypass ssl host verfication on localhost
    Thruk::UserAgent::disable_verify_hostname_by_url($ua, $authurl);
    $stats->profile(begin => "ext::auth: post1 ".$authurl) if $stats;
    my $res      = $ua->post($authurl);
    $stats->profile(end   => "ext::auth: post1 ".$authurl) if $stats;
    _debug("auth post1:\n%s\n", $res->as_string()) if ($ENV{'THRUK_COOKIE_AUTH_VERBOSE'} && $ENV{'THRUK_COOKIE_AUTH_VERBOSE'} > 3);
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
                $login = encode_utf8(Thruk::Utils::Encode::ensure_utf8($login));
                $pass  = encode_utf8(Thruk::Utils::Encode::ensure_utf8($pass));
                $ua->credentials( $netloc, $realm, $login, $pass );
            }
            $stats->profile(begin => "ext::auth: post2 ".$authurl) if $stats;
            $res = $ua->post($authurl);
            $stats->profile(end   => "ext::auth: post2 ".$authurl) if $stats;
            _debug("auth post2:\n%s\n", $res->as_string()) if ($ENV{'THRUK_COOKIE_AUTH_VERBOSE'} && $ENV{'THRUK_COOKIE_AUTH_VERBOSE'} > 3);
            if($res->code == 200 and $res->request->header('authorization') and $res->decoded_content =~ m/^OK:\ (.*)$/mx) {
                if(ref $login eq 'HASH') { $login = $1; }
                if($1 eq Thruk::Authentication::User::transform_username($config, $login)) {
                    my $hash = $res->request->header('authorization');
                    $hash =~ s/^Basic\ //mx;
                    $hash = 'none' if $config->{'cookie_auth_session_cache_timeout'} == 0;
                    my $session = store_session($config, undef, {
                        hash       => $hash,
                        address    => $address,
                        username   => $login,
                    }, $create_session_file);
                    return $session;
                }
            } else {
                $login = '(by basic auth hash)' if ref $login eq 'HASH';
                print STDERR 'authorization failed for user ', $login,' got rc ', $res->code, "\n";
                return 0;
            }
        } else {
            print STDERR 'auth: realm does not match, got ', $realm, "\n";
        }
    } else {
        print STDERR 'auth: expected code 401, got ', $res->code, "\n", Thruk::Utils::dump_params($res);
    }
    return -1;
}

##############################################

=head2 verify_basic_auth

    verify_basic_auth($config, $basic_auth, $login, $timeout, $revalidation)

verify authentication by sending request with basic auth header.

returns  1 if authentication was successfull
returns -1 on timeout error
returns  0 if unsuccessful

=cut
sub verify_basic_auth {
    my($config, $basic_auth, $login, $timeout, $revalidation) = @_;
    confess("no basic auth data to verify") unless $basic_auth;
    my $authurl  = $config->{'cookie_auth_restricted_url'};

    # unset proxy which eventually has been set from https backends
    local $ENV{'HTTPS_PROXY'} = undef if exists $ENV{'HTTPS_PROXY'};
    local $ENV{'HTTP_PROXY'}  = undef if exists $ENV{'HTTP_PROXY'};

    my $ua = get_user_agent($config);
    $ua->timeout($timeout) if $timeout;
    # bypass ssl host verfication on localhost
    Thruk::UserAgent::disable_verify_hostname_by_url($ua, $authurl);
    $ua->default_header( 'Authorization' => 'Basic '.$basic_auth );
    _debug("basic auth request for %s to %s\n", $login, $authurl) if ($ENV{'THRUK_COOKIE_AUTH_VERBOSE'} && $ENV{'THRUK_COOKIE_AUTH_VERBOSE'} > 1);
    my $res = $ua->post($authurl);
    if($res->code == 302 && $authurl =~ m|^http:|mx) {
        (my $authurl_https = $authurl) =~ s|^http:|https:|gmx;
        if($res->{'_headers'}->{'location'} eq $authurl_https) {
            _debug("basic auth redirects to %s\n", $authurl_https) if ($ENV{'THRUK_COOKIE_AUTH_VERBOSE'} && $ENV{'THRUK_COOKIE_AUTH_VERBOSE'} > 1);
            $config->{'cookie_auth_restricted_url'} = $authurl_https;
            return(verify_basic_auth($config, $basic_auth, $login, $revalidation));
        }
    }
    _debug("basic auth code: %d\n", $res->code) if ($ENV{'THRUK_COOKIE_AUTH_VERBOSE'} && $ENV{'THRUK_COOKIE_AUTH_VERBOSE'} > 2);
    if($res->code == 200 and $res->decoded_content =~ m/^OK:\ (.*)$/mx) {
        if($1 eq Thruk::Authentication::User::transform_username($config, $login)) {
            return 1;
        }
    }
    _debug("basic auth result: %s\n", $res->decoded_content) if ($ENV{'THRUK_COOKIE_AUTH_VERBOSE'} && $ENV{'THRUK_COOKIE_AUTH_VERBOSE'} > 3);
    if($revalidation) {
        if($res->code < 400 || $res->code >= 500) {
            # do not log out on temporary errors...
            return 1;
        }
    }
    if($res->code == 500 && $res->decoded_content =~ m/(\Qtimeout during auth check\E|\Qread timeout at\E)/mx) {
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
    my $ua = Thruk::UserAgent->new({}, $config);
    $ua->timeout(30);
    $ua->agent("thruk_auth");
    return $ua;
}

##############################################

=head2 clean_session_files

    clean_session_files($c)

clean up session files

=cut
sub clean_session_files {
    my($c) = @_;
    die("no config") unless $c;

    $c->stats->profile(begin => "clean_session_files");

    my($total, $cleaned) = (0, 0);
    my $sdir    = $c->config->{'var_path'}.'/sessions';
    my $cookie_auth_session_timeout = $c->config->{'cookie_auth_session_timeout'};
    if($cookie_auth_session_timeout <= 0) {
        # clean old unused sessions after one year, even if they don't expire
        $cookie_auth_session_timeout = 365 * 86400;
    }
    my $timeout = time() - $cookie_auth_session_timeout;
    my $fake_session_timeout = time() - 600;
    Thruk::Utils::IO::mkdir($sdir);
    my $sessions_by_user = {};
    opendir( my $dh, $sdir) or die "can't opendir '$sdir': $!";
    for my $entry (readdir($dh)) {
        next if $entry eq '.' or $entry eq '..';
        $total++;
        my $file = $sdir.'/'.$entry;
        my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
           $atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
        if($mtime) {
            if($mtime < $timeout) {
                my $data;
                eval {
                    $data = Thruk::Utils::IO::json_lock_retrieve($file);
                };
                _warn($@) if $@;
                _audit_log("session", "session timeout hit, removing session file", $data->{'username'}//'?', $entry, 0);
                unlink($file);
                $cleaned++;
            }
            elsif($mtime < $fake_session_timeout) {
                eval {
                    my $data;
                    eval {
                        $data = Thruk::Utils::IO::json_lock_retrieve($file);
                    };
                    _warn($@) if $@;
                    if($data && $data->{'fake'}) {
                        _audit_log("session", "short session timeout hit, removing session file", $data->{'username'}//'?', $entry, 0);
                        unlink($file);
                        $cleaned++;
                    } elsif(defined $data->{'username'}) {
                        $sessions_by_user->{$data->{'username'}}->{$file} = $mtime;
                    }
                };
            }
        }
    }

    # limit sessions to 500 per user
    my $max_sessions_per_user = 500;
    for my $user (sort keys %{$sessions_by_user}) {
        my $user_sessions = $sessions_by_user->{$user};
        my $num = scalar keys %{$user_sessions};
        if($num > $max_sessions_per_user) {
            _warn(sprintf("user %s has %d open sessions (max. %d) cleaning up.", $user, $num, $max_sessions_per_user));
            for my $file (reverse sort { $user_sessions->{$b} <=> $user_sessions->{$a} } keys %{$user_sessions}) {
                if($num > $max_sessions_per_user) {
                    my $entry = $file;
                    $entry =~ s|^.*/||gmx;
                    _audit_log("session", "max session reached, cleaning old session", $user, $entry, 0);
                    unlink($file);
                    $cleaned++;
                    $num--;
                } else {
                    last;
                }
            }
        }
    }

    $c->stats->profile(end => "clean_session_files");

    return($total, $cleaned);
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

  store_session($config, $sessionid, $data, [$create_session_file])

store session data

=cut

sub store_session {
    my($config, $sessionid, $data, $create_session_file) = @_;

    # store session key hashed
    my($hashed_key, $digest_name);
    ($sessionid,$hashed_key,$digest_name) = generate_sessionid($sessionid);

    $data->{'csrf_token'} = Thruk::Utils::Crypt::random_uuid([$sessionid]) unless $data->{'csrf_token'};
    delete $data->{'private_key'};
    delete $data->{'file'};
    my $hash_raw  = delete $data->{'hash_raw'};
    my $hash_orig;

    confess("no username") unless $data->{'username'};

    # store basic auth hash crypted with the private session id
    if($data->{'hash'} && $data->{'hash'} ne 'none') {
        $hash_orig = $data->{'hash'};
        if($hash_raw) {
            # no need to recrypt every time
            $data->{'hash'} = $hash_raw;
        } else {
            $data->{'hash'} = Thruk::Utils::Crypt::encrypt($sessionid, $data->{'hash'});
        }
    }

    die("only letters and numbers allowed") if $sessionid !~ m/^[a-z0-9_]+$/mx;
    my $sdir = $config->{'var_path'}.'/sessions';
    my $sessionfile = $sdir.'/'.$hashed_key.'.'.$digest_name;
    if(!defined $create_session_file || $create_session_file) {
        Thruk::Utils::IO::mkdir_r($sdir);
        Thruk::Utils::IO::json_lock_store($sessionfile, $data);
    }

    # restore some keys which should not be stored
    $data->{'private_key'} = $sessionid;
    $data->{'hash_raw'}    = $hash_raw if $hash_raw;
    $data->{'hash'}        = $hash_orig if $hash_orig;
    $data->{'file'}        = $sessionfile;
    $data->{'hashed_key'}  = $hashed_key;

    if(defined $Thruk::Globals::c) {
        _audit_log("session", "session created", $data->{'username'}, $hashed_key, 0);
    }

    return($data);
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
    my($digest_name, $hashed_key);
    if($args{'file'}) {
        $sessionfile = Thruk::Base::basename($args{'file'});
        if($sessionfile =~ $hashed_key_file_regex) {
            $hashed_key  = $1;
            $digest_name = substr($2, 1) if $2;
        } else {
            return;
        }
        if(!$digest_name && length($hashed_key) < 64) {
            return;
        }
    } else {
        my $digest_nr;
        $sessionid = $args{'id'};
        if($sessionid =~ $session_key_regex) {
            $digest_nr = substr($2, 1) if $2;
        } else {
            return;
        }
        return unless $digest_nr;
        $digest_name = Thruk::Utils::Crypt::digest_name($digest_nr) unless $digest_name;
    }
    return unless $digest_name;

    if(!$hashed_key) {
        $hashed_key = Thruk::Utils::Crypt::hexdigest($sessionid, $digest_name);
    }
    my $sdir = $config->{'var_path'}.'/sessions';
    $sessionfile = $sdir.'/'.$hashed_key.'.'.$digest_name;

    my $data;
    return unless -e $sessionfile;
    my @stat = stat(_);
    eval {
        $data = Thruk::Utils::IO::json_lock_retrieve($sessionfile);
    };
    my $err = $@;
    _warn("failed to read sessionfile: $sessionfile: $err") if $err;

    return unless defined $data;

    if($sessionid && $data->{hash}) {
        # try to decrypt from private key (can be skipped for old sessions)
        my $decrypted = Thruk::Utils::Crypt::decrypt($sessionid, $data->{'hash'});
        $data->{'hash'} = $decrypted if $decrypted;
    }
    $data->{file}        = $sessionfile;
    $data->{hashed_key}  = $hashed_key;
    $data->{digest}      = $digest_name;
    $data->{active}      = $stat[9];
    $data->{roles}       = [] unless $data->{roles};
    $data->{private_key} = $sessionid if $sessionid;

    return($data);
}

##############################################

=head2 generate_sessionid

  generate_sessionid([$sessionid])

returns random sessionid along with the hashed key and the hash type

  returns $sessionid, $hashed_key, $digest_name

=cut

sub generate_sessionid {
    my($sessionid) = @_;
    $sessionid = Thruk::Utils::Crypt::random_uuid() unless $sessionid;
    my($hashed_key, $digest_nr, $digest_name) = Thruk::Utils::Crypt::hexdigest($sessionid);
    return($sessionid, $hashed_key, $digest_name);
}

##############################################

=head2 private2hashed

  private2hashed($sessionid)

returns hashed_key for given private key

  returns $hashed_key, $digest_name

=cut

sub private2hashed {
    my($sessionid) = @_;
    my $digest_nr;
    if($sessionid =~ $session_key_regex) {
        $digest_nr = substr($2, 1) if $2;
    } else {
        return;
    }
    my $digest_name = Thruk::Utils::Crypt::digest_name($digest_nr);
    my $hashed_key  = Thruk::Utils::Crypt::hexdigest($sessionid, $digest_name);
    return($hashed_key, $digest_name);
}

1;
