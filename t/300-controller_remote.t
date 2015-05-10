use strict;
use warnings;
use Test::More tests => 41;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::remote' }

TestUtils::test_page(
    'url'          => '/thruk/cgi-bin/remote.cgi',
    'like'         => 'OK',
    'skip_doctype' => 1,
);

TestUtils::test_page(
    'url'          => '/thruk/cgi-bin/remote.cgi?startup',
    'like'         => 'startup done',
    'skip_doctype' => 1,
);

TestUtils::test_page(
    'url'          => '/thruk/cgi-bin/remote.cgi?compile',
    'like'         => '\d+ templates precompiled in \d+\.\d+s',
    'skip_doctype' => 1,
);

TestUtils::test_page(
    'url'          => '/thruk/cgi-bin/remote.cgi?log',
    'post'         => { 'test log data' => '' },
    'like'         => 'OK',
    'skip_doctype' => 1,
);

