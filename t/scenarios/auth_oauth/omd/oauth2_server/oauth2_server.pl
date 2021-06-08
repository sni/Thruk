#!/usr/bin/perl

use warnings;
use strict;
use utf8;

BEGIN {
    $ENV{DANCER_ENVIRONMENT} = 'config';
}
use Dancer2;
use Dancer2::Plugin::OAuth2::Server;

get '/oauth/userinfo' => oauth_scopes 'openid' => sub {
    return to_json { login => "clientö" };
};

dance;
