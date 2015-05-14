#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib 'lib';
use Thruk::Backend::Pool;

###################################################
# create connection pool
# has to be done really early to save memory
BEGIN {
    $ENV{'THRUK_SRC'} = 'FastCGI';
    $ENV{'PLACK_ENV'} = 'deployment' unless $ENV{'PLACK_ENV'};
    Thruk::Backend::Pool::init_backend_thread_pool();
}

use Plack::Handler::FCGI;
use Thruk;
my $server = Plack::Handler::FCGI->new(
    nproc  => 1,
    detach => 1,
);
$server->run(Thruk->startup);
