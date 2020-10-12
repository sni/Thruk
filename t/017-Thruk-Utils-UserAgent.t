#!/usr/bin/env perl

use warnings;
use strict;
use Test::More;

BEGIN {
    plan tests => 8;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok('Thruk');
use_ok('Thruk::UserAgent');

my $c = TestUtils::get_c();

#########################
{
    local $c->config->{'use_curl'} = 0;
    my $ua = Thruk::UserAgent->new({}, $c->config);
    isa_ok($ua, 'LWP::UserAgent');

    my $res = $ua->get("http://127.0.0.1:12345");
    isa_ok($res, 'HTTP::Response');

    $res = $ua->post("http://127.0.0.1:12345", {});
    isa_ok($res, 'HTTP::Response');
};

#########################
{
    local $c->config->{'use_curl'} = 1;
    my $ua = Thruk::UserAgent->new({}, $c->config);
    isa_ok($ua, 'Thruk::UserAgent');

    my $res = $ua->get("http://127.0.0.1:12345");
    isa_ok($res, 'HTTP::Response');

    $res = $ua->post("http://127.0.0.1:12345", {});
    isa_ok($res, 'HTTP::Response');
};