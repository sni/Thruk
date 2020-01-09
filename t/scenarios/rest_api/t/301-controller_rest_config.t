use strict;
use warnings;
use Test::More;
use Cpanel::JSON::XS qw/decode_json/;

die("*** ERROR: this test is meant to be run with PLACK_TEST_EXTERNALSERVER_URI set") unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

BEGIN {
    plan tests => 236;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok 'Thruk::Controller::rest_v1';
TestUtils::set_test_user_token();
my($host,$service) = ('localhost', 'Users');
my($hostgroup,$servicegroup) = ('Everything', 'Http Check');

my $pages = [{
# force reschedule so we get some performance data
        url     => 'POST /hosts/<name>/cmd/schedule_forced_host_check',
        post    => { start_time => 'now' },
        like    => ['Command successfully submitted'],
    }, {
        url     => 'GET /hosts/<name>',
        waitfor => 'rta_unit',
    }, {
        url     => 'GET /hosts/<name>',
        like    => ['"rta_unit" : "ms",', '"rta" : "\d+\.\d+', ''],
    }, {
# verify configuration from config tool
        url     => 'GET /hosts/<name>/config',
        like    => ['"alias" : "localhost",', '"address" : "127.0.0.1",', '/omd/sites/demo/etc/naemon/conf.d/example.cfg:1'],
    }, {
        url     => 'GET /hostgroups/'.$hostgroup.'/config',
        like    => ['Just all hosts'],
    }, {
        url     => 'GET /servicegroups/'.$servicegroup.'/config',
        like    => ['Http Checks'],
    }, {
# change a few things
        url     => 'PATCH /hosts/<name>/config',
        post    => {address => '127.0.0.2', max_check_attempts => 5, icon_image => undef },
        like    => ['changed 1 objects successfully.'],
    }, {
        url     => 'GET /hosts/<name>/config',
        like    => ['"alias" : "localhost",', '"address" : "127.0.0.2",', '/omd/sites/demo/etc/naemon/conf.d/example.cfg:1'],
        unlike  => ['icon_image'],
    }, {
        url     => 'GET /config/diff',
        like    => ['/omd/sites/demo/etc/naemon/conf.d/example.cfg', 'max_check_attempts'],
    }, {
        url     => 'POST /config/check',
        post    => {},
        like    => ['"failed" : false,', 'Running configuration check'],
    }, {
        url     => 'POST /config/save',
        post    => {},
        like    => ['successfully saved changes for 1 site.'],
    }, {
        url     => 'POST /config/reload',
        post    => {},
        like    => ['"failed" : false'],
    }, {
        url     => 'GET /hosts/<name>/config',
        like    => ['"alias" : "localhost",', '"address" : "127.0.0.2",', '/omd/sites/demo/etc/naemon/conf.d/example.cfg:1'],
        unlike  => ['icon_image'],
    }, {
        url     => 'GET /hosts/<name>',
        like    => ['"alias" : "localhost",', '"address" : "127.0.0.2",'],
    }, {
# try reverting changes
        url     => 'PATCH /hosts/<name>/config',
        post    => {address => '127.0.0.1', max_check_attempts => undef, icon_image => "linux40.png" },
        like    => ['changed 1 objects successfully.'],
    }, {
        url     => 'GET /config/diff',
        like    => ['/omd/sites/demo/etc/naemon/conf.d/example.cfg', 'linux40.png'],
    }, {
        url     => 'POST /config/revert',
        post    => {},
        like    => ['successfully reverted stashed changes for 1 site.'],
    }, {
# try deleting things
        url     => 'DELETE /hosts/<name>/config',
        post    => {},
        like    => ['removed 1 objects successfully.'],
    }, {
        url     => 'GET /config/diff',
        like    => ['/omd/sites/demo/etc/naemon/conf.d/example.cfg', '-\s*alias'],
    }, {
        url     => 'POST /config/revert',
        post    => {},
        like    => ['successfully reverted stashed changes for 1 site.'],
    }, {
# finally revert host back to start
        url     => 'PATCH /hosts/<name>/config',
        post    => {address => '127.0.0.1', max_check_attempts => undef, icon_image => "linux40.png" },
        like    => ['changed 1 objects successfully.'],
    }, {
        url     => 'POST /config/save',
        post    => {},
        like    => ['successfully saved changes for 1 site.'],
    }, {
        url     => 'POST /config/reload',
        post    => {},
        like    => ['"failed" : false'],
    }, {
        url     => 'GET /hosts/<name>/config',
        like    => ['"alias" : "localhost",', '"address" : "127.0.0.1",', '/omd/sites/demo/etc/naemon/conf.d/example.cfg:1', 'linux40.png'],
    }, {
        url     => 'GET /config/files',
        like    => ['/etc/naemon/conf.d/thruk_bp_generated.cfg', '/etc/naemon/conf.d/test.cfg'],
    }, {
        url     => 'GET /config/objects',
        like    => ['/etc/naemon/conf.d/thruk_bp_generated.cfg', '/etc/naemon/conf.d/test.cfg'],
    }, {
# create new host
        url     => 'POST /config/objects',
        post    => {':TYPE' => 'host', ':FILE' => '301-test.cfg', 'name' => '301-test'},
        like    => ['created 1 objects successfully.', '301-test.cfg'],
    }, {
        url     => 'POST /config/revert',
        post    => {},
        like    => ['successfully reverted stashed changes for 1 site.'],
    },
];

for my $test (@{$pages}) {
    my($method, $url) = split(/\s+/mx, $test->{'url'}, 2);
    $url =~ s%/hosts?/<name>%/hosts/$host/%gmx;
    $test->{'url'}          = '/thruk/r'.$url;
    $test->{'method'}       = $method;
    $test->{'content_type'} = 'application/json;charset=UTF-8';
    my $page = TestUtils::test_page(%{$test});
    #BAIL_OUT("failed") unless Test::More->builder->is_passing;
}
