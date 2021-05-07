#!/usr/bin/env perl

use warnings;
use strict;
use Test::More;
use utf8;

use Thruk::Utils::IO ();

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan tests => 17;

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
# REMOVE AFTER: 01.01.2022
{
    # test upgrading existing sessions
    my $hash        = 'b21kYWRtaW46b21k';
    my $sessionid   = '8e87a0aff175849ba1335f6383b85050';
    my $sessiondir  = $c->config->{'var_path'}.'/sessions';
    my $sessionfile = $sessiondir.'/'.$sessionid;
    open(my $fh, '>', $sessionfile) or die("cannot write $sessionfile: $!");
    print $fh $hash."~~~127.0.0.1~~~omdadmin\n";
    close($fh);
    my $session = Thruk::Utils::CookieAuth::retrieve_session(id => $sessionid, config => $c->config);
    is($session->{'username'}, 'omdadmin', "got session file");
    is($session->{'private_key'}, $sessionid, "got session id");
    is($session->{'hash'}, $hash, "got basic auth hash");
    ok(! -f $sessionfile, 'session should have been migrated');
    ok(-f $session->{'file'}, 'session should have been migrated');

    my $session2 = Thruk::Utils::CookieAuth::retrieve_session(id => $sessionid, config => $c->config);
    is($session2->{'username'}, 'omdadmin', "got session file");
    is($session2->{'private_key'}, $sessionid, "got session id");
    is($session2->{'hash'}, $hash, "got basic auth hash");

    unlink($session->{'file'});
}
# /REMOVE
#########################
