use warnings;
use strict;
use Cpanel::JSON::XS qw/decode_json/;
use Test::More;

BEGIN {
    plan tests => 247;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok 'Thruk::Controller::rest_v1';
TestUtils::set_test_user_token();
my($host,$service) = ('localhost', 'Users');
my($hostgroup,$servicegroup) = ('Everything', 'Http Check');

_test_page({
# force reschedule so we get some performance data
    url     => 'POST /hosts/<name>/cmd/schedule_forced_host_check',
    post    => { start_time => 'now' },
    like    => ['Command successfully submitted'],
});
_test_page({
    url     => 'GET /hosts/<name>',
    waitfor => 'rta_unit',
});
_test_page({
    url     => 'GET /hosts/<name>',
    like    => ['"rta_unit" : "ms",', '"rta" : \d+\.\d+', ''],
});
_test_page({
# verify configuration from config tool
    url     => 'GET /hosts/<name>/config',
    like    => ['"alias" : "localhost",', '"address" : "127.0.0.1",', '/omd/sites/demo/etc/naemon/conf.d/example.cfg:1'],
});
_test_page({
    url     => 'GET /hostgroups/'.$hostgroup.'/config',
    like    => ['Just all hosts'],
});
_test_page({
    url     => 'GET /servicegroups/'.$servicegroup.'/config',
    like    => ['Http Checks'],
});
_test_page({
# change a few things
    url     => 'PATCH /hosts/<name>/config',
    post    => {address => '127.0.0.2', max_check_attempts => 5, icon_image => undef },
    like    => ['changed 1 objects successfully.'],
});
_test_page({
    url     => 'GET /hosts/<name>/config',
    like    => ['"alias" : "localhost",', '"address" : "127.0.0.2",', '/omd/sites/demo/etc/naemon/conf.d/example.cfg:1'],
    unlike  => ['icon_image'],
});
_test_page({
    url     => 'GET /config/diff',
    like    => ['/omd/sites/demo/etc/naemon/conf.d/example.cfg', 'max_check_attempts'],
});
_test_page({
    url     => 'POST /config/check',
    post    => {},
    like    => ['"failed" : false,', 'Running configuration check'],
});
_test_page({
    url     => 'POST /config/save',
    post    => {},
    like    => ['successfully saved changes for 1 site.'],
});
_test_page({
    url     => 'POST /config/reload',
    post    => {},
    like    => ['"failed" : false'],
});
_test_page({
    url     => 'GET /hosts/<name>/config',
    like    => ['"alias" : "localhost",', '"address" : "127.0.0.2",', '/omd/sites/demo/etc/naemon/conf.d/example.cfg:1'],
    unlike  => ['icon_image'],
});
_test_page({
    url     => 'GET /hosts/<name>',
    like    => ['"alias" : "localhost",', '"address" : "127.0.0.2",'],
});
_test_page({
# try reverting changes
    url     => 'PATCH /hosts/<name>/config',
    post    => {address => '127.0.0.1', max_check_attempts => undef, icon_image => "linux40.png" },
    like    => ['changed 1 objects successfully.'],
});
_test_page({
    url     => 'GET /config/diff',
    like    => ['/omd/sites/demo/etc/naemon/conf.d/example.cfg', 'linux40.png'],
});
_test_page({
    url     => 'POST /config/revert',
    post    => {},
    like    => ['successfully reverted stashed changes for 1 site.'],
});
_test_page({
# try deleting things
    url     => 'DELETE /hosts/<name>/config',
    post    => {},
    like    => ['removed 1 objects successfully.'],
});
_test_page({
    url     => 'GET /config/diff',
    like    => ['/omd/sites/demo/etc/naemon/conf.d/example.cfg', '-\s*alias'],
});
_test_page({
    url     => 'POST /config/revert',
    post    => {},
    like    => ['successfully reverted stashed changes for 1 site.'],
});
_test_page({
# finally revert host back to start
    url     => 'PATCH /hosts/<name>/config',
    post    => {address => '127.0.0.1', max_check_attempts => undef, icon_image => "linux40.png" },
    like    => ['changed 1 objects successfully.'],
});
_test_page({
    url     => 'POST /config/save',
    post    => {},
    like    => ['successfully saved changes for 1 site.'],
});
_test_page({
    url     => 'POST /config/reload',
    post    => {},
    like    => ['"failed" : false'],
});
_test_page({
    url     => 'GET /hosts/<name>/config',
    like    => ['"alias" : "localhost",', '"address" : "127.0.0.1",', '/omd/sites/demo/etc/naemon/conf.d/example.cfg:1', 'linux40.png'],
});
_test_page({
    url     => 'GET /config/files',
    like    => ['/etc/naemon/conf.d/example.cfg', '/etc/naemon/conf.d/test.cfg'],
});
_test_page({
    url     => 'GET /config/objects',
    like    => ['/etc/naemon/conf.d/example.cfg', '/etc/naemon/conf.d/test.cfg'],
});
_test_page({
    url     => 'GET /config/fullobjects',
    like    => ['/etc/naemon/conf.d/example.cfg', '/etc/naemon/conf.d/test.cfg', ':TEMPLATES'],
});
_test_page({
# create new host
    url     => 'POST /config/objects',
    post    => {':TYPE' => 'host', ':FILE' => '301-test.cfg', 'name' => '301-test'},
    like    => ['created 1 objects successfully.', '301-test.cfg'],
});
_test_page({
    url     => 'POST /config/revert',
    post    => {},
    like    => ['successfully reverted stashed changes for 1 site.'],
});

sub _test_page {
    my($test) = @_;
    my($method, $url) = split(/\s+/mx, $test->{'url'}, 2);
    $url =~ s%/hosts?/<name>%/hosts/$host%gmx;
    $test->{'url'}          = '/thruk/r'.$url;
    $test->{'method'}       = $method;
    $test->{'content_type'} = 'application/json; charset=utf-8';
    my $page = TestUtils::test_page(%{$test});
}
