use strict;
use warnings;
use Test::More;

die("*** ERROR: this test is meant to be run with PLACK_TEST_EXTERNALSERVER_URI set") unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

BEGIN {
    plan tests => 75;

    use lib('t');
    require TestUtils;
    import TestUtils;
    $ENV{'NO_POST_TOKEN'} = 1; # disable adding "token" to each POST request
}

use_ok 'Thruk::Controller::rest_v1';

my($host,$service) = ('localhost', 'Users');

my $pages = [{
        url          => '/services/localhost/Ping/cmd/schedule_forced_svc_check',
        post         => { 'start_time' => 'now' },
        like         => ['Command successfully submitted'],
    }, {
        url          => '/csv/services?q=***description ~ http and description !~ cert***&columns=description',
        like         => ['Https'],
        unlike       => ['Cert'],
        content_type => 'text/plain; charset=UTF-8',
    }, {
        url          => '/csv/services/totals?q=***description ~ http and description !~ cert***&columns=total',
        like         => ['total;2'],
        content_type => 'text/plain; charset=UTF-8',
    }, {
        url          => '/services/'.$host.'/'.$service.'/cmd/schedule_svc_downtime',
        post         => { 'start_time' => 'now', 'end_time' => '+60m', 'comment_data' => 'test comment' },
        like         => ['Command successfully submitted'],
    }, {
        url          => '/downtimes',
        like         => ['"test comment",', 'omdadmin'],
    }, {
        url          => '/services/localhost/Ping',
        like         => ['"rta"'],
        waitfor      => '"rta"',
    }, {
        url          => '/services?columns=rta&rta[gt]=0',
        like         => ['"rta" : "0.\d+'],
    }, {
        url          => '/services?columns=rta&rta[gt]=0&_WORKER[ne]=test&_HOSTWORKER[ne]=test',
        like         => ['"rta" : "0.\d+'],
    }, {
        url          => '/logs?q=***type = "EXTERNAL COMMAND"***',
        like         => ['EXTERNAL COMMAND'],
    }, {
        url          => '/logs?q=***type = "EXTERNAL COMMAND" and time > '.(time() - 600).'***',
        like         => ['EXTERNAL COMMAND'],
    }
];

for my $test (@{$pages}) {
    $test->{'content_type'} = 'application/json;charset=UTF-8' unless $test->{'content_type'};
    $test->{'url'}          = '/thruk/r'.$test->{'url'};
    my $page = TestUtils::test_page(%{$test});
    #BAIL_OUT("failed") unless Test::More->builder->is_passing;
}
