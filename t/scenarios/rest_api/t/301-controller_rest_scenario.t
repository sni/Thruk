use strict;
use warnings;
use Test::More;
use Cpanel::JSON::XS;

die("*** ERROR: this test is meant to be run with PLACK_TEST_EXTERNALSERVER_URI set,\nex.: THRUK_TEST_AUTH=omdadmin:omd PLACK_TEST_EXTERNALSERVER_URI=http://localhost:60080/demo perl t/scenarios/rest_api/t/301-controller_rest_scenario.t") unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

BEGIN {
    plan tests => 117;

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

################################################################################
# test offset
{
    my $page = TestUtils::test_page(
        url => '/thruk/r/services?columns=host_name,description',
    );
    my $tstdata = Cpanel::JSON::XS::decode_json($page->{'content'});
    is(scalar @{$tstdata}, 9, "number of services");

    $page = TestUtils::test_page(
        url => '/thruk/r/services?columns=host_name,description&offset=1',
    );
    my $data = Cpanel::JSON::XS::decode_json($page->{'content'});
    is(scalar @{$data}, 8, "number of services");
    is($data->[0]->{'host_name'}, $tstdata->[1]->{'host_name'}, "got correct index");
    is($data->[0]->{'description'}, $tstdata->[1]->{'description'}, "got correct index");

    $page = TestUtils::test_page(
        url => '/thruk/r/services?columns=host_name,description&offset=1&limit=2',
    );
    $data = Cpanel::JSON::XS::decode_json($page->{'content'});
    is(scalar @{$data}, 2, "number of services");
    is($data->[0]->{'host_name'}, $tstdata->[1]->{'host_name'}, "got correct index");
    is($data->[0]->{'description'}, $tstdata->[1]->{'description'}, "got correct index");
};

################################################################################
# test aggregation functions
{
    my $page = TestUtils::test_page(
        url => '/thruk/r/services?columns=avg(execution_time),state&sort=avg(execution_time)&host_name='.$host.'&avg(execution_time)[gte]=0.000001',
    );
    my $tstdata = Cpanel::JSON::XS::decode_json($page->{'content'});
    ok(scalar @{$tstdata} > 0, "got result");
    ok(defined $tstdata->[0]->{':KEY'}, "got result");

    $page = TestUtils::test_page(
        url => '/thruk/r/hosts?columns=min(state),max(state),avg(state),count(state),sum(state)',
    );
    $tstdata = Cpanel::JSON::XS::decode_json($page->{'content'});
    is(scalar keys %{$tstdata}, 5, "got result");
    is($tstdata->{'min(state)'}, 0, "got min state");
    is($tstdata->{'count(state)'}, 2, "got count state");
};