use strict;
use warnings;
use Test::More;
use Cpanel::JSON::XS qw/decode_json/;

die("*** ERROR: this test is meant to be run with PLACK_TEST_EXTERNALSERVER_URI set") unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

BEGIN {
    plan tests => 85;

    use lib('t');
    require TestUtils;
    import TestUtils;
    $ENV{'NO_POST_TOKEN'} = 1; # disable adding "token" to each POST request
}

use_ok 'Thruk::Controller::rest_v1';
my($host,$service) = ('localhost', 'Users');

my $original_report;
my $pages = [{
        url     => '/thruk/reports',
        like    => ['"desc" : "Example Description"', '"user" : "omdadmin"', '"timeperiod" : "last24hours"', '"host" : "localhost"'],
    }, {
# update existing report
        url     => '/thruk/reports/1',
        method  => 'patch',
        post    => { params => { timeperiod => 'lastweek' }, desc => 'Changed Report' },
        like    => ['successfully saved 1 report.'],
    }, {
        url     => '/thruk/reports/1',
        like    => ['"desc" : "Changed Report"', '"user" : "omdadmin"', '"timeperiod" : "lastweek"', '"host" : "localhost"'],
    }, {
# change back
        url     => '/thruk/reports/1',
        method  => 'post',
        post    => \$original_report,
        like    => ['successfully saved 1 report.'],
    }, {
        url     => '/thruk/reports',
        like    => ['"desc" : "Example Description"', '"user" : "omdadmin"', '"timeperiod" : "last24hours"', '"host" : "localhost"'],
    }, {
# create new report
        url     => '/thruk/reports',
        method  => 'post',
        post    => \$original_report,
        like    => ['successfully saved 1 report.'],
    }, {
        url     => '/thruk/reports/2',
        like    => ['"desc" : "Example Description"', '"user" : "omdadmin"', '"timeperiod" : "last24hours"', '"host" : "localhost"'],
    }, {
# remove report
        url     => '/thruk/reports/2',
        method  => 'delete',
        post    => {},
        like    => ['successfully removed 1 report.'],
    }, {
        url     => '/thruk/reports/2',
        like    => ['no such report'],
        fail    => 1,
    },
];

for my $test (@{$pages}) {
    $test->{'content_type'} = 'application/json;charset=UTF-8' unless $test->{'content_type'};
    $test->{'url'}          = '/thruk/r'.$test->{'url'};
    my $page = TestUtils::test_page(%{$test});
    if(!defined $original_report) {
        my $data = decode_json($page->{'content'});
        $original_report = $data->[0];
    }
    #BAIL_OUT("failed") unless Test::More->builder->is_passing;
}
