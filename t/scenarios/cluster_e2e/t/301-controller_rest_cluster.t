use strict;
use warnings;
use Test::More;
use Cpanel::JSON::XS qw/decode_json/;

die("*** ERROR: this test is meant to be run with PLACK_TEST_EXTERNALSERVER_URI set") unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

BEGIN {
    plan tests => 160;

    use lib('t');
    require TestUtils;
    import TestUtils;
    $ENV{'NO_POST_TOKEN'} = 1; # disable adding "token" to each POST request
}

use_ok 'Thruk::Controller::rest_v1';
my($host,$service) = ('localhost', 'Users');

my $pages = [{
# force reschedule so we get some performance data
        url     => '/hosts/'.$host.'/cmd/schedule_forced_host_check',
        post    => { start_time => 'now' },
        like    => ['Command successfully submitted'],
    }, {
        url     => '/hosts/'.$host,
        like    => ['"rta_unit" : "ms",', '"rta" : "0.0', ''],
    }, {
# verify configuration from config tool
        url     => '/hosts/'.$host.'/config',
        like    => ['"alias" : "localhost",', '"address" : "127.0.0.1",', '/omd/sites/demo/etc/naemon/conf.d/example.cfg:1'],
    }, {
# change a few things
        url     => '/hosts/'.$host.'/config',
        method  => 'patch',
        post    => {address => '127.0.0.2', max_check_attempts => 5, icon_image => undef },
        like    => ['changed 1 objects successfully.'],
    }, {
        url     => '/hosts/'.$host.'/config',
        like    => ['"alias" : "localhost",', '"address" : "127.0.0.2",', '/omd/sites/demo/etc/naemon/conf.d/example.cfg:1'],
        unlike  => ['icon_image'],
    }, {
        url     => '/config/diff',
        like    => ['/omd/sites/demo/etc/naemon/conf.d/example.cfg', 'max_check_attempts'],
    }, {
        url     => '/config/check',
        post    => {},
        like    => ['"failed" : false,', 'Running configuration check'],
    }, {
        url     => '/config/save',
        post    => {},
        like    => ['successfully saved changes for 1 site.'],
    }, {
        url     => '/config/reload',
        post    => {},
        like    => ['"failed" : false'],
    }, {
        url     => '/hosts/'.$host.'/config',
        like    => ['"alias" : "localhost",', '"address" : "127.0.0.2",', '/omd/sites/demo/etc/naemon/conf.d/example.cfg:1'],
        unlike  => ['icon_image'],
    }, {
        url     => '/hosts/'.$host,
        like    => ['"alias" : "localhost",', '"address" : "127.0.0.2",'],
    }, {
# try reverting changes
        url     => '/hosts/'.$host.'/config',
        method  => 'patch',
        post    => {address => '127.0.0.1', max_check_attempts => undef, icon_image => "linux40.png" },
        like    => ['changed 1 objects successfully.'],
    }, {
        url     => '/config/diff',
        like    => ['/omd/sites/demo/etc/naemon/conf.d/example.cfg', 'linux40.png'],
    }, {
        url     => '/config/revert',
        post    => {},
        like    => ['successfully reverted stashed changes for 1 site.'],
    }, {
# finally revert host back to start
        url     => '/hosts/'.$host.'/config',
        method  => 'patch',
        post    => {address => '127.0.0.1', max_check_attempts => undef, icon_image => "linux40.png" },
        like    => ['changed 1 objects successfully.'],
    }, {
        url     => '/config/save',
        post    => {},
        like    => ['successfully saved changes for 1 site.'],
    }, {
        url     => '/config/reload',
        post    => {},
        like    => ['"failed" : false'],
    }, {
        url     => '/hosts/'.$host.'/config',
        like    => ['"alias" : "localhost",', '"address" : "127.0.0.1",', '/omd/sites/demo/etc/naemon/conf.d/example.cfg:1', 'linux40.png'],
    },
];

for my $test (@{$pages}) {
    my $page = TestUtils::test_page(
        'url'          => '/thruk/r'.$test->{'url'},
        'content_type' => 'application/json;charset=UTF-8',
        'like'         => $test->{'like'},
        'post'         => $test->{'post'},
        'method'       => $test->{'method'},
    );
    #BAIL_OUT("failed") unless Test::More->builder->is_passing;
}
