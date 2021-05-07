#!/usr/bin/env perl

use warnings;
use strict;

use lib 'lib';

###################################################
# create connection pool
# has to be done really early to save memory
my $pool;
BEGIN {
    $ENV{'THRUK_MODE'} = 'FASTCGI';
    use Thruk::Backend::Pool;
    $pool = Thruk::Backend::Pool->new();
}

use Plack::Handler::FCGI ();

use Thruk ();

my $server = Plack::Handler::FCGI->new(
    nproc  => 1,
    detach => 1,
);
$server->run(Thruk->startup($pool));
