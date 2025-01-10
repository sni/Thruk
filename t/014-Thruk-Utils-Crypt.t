#!/usr/bin/env perl

use warnings;
use strict;
use Test::More;
use utf8;

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan tests => 75;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok('Thruk::Utils::Crypt');

#########################
{
    my $teststrings = ['', ' ', 'a', 'test', '$`+*öäü&', 'x' x 1000];
    for my $s1 (@{$teststrings}) {
        for my $s2 (@{$teststrings}) {
            my $key       = $s1;
            my $orig      = $s2;
            my $data      = $s2;
            my $crypted   = Thruk::Utils::Crypt::encrypt($key, $data);
            like($crypted, '/^CBC,.+/', "data is crypted");
            my $decrypted = Thruk::Utils::Crypt::decrypt($key, $crypted);
            is($decrypted, $orig, "decrypted string is ok");
        }
    }
};

my $b1 = Thruk::Utils::Crypt::get_random_bytes(16);
my $b2 = Thruk::Utils::Crypt::get_random_bytes(16);
is(length($b1), 16, 'random length is ok');
ok($b1 ne $b2, "randomness differs");
