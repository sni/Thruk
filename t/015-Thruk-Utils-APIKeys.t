#!/usr/bin/env perl

use warnings;
use strict;
use Test::More;
use utf8;

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan tests => 5;

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
