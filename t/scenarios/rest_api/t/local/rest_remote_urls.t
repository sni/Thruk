use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 15;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# rest requests with remote url
{
    TestUtils::test_command({
        cmd     => "/thruk/script/thruk -k rest https://localhost/demo/thruk/r/",
        like    => ["/login required/"],
        exit    => 3,
    });
};

###########################################################
# calling remote.cgi from cli
{
    my $postdata = 'data=%7B%22credential%22%3A+%22testkey%22%2C+%22options%22%3A+%7B%22action%22%3A%22raw%22%2C%22args%22%3A%5B%22GET+status%5CnResponseHeader%3A+fixed16%5CnOutputFormat%3A+json%5CnColumns%3A+program_start+accept_passive_host_checks+accept_passive_service_checks+cached_log_messages+check_external_commands+check_host_freshness+check_service_freshness+connections+connections_rate+enable_event_handlers+enable_flap_detection+enable_notifications+execute_host_checks+execute_service_checks+forks+forks_rate+host_checks+host_checks_rate+interval_length+last_command_check+last_log_rotation+livestatus_version+log_messages+log_messages_rate+nagios_pid+neb_callbacks+neb_callbacks_rate+obsess_over_hosts+obsess_over_services+process_performance_data+program_version+requests+requests_rate+service_checks+service_checks_rate%5Cn%22%5D%2C%22backends%22%3A%5B%22demo%22%5D%2C%22remote_name%22%3A%22demo%22%2C%22sub%22%3A%22_raw_query%22%7D%7D';
    TestUtils::test_command({
        cmd     => "/thruk/script/thruk rest -m POST -d ".$postdata." remote.cgi",
        like    => ["/output/", '/"200/', "/-naemon/", '/"version"/'],
        exit    => 0,
    });
};
