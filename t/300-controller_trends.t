use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 79;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

BEGIN { use_ok 'Thruk::Controller::trends' }

my($host,$service) = TestUtils::get_test_service();
my $timeperiod     = TestUtils::get_test_timeperiod();

my $pages = [
# Step 1
    '/thruk/cgi-bin/trends.cgi',
];

my $reports = [
    '/thruk/cgi-bin/trends.cgi?host='.$host.'&t1=1264820912&t2=1265425712&includesoftstates=no&assumestateretention=yes&assumeinitialstates=yes&assumestatesduringnotrunning=yes&initialassumedhoststate=0&backtrack=4',
    '/thruk/cgi-bin/trends.cgi?host='.$host.'&service='.$service.'&t1=1264820912&t2=1265425712&includesoftstates=no&assumestateretention=yes&assumeinitialstates=yes&assumestatesduringnotrunning=yes&initialassumedservicestate=0&backtrack=4',
];

my $pictures = [
    # host last 7 days
    '/thruk/cgi-bin/trends.cgi?createimage&smallimage&host='.$host.'&t1=1264820912&t2=1265425712&includesoftstates=no&assumestateretention=yes&assumeinitialstates=yes&assumestatesduringnotrunning=yes&initialassumedhoststate=0&backtrack=4',
    '/thruk/cgi-bin/trends.cgi?createimage&host='.$host.'&t1=1264820912&t2=1265425712&includesoftstates=no&assumestateretention=yes&assumeinitialstates=yes&assumestatesduringnotrunning=yes&initialassumedhoststate=0&backtrack=4',

    # service last 7 days
    '/thruk/cgi-bin/trends.cgi?createimage&smallimage&host='.$host.'&service='.$service.'&t1=1264820912&t2=1265425712&includesoftstates=no&assumestateretention=yes&assumeinitialstates=yes&assumestatesduringnotrunning=yes&initialassumedservicestate=0&backtrack=4',
    '/thruk/cgi-bin/trends.cgi?createimage&host='.$host.'&service='.$service.'&t1=1264820912&t2=1265425712&includesoftstates=no&assumestateretention=yes&assumeinitialstates=yes&assumestatesduringnotrunning=yes&initialassumedservicestate=0&backtrack=4',

    # with timeperiod
    '/thruk/cgi-bin/trends.cgi?createimage&host='.$host.'&t1=1264820912&t2=1265425712&includesoftstates=no&assumestateretention=yes&assumeinitialstates=yes&assumestatesduringnotrunning=yes&initialassumedhoststate=0&backtrack=4&rpttimeperiod='.$timeperiod,
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Host and Service State Trends',
    );
}

for my $url (@{$reports}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => [ 'Host and Service State Trends', 'Duration: ' ],
    );
}

for my $url (@{$pictures}) {
    TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'image/png',
    );
}
