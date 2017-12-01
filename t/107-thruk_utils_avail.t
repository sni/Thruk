use strict;
use warnings;
use utf8;
use Test::More;

plan tests => 6;

use_ok("Monitoring::Availability");
use_ok("Thruk::Utils::Avail");

my $host    = 'test_host';
my $service = 'service';
my $start   = 1264110000;
my $end     = 1264135000;
my $ma = Monitoring::Availability->new();

###########################################################
# simple outage
{
    my $log = '
[1264110000] SERVICE ALERT: test_host;service;OK;HARD;1;check is ok
[1264111000] SERVICE ALERT: test_host;service;UNKNOWN;SOFT;1;check is unknown
[1264112000] SERVICE ALERT: test_host;service;UNKNOWN;HARD;2;check is unknown
[1264115000] SERVICE ALERT: test_host;service;OK;HARD;1;check is ok
';
    my $expected_outages =[{
        'host'          => 'test_host',
        'service'       => 'service',
        'start'         => 1264112000,
        'end'           => 1264115000,
        'real_end'      => 1264115000,
        'duration'      => 3000,
        'plugin_output' => 'check is unknown',
        'type'          => 'SERVICE UNKNOWN (HARD)',
        'class'         => 'unknown',
        'in_downtime'   => 0,
    }];
    my $ma_options = {
        'start'                        => $start,
        'end'                          => $end,
        'log_string'                   => $log,
        'services'                     => [{ 'host' => $host, 'service' => $service }],
        'assumeinitialstates'          => "yes",
    };
    my $avail_data = $ma->calculate(%{$ma_options});
    my $logs       = $ma->get_condensed_logs();
    my $outages    = Thruk::Utils::Avail::outages($logs, {'critical' => 1, 'unknown' => 1}, $start, $end, $host, $service);
    is_deeply($outages, $expected_outages, "simple outage as expected");
};

###########################################################
# soft outage
{
    my $log = '
[1264110000] SERVICE ALERT: test_host;service;OK;HARD;1;check is ok
[1264111000] SERVICE ALERT: test_host;service;UNKNOWN;SOFT;1;check is unknown
[1264112000] SERVICE ALERT: test_host;service;UNKNOWN;HARD;2;check is unknown
[1264115000] SERVICE ALERT: test_host;service;OK;HARD;1;check is ok
';
    my $expected_outages =[{
        'host'          => 'test_host',
        'service'       => 'service',
        'start'         => 1264111000,
        'end'           => 1264112000,
        'real_end'      => 1264115000,
        'duration'      => 4000,
        'plugin_output' => 'check is unknown',
        'type'          => 'SERVICE UNKNOWN',
        'class'         => 'unknown',
        'in_downtime'   => 0,
    }];
    my $ma_options = {
        'start'                        => $start,
        'end'                          => $end,
        'log_string'                   => $log,
        'services'                     => [{ 'host' => $host, 'service' => $service }],
        'assumeinitialstates'          => "yes",
        'includesoftstates'            => "yes",
    };
    my $avail_data = $ma->calculate(%{$ma_options});
    my $logs       = $ma->get_condensed_logs();
    my $outages    = Thruk::Utils::Avail::outages($logs, {'critical' => 1, 'unknown' => 1}, $start, $end, $host, $service);
    is_deeply($outages, $expected_outages, "simple outage as expected");
};

