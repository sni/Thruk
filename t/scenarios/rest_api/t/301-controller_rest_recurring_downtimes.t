use strict;
use warnings;
use Test::More;
use Cpanel::JSON::XS qw/decode_json/;

die("*** ERROR: this test is meant to be run with PLACK_TEST_EXTERNALSERVER_URI set") unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

BEGIN {
    plan tests => 57;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok 'Thruk::Controller::rest_v1';
TestUtils::set_test_user_token();
my($host,$service) = ('localhost', 'Users');

my $pages = [{
# create new downtime
        url     => '/thruk/recurring_downtimes',
        method  => 'post',
        post    => { 'file'     => '9999',
                     'duration' => '120',
                     'host'     => [$host],
                     'target'   => 'host',
                     'schedule' => [{cust => '* * * * *', type => 'cust'}],
                     'fixed'    => 1,
                     'comment'  => 'test downtime',
                   },
        like    => ['successfully created downtime'],
    }, {
        url     => '/thruk/recurring_downtimes',
        like    => ['test downtime', $host, '9999'],
    }, {
        url     => '/thruk/recurring_downtimes/9999',
        like    => ['test downtime', $host, '9999'],
    }, {
# update downtime
        url     => '/thruk/recurring_downtimes/9999',
        method  => 'patch',
        post    => { comment => 'updated downtime' },
        like    => ['successfully saved 1 downtime.'],
    }, {
        url     => '/thruk/recurring_downtimes/9999',
        like    => ['updated downtime', $host, '9999'],
    }, {
# delete downtime
        url     => '/thruk/recurring_downtimes/9999',
        method  => 'delete',
        post    => {},
        like    => ['successfully removed 1 downtime.'],
    }
];

for my $test (@{$pages}) {
    $test->{'content_type'} = 'application/json;charset=UTF-8' unless $test->{'content_type'};
    $test->{'url'}          = '/thruk/r'.$test->{'url'};
    my $page = TestUtils::test_page(%{$test});
    #BAIL_OUT("failed") unless Test::More->builder->is_passing;
}
