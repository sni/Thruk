use warnings;
use strict;
use Cpanel::JSON::XS;
use Test::More;

die("*** ERROR: this test is meant to be run with PLACK_TEST_EXTERNALSERVER_URI set,\nex.: THRUK_TEST_AUTH=omdadmin:omd PLACK_TEST_EXTERNALSERVER_URI=http://localhost:60080/demo perl t/scenarios/rest_api/t/305-controller_rest_commands.t") unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

BEGIN {
    plan tests => 1083;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok 'Thruk::Controller::Rest::V1::cmd';
TestUtils::set_test_user_token();

my($host,$service) = ('localhost', 'Users');
my($hostgroup,$servicegroup) = ('Everything', 'Http Check');
my($contact,$contactgroup) = ('example', 'example');
my $cmds = Thruk::Controller::Rest::V1::cmd::get_rest_external_command_data();

for my $type (sort keys %{$cmds}) {
    my $rest_path = '';
    if($type eq 'hosts') {
        $rest_path = 'hosts/'.$host;
    } elsif($type eq 'hostgroups') {
        $rest_path = 'hostgroups/'.$hostgroup;
    } elsif($type eq 'services') {
        $rest_path = 'services/'.$host.'/'.$service;
    } elsif($type eq 'servicegroups') {
        $rest_path = 'servicegroups/'.$servicegroup;
    } elsif($type eq 'contacts') {
        $rest_path = 'contacts/'.$contact;
    } elsif($type eq 'contactgroups') {
        $rest_path = 'contactgroups/'.$contactgroup;
    } elsif($type eq 'system' || $type eq 'all_host_service') {
        $rest_path = 'system';
    } else {
        BAIL_OUT("unknown type: ".$type);
    }
    for my $cmd (sort keys %{$cmds->{$type}}) {
        next if $cmd eq 'acknowledge_host_problem_expire';
        next if $cmd eq 'acknowledge_svc_problem_expire';
        next if $cmd eq 'del_comment';
        next if $cmd eq 'del_downtime';
        next if $cmd =~ m/^shutdown_pro/mx;
        next if $cmd =~ m/^restart_pro/mx;
        my $test = {
            'content_type' => 'application/json; charset=utf-8',
            'url'          => '/thruk/r/'.$rest_path.'/cmd/'.$cmd,
            'like'         => ['Command successfully submitted', 'COMMAND \['],
            'unlike'       => ['sending command failed'],
            'post'         => {
                comment_data      => "test",
                plugin_output     => "test",
                notification_time => "+60m",
                comment_id        => "1",
                downtime_id       => "1",
                timeperiod        => "24x7",
                value             => "0",
                name              => "TST",
                checkcommand      => "check_udp",
                eventhandler      => "check_udp",
                interval          => "60",
                number            => "10",
                attempts          => "0",
                hostgroup_name    => "Everything",
                log               => "Example Log;Text;time: ".time(),
             },
        };
        TestUtils::test_page(%{$test});
    }
}

########################################
# test command error message
TestUtils::test_page(
    'content_type' => 'application/json; charset=utf-8',
    'url'          => '/thruk/r/hosts/'.$host.'/cmd/schedule_host_downtime',
    'code'         => 400,
    'like'         => ['demo: 400: Couldn\'t parse ulong argument trigger_id', 'COMMAND', 'sending command failed', '"code" : 400'],
    'unlike'       => ['Command successfully submitted'],
    'post'         => {
        comment_data        => "test",
        triggered_by        => "test",
    },
);

########################################
# enable some things again
TestUtils::test_page(
    'content_type' => 'application/json; charset=utf-8',
    'url'          => '/thruk/r/system/cmd/start_accepting_passive_svc_checks',
    'like'         => ['Command successfully submitted', 'COMMAND \['],
    'unlike'       => ['sending command failed'],
    'post'         => {},
);