###########################################################
# multiple outages
{
    my $log = '
[1264110000] SERVICE ALERT: test_host;service;OK;HARD;1;check is ok
[1264111000] SERVICE ALERT: test_host;service;UNKNOWN;SOFT;1;check is unknown
[1264112000] SERVICE ALERT: test_host;service;UNKNOWN;HARD;2;check is unknown
[1264113000] SERVICE DOWNTIME ALERT: test_host;service;STARTED; Service has entered a period of scheduled downtime
[1264114000] SERVICE DOWNTIME ALERT: test_host;service;CANCELLED; Scheduled downtime for service has been cancelled.
[1264115000] SERVICE ALERT: test_host;service;OK;HARD;1;check is ok
[1264120000] SERVICE ALERT: test_host;service;UNKNOWN;SOFT;1;check is unknown again
[1264121000] SERVICE ALERT: test_host;service;UNKNOWN;HARD;2;check is unknown again
[1264122000] SERVICE ALERT: test_host;service;OK;HARD;1;check is ok
[1264130000] SERVICE DOWNTIME ALERT: test_host;service;STARTED; Service has entered a period of scheduled downtime
[1264131000] SERVICE ALERT: test_host;service;UNKNOWN;SOFT;1;check is unknown during downtime
[1264132000] SERVICE ALERT: test_host;service;UNKNOWN;HARD;2;check is unknown during downtime
[1264134000] SERVICE ALERT: test_host;service;OK;HARD;1;check is ok
[1264135000] SERVICE DOWNTIME ALERT: test_host;service;CANCELLED; Scheduled downtime for service has been cancelled.
';

    my $ma = Monitoring::Availability->new();
    my $ma_options = {
        'start'                        => $start,
        'end'                          => $end,
        'log_string'                   => $log,
        'services'                     => [{ 'host' => $host, 'service' => $service }],
        'assumeinitialstates'          => "yes",
    };
    my $expected_outages =[{
        'host'          => 'test_host',
        'service'       => 'service',
        'start'         => 1264121000,
        'end'           => 1264122000,
        'real_end'      => 1264122000,
        'duration'      => 1000,
        'plugin_output' => 'check is unknown again',
        'type'          => 'SERVICE UNKNOWN (HARD)',
        'class'         => 'unknown',
        'in_downtime'   => 0,
    }, {
        'host'          => 'test_host',
        'service'       => 'service',
        'start'         => 1264114000,
        'end'           => 1264115000,
        'real_end'      => 1264115000,
        'duration'      => 1000,
        'plugin_output' => 'check is unknown',
        'type'          => 'SERVICE UNKNOWN (HARD)',
        'class'         => 'unknown',
        'in_downtime'   => 0,
    }, {
        'host'          => 'test_host',
        'service'       => 'service',
        'start'         => 1264112000,
        'end'           => 1264113000,
        'real_end'      => 1264113000,
        'duration'      => 1000,
        'plugin_output' => 'check is unknown',
        'type'          => 'SERVICE UNKNOWN (HARD)',
        'class'         => 'unknown',
        'in_downtime'   => 0,
    }];
    my $avail_data = $ma->calculate(%{$ma_options});
    my $logs       = $ma->get_condensed_logs();
    my $outages    = Thruk::Utils::Avail::outages($logs, {'critical' => 1, 'unknown' => 1}, $start, $end, $host, $service);
    is_deeply($outages, $expected_outages, "multiple outage as expected");
};

###########################################################
# timeperiod outage
{
    my $log = '
[1264110000] TIMEPERIOD TRANSITION: test;1;0
[1264110000] SERVICE ALERT: test_host;service;OK;HARD;1;check is ok
[1264111000] SERVICE ALERT: test_host;service;UNKNOWN;SOFT;1;check is unknown
[1264112000] SERVICE ALERT: test_host;service;UNKNOWN;HARD;2;check is unknown
[1264113000] TIMEPERIOD TRANSITION: test;0;1
[1264115000] SERVICE ALERT: test_host;service;OK;HARD;1;check is ok
';
    my $expected_outages =[{
        'host'          => 'test_host',
        'service'       => 'service',
        'start'         => 1264113000,
        'end'           => 1264115000,
        'real_end'      => 1264115000,
        'duration'      => 2000,
        'plugin_output' => 'check is unknown',
        'type'          => 'SERVICE UNKNOWN (HARD)',
        'class'         => 'unknown',
    }];
    my $ma_options = {
        'start'                        => $start,
        'end'                          => $end,
        'log_string'                   => $log,
        'services'                     => [{ 'host' => $host, 'service' => $service }],
        'assumeinitialstates'          => "yes",
        'rpttimeperiod'                => "test",
    };
    my $avail_data = $ma->calculate(%{$ma_options});
    my $logs       = $ma->get_condensed_logs();
    my $outages    = Thruk::Utils::Avail::outages($logs, {'critical' => 1, 'unknown' => 1}, $start, $end, $host, $service);
    is_deeply($outages, $expected_outages, "timeperiod outage as expected");
};
