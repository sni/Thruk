use strict;
use warnings;
use Test::More tests => 101;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

BEGIN { use_ok 'Thruk::Controller::avail' }

my($host,$service) = TestUtils::get_test_service();

my $pages = [
# Step 1
    '/avail',
    '/thruk/cgi-bin/avail.cgi',

# Step 2
    '/thruk/cgi-bin/avail.cgi?report_type=hosts',
    '/thruk/cgi-bin/avail.cgi?report_type=hostgroups',
    '/thruk/cgi-bin/avail.cgi?report_type=services',
    '/thruk/cgi-bin/avail.cgi?report_type=servicegroups',

# Step 3
    '/thruk/cgi-bin/avail.cgi?get_date_parts=&report_type=hostgroups&hostgroup=down',
    '/thruk/cgi-bin/avail.cgi?get_date_parts=&report_type=hosts&host='.$host,
    '/thruk/cgi-bin/avail.cgi?get_date_parts=&report_type=services&service='.$host.';'.$service,
    '/thruk/cgi-bin/avail.cgi?get_date_parts=&report_type=servicegroups&servicegroup=critical',

# Report
    '/thruk/cgi-bin/avail.cgi?host='.$host.'&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=0&backtrack=4',
    '/thruk/cgi-bin/avail.cgi?host=all&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=0&backtrack=4',
    '/thruk/cgi-bin/avail.cgi?servicegroup=critical&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=0&backtrack=4',
    '/thruk/cgi-bin/avail.cgi?hostgroup=down&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=0&backtrack=4',
    '/thruk/cgi-bin/avail.cgi?service='.$service.'&host='.$host.'&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=0&backtrack=4',
    '/thruk/cgi-bin/avail.cgi?service=all&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=0&backtrack=4',

    '/thruk/cgi-bin/avail.cgi?host='.$host.'&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=-1&initialassumedhoststate=-1',
    '/thruk/cgi-bin/avail.cgi?host=all&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=-1&initialassumedhoststate=-1',
    '/thruk/cgi-bin/avail.cgi?servicegroup=critical&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=-1&initialassumedhoststate=-1',
    '/thruk/cgi-bin/avail.cgi?hostgroup=down&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=-1&initialassumedhoststate=-1',
    '/thruk/cgi-bin/avail.cgi?service='.$service.'&host='.$host.'&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=-1&initialassumedhoststate=-1',
    '/thruk/cgi-bin/avail.cgi?service=all&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=-1&initialassumedhoststate=-1&backtrack=4',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Availability Report',
        'unlike'  => 'internal server error',
    );
}


my $csv_pages = [
    # CSV
    '/thruk/cgi-bin/avail.cgi?host=all&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=-1&initialassumedhoststate=-1&csvoutput=',
    '/thruk/cgi-bin/avail.cgi?service=all&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=-1&initialassumedhoststate=-1&backtrack=4&csvoutput=',
];

for my $url (@{$csv_pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'HOST_NAME, ',
        'unlike'  => 'internal server error',
    );
}