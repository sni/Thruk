use warnings;
use strict;
use Cwd ();
use File::Temp qw/tempfile/;
use Test::More;

use Thruk::Base ();
use Thruk::Utils::Encode ();
use Thruk::Utils::IO ();

plan skip_all => 'backends required' if(!-s ($ENV{'THRUK_CONFIG'} || '.').'/thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
plan skip_all => 'Set $ENV{TEST_MYSQL} to a test database connection.' unless $ENV{TEST_MYSQL};
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
my $m = Thruk::Backend::Provider::Mysql->new({options => {peer => $ENV{'TEST_MYSQL'}, peer_key => 'abcd'}});
isa_ok($m, 'Thruk::Backend::Provider::Mysql');

my($res, $c)    = ctx_request('/thruk/main.html');
my $mode        = 'update';
my $files       = [Cwd::getcwd().'/t/data/mysql/archive.log'];
my $verbose     = 1;
my $dbh         = $m->_dbh;
my $blocksize   = undef;

#####################################################################
# create tables
Thruk::Action::AddDefaults::set_possible_backends($c, {});
my $backends = $c->stash->{'backends'};
$backends    = Thruk::Base::list($backends);
my $prefix   = $backends->[0];
isnt($prefix, undef, 'got peer key: '.$prefix) or BAIL_OUT("got no peer key, cannot test");
my $peer     = $c->db->get_peer_by_key($prefix);
isnt($peer, undef, 'got backend by key');
$peer->{'_logcache'} = $m;
$m->{'_peer'} = $m;

#####################################################################
# import data
{
    local $ENV{THRUK_QUIET} = 1;
    Thruk::Backend::Provider::Mysql::_drop_tables($dbh, $prefix);
    Thruk::Backend::Provider::Mysql::_create_tables($dbh, $prefix);
    my($logcount) = $m->_update_logcache($c, $mode, $peer, $dbh, $prefix, $blocksize, $files);
    is($logcount, 10, 'imported all items from '.$files->[0]);
};

#####################################################################
# check duplicate detection
{
    local $ENV{THRUK_QUIET} = 1;
    my($logcount) = $m->_update_logcache($c, $mode, $peer, $dbh, $prefix, $blocksize, $files);
    is($logcount, 0, 'don\'t import duplicates '.$files->[0]);
};

#####################################################################
my($tempfile) = $m->get_logs(file => 1, collection => $prefix, sort => { 'ASC' => 'time'});
is(-f $tempfile, 1, $tempfile.' exists');
my $cont = Thruk::Utils::IO::read($files->[0]);
Thruk::Utils::Encode::decode_any($cont);
Thruk::Utils::Encode::remove_utf8_surrogates($cont);
utf8::encode($cont);
my($fh, $file2) = tempfile();
CORE::close($fh);
Thruk::Utils::IO::write($file2, $cont);
TestUtils::test_command({
    cmd   => '/usr/bin/diff -u '.$tempfile.' '.$file2,
    like => ['/^$/'],
});
unlink($tempfile);
unlink($file2);

#####################################################################
# clean up
Thruk::Backend::Provider::Mysql::_drop_tables($dbh, $prefix);
$dbh->disconnect();
