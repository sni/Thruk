use strict;
use warnings;
use Data::Dumper;
use Test::More;
$Data::Dumper::Sortkeys = 1;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
plan skip_all => 'Set $ENV{TEST_MYSQL} to a test database connection.' unless $ENV{TEST_MYSQL};
plan tests => 14;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use Catalyst::Test 'Thruk';
use_ok('Thruk::Backend::Provider::Mysql');
use_ok('Thruk::Config');
use_ok('Thruk::Action::AddDefaults');
use_ok('Thruk::Utils');

#####################################################################
# create connection
my $m = Thruk::Backend::Provider::Mysql->new({peer => $ENV{'TEST_MYSQL'}});
isa_ok($m, 'Thruk::Backend::Provider::Mysql');

my($res, $c)    = ctx_request('/thruk/side.html');
my $mode        = 'update';
my $files       = ['t/data/mysql/archive.log'];
my $verbose     = 1;
my $dbh         = $m->_dbh;
my $blocksize   = undef;

#####################################################################
# create tables
Thruk::Action::AddDefaults::_set_possible_backends($c, {});
my $backends = $c->stash->{'backends'};
$backends    = Thruk::Utils::list($backends);
my $prefix   = $backends->[0];
isnt($prefix, undef, 'got peer key: '.$prefix);
my $peer     = $c->{'db'}->get_peer_by_key($prefix);
isnt($peer, undef, 'got backend by key');
$peer->{'logcache'} = $m;
$peer->{'class'}->{'logcache'} = $m;

#####################################################################
# import data
$m->_drop_tables($dbh, $prefix);
$m->_create_tables($dbh, $prefix);
my($logcount) = $m->_update_logcache($c, $mode, $peer, $dbh, $prefix, $verbose, $blocksize, $files);
is($logcount, 5, 'imported all items from '.$files->[0]);

#####################################################################
# check duplicate detection
($logcount) = $m->_update_logcache($c, $mode, $peer, $dbh, $prefix, $verbose, $blocksize, $files);
is($logcount, 0, 'don\'t import duplicates '.$files->[0]);

#####################################################################
my($tempfile) = $m->get_logs(file => 1, collection => $prefix);
is(-f $tempfile, 1, $tempfile.' exists');
TestUtils::test_command({
    cmd   => '/usr/bin/diff -u '.$tempfile.' '.$files->[0],
    like => ['/^$/'],
});
unlink($tempfile);

#####################################################################
# clean up
$m->_drop_tables($dbh, $prefix);
$dbh->disconnect();
