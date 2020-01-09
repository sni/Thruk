#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';

###################################################
# create connection pool
# has to be done really early to save memory
BEGIN {
    $ENV{'THRUK_SRC'} = 'FastCGI';
    use Thruk::Backend::Pool;
    Thruk::Backend::Pool::init_backend_thread_pool();
}

use Plack::Handler::FCGI ();
use Thruk;
my $server = Plack::Handler::FCGI->new(
    nproc  => 1,
    detach => 1,
);
$server->run(Thruk->startup);
