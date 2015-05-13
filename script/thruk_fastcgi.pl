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
    Thruk::Backend::Pool::init_backend_thread_pool();
}

push @ARGV, '-s', 'FCGI';
push @ARGV, '--no-default-middleware';
unshift(@ARGV, $Bin.'/thruk.psgi');

require Plack::Runner;
my $runner = Plack::Runner->new;
$runner->parse_options(@ARGV);
$runner->run;
