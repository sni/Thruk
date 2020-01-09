#!/usr/bin/env perl

use warnings;
use strict;
use utf8;
use Test::More;

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan tests => 16;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok('Thruk::Utils::APIKeys');

#########################
my $c = TestUtils::get_c();

#########################
{
    my($username, $comment, $roles, $system) = ('test', 'comment', [], 0);
    my($privatekey, $hashed_key, $file) = Thruk::Utils::APIKeys::create_key($c, $username, $comment, $roles, $system);
    ok(-f $file, 'api key created');
    my $apikey = Thruk::Utils::APIKeys::get_key_by_private_key($c->config, $privatekey);
    is($apikey->{'user'}, $username, "got api key user");
    is($apikey->{'comment'}, $comment, "got api key comment");
    is($apikey->{'file'}, $file, "got api key file");
    unlink($file);
}

#########################
# REMOVE AFTER: 01.01.2022
{
    # test upgrading existing api keys
    my $username   = 'test';
    my $privatekey = '8e87a0aff175849ba1335f6383b85050';
    my $keydir     = $c->config->{'var_path'}.'/api_keys';
    my $keyfile    = $keydir.'/'.$privatekey;
    open(my $fh, '>', $keyfile) or die("cannot write $keyfile: $!");
    print $fh "{'user':'".$username."'}\n";
    close($fh);
    ok(-f $keyfile, 'old api key created');

    my $apikey = Thruk::Utils::APIKeys::get_key_by_private_key($c->config, $privatekey);
    is($apikey->{'user'}, $username, "got api key user");
    ok(!-f $keyfile, 'old api key migrated');
    ok(-f $apikey->{'file'}, 'old api key migrated');

    my $apikey2 = Thruk::Utils::APIKeys::get_key_by_private_key($c->config, $privatekey);
    is($apikey2->{'user'}, $username, "got api key user");
    ok(!-f $keyfile, 'old api key migrated');
    ok(-f $apikey->{'file'}, 'old api key migrated');

    unlink($apikey->{'file'});

    # test upgrading existing api keys II
    open($fh, '>', $keyfile) or die("cannot write $keyfile: $!");
    print $fh "{'user':'".$username."'}\n";
    close($fh);
    ok(-f $keyfile, 'old api key created');

    $apikey = Thruk::Utils::APIKeys::read_key($c->config, $keyfile);
    is($apikey->{'user'}, $username, "got api key user");
    ok(!-f $keyfile, 'old api key migrated');
    ok(-f $apikey->{'file'}, 'old api key migrated');

    unlink($apikey->{'file'});
}
# /REMOVE AFTER
#########################
