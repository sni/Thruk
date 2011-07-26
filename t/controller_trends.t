use strict;
use warnings;
use Test::More tests => 56;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

BEGIN { use_ok 'Thruk::Controller::trends' }

my($host,$service) = TestUtils::get_test_service();

my $pages = [
# Step 1
    '/thruk/cgi-bin/trends.cgi',
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
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Host and Service State Trends',
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}

for my $url (@{$pictures}) {
    TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'image/png',
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}
