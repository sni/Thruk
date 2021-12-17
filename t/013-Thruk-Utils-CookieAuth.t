#!/usr/bin/env perl

use warnings;
use strict;
use Test::More;
use utf8;

use Thruk::Utils::IO ();

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan tests => 9;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok('Thruk::Utils::CookieAuth');

#########################
my $c = TestUtils::get_c();

#########################
{
    my($sessionid,$hashed_key) = Thruk::Utils::CookieAuth::generate_sessionid();
    my $data = {
      'hash'     => 'test',
      'username' => 'user',
    };
    my $data2 = Thruk::Utils::CookieAuth::store_session($c->config, $sessionid, $data);
    my $sessionid2  = $data2->{'private_key'};
    my $sessionfile = $data2->{'file'};
    is($sessionid2, $sessionid, "session id did not change: ".$sessionid2);
    isnt($sessionfile, undef, "got file: ".$sessionfile);
    is($data2->{'hash'}, $data->{'hash'}, "basic auth hash is untouched");

    $data2 = Thruk::Utils::IO::json_lock_retrieve($sessionfile);
    like($data2->{'hash'}, '/^CBC,.+/', "basic auth hash is stored crypted");

    my $session2 = Thruk::Utils::CookieAuth::retrieve_session(id => $sessionid, config => $c->config);
    is($session2->{'file'}, $sessionfile, "got session file");
    is($session2->{'hash'}, "test", "hash has been decrypted");

    # read session by file
    my $session3 = Thruk::Utils::CookieAuth::retrieve_session(file => $sessionfile, config => $c->config);
    is($session3->{'file'}, $sessionfile, "got session file");
    like($session3->{'hash'}, '/^CBC,.+/', "basic auth hash is still crypted");

    unlink($sessionfile);
};
#########################
