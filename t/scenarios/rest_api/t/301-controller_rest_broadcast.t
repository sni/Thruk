use strict;
use warnings;
use Test::More;
use Cpanel::JSON::XS qw/decode_json/;

die("*** ERROR: this test is meant to be run with PLACK_TEST_EXTERNALSERVER_URI set") unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

BEGIN {
    plan tests => 49;

    use lib('t');
    require TestUtils;
    import TestUtils;
    $ENV{'NO_POST_TOKEN'} = 1; # disable adding "token" to each POST request
}

use_ok 'Thruk::Controller::rest_v1';
my($host,$service) = ('localhost', 'Users');

my $pages = [{
# create new broadcast
        url     => '/thruk/broadcasts',
        method  => 'post',
        post    => { 'file' => 'test', text => 'test broadcast' },
        like    => ['successfully created broadcast'],
    }, {
        url     => '/thruk/broadcasts',
        like    => ['test broadcast'],
    }, {
        url     => '/thruk/broadcasts/test',
        like    => ['test broadcast'],
    }, {
# update broadcast
        url     => '/thruk/broadcasts/test',
        method  => 'patch',
        post    => { text => 'updated broadcast' },
        like    => ['successfully saved 1 broadcast.'],
    }, {
        url     => '/thruk/broadcasts/test',
        like    => ['updated broadcast'],
    }, {
# delete broadcast
        url     => '/thruk/broadcasts/test',
        method  => 'delete',
        post    => {},
        like    => ['successfully removed 1 broadcast.'],
    }
];

for my $test (@{$pages}) {
    $test->{'content_type'} = 'application/json;charset=UTF-8' unless $test->{'content_type'};
    $test->{'url'}          = '/thruk/r'.$test->{'url'};
    my $page = TestUtils::test_page(%{$test});
    #BAIL_OUT("failed") unless Test::More->builder->is_passing;
}
