use warnings;
use strict;
use Test::More;
use utf8;

plan tests => 27;

BEGIN {
    $ENV{'THRUK_AUTHOR'} = 1;
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use Thruk::Utils::IO ();

###########################################################
# verify that we use the correct thruk binary
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# add downtime with utf8 characters
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk r -d comment_data=döwnäüß€ -d end_time=+3m /hosts/öäüß€/cmd/schedule_host_downtime',
    like => ['/Command successfully submitted/'],
});

###########################################################
# excel export service list
TestUtils::test_command({
    cmd  => '/usr/bin/env bash -c \'thruk url "status.cgi?style=detail&view_mode=xls&columns=Hostname&columns=IP&columns=Service&columns=Comments" >/tmp/test.xls\'',
    like => ['/^$/'],
});

###########################################################
# check excel file
TestUtils::test_command({
    cmd  => '/usr/bin/env file /tmp/test.xls',
    like => ['/\/tmp\/test.xls: CDFV2 Microsoft Excel/'],
});

###########################################################
# convert to csv
TestUtils::test_command({
    cmd     => '/usr/bin/env libreoffice --headless --convert-to "csv" --infilter="CSV:44,34,UTF-8" --outdir /tmp/ /tmp/test.xls',
    like    => ['/convert/', '/StarCalc/'],
});

###########################################################
# check excel file
TestUtils::test_command({
    cmd  => '/usr/bin/env file /tmp/test.csv',
    like => ['/\/tmp\/test.csv: UTF-8 Unicode text/'],
});

###########################################################
# does the csv contain all information?
my $content = Thruk::Utils::IO::read_decoded("/tmp/test.csv");
like($content, '/öäüß€/', 'csv file contains hostname');
like($content, '/döwnäüß€/', 'csv contains downtime comment');

###########################################################
# cleanup
unlink("/tmp/test.xls");
#unlink("/tmp/test.csv");

###########################################################
