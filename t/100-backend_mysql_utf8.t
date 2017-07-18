use strict;
use warnings;
use Test::More;

plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
plan skip_all => 'Set $ENV{TEST_MYSQL} to a test database connection.' unless $ENV{TEST_MYSQL};
plan skip_all => 'broken on travis right atm' if $ENV{TEST_TRAVIS};
plan tests => 14;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

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
isnt($prefix, undef, 'got peer key: '.$prefix) or BAIL_OUT("got no peer key, cannot test");
my $peer     = $c->{'db'}->get_peer_by_key($prefix);
isnt($peer, undef, 'got backend by key');
$peer->{'_logcache'} = $m;
$m->{'_peer'} = $m;

#####################################################################
# import data
Thruk::Backend::Provider::Mysql::_drop_tables($dbh, $prefix);
Thruk::Backend::Provider::Mysql::_create_tables($dbh, $prefix);
my($logcount) = $m->_update_logcache($c, $mode, $peer, $dbh, $prefix, $verbose, $blocksize, $files);
is($logcount, 10, 'imported all items from '.$files->[0]);

#####################################################################
# check duplicate detection
($logcount) = $m->_update_logcache($c, $mode, $peer, $dbh, $prefix, $verbose, $blocksize, $files);
is($logcount, 0, 'don\'t import duplicates '.$files->[0]);

#####################################################################
my($tempfile) = $m->get_logs(file => 1, collection => $prefix, sort => { 'ASC' => 'time'});
is(-f $tempfile, 1, $tempfile.' exists');
TestUtils::test_command({
    cmd   => '/usr/bin/diff -u '.$tempfile.' '.$files->[0],
    like => ['/^$/'],
});
unlink($tempfile);

#####################################################################
# clean up
Thruk::Backend::Provider::Mysql::_drop_tables($dbh, $prefix);
$dbh->disconnect();
