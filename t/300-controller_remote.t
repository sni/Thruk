use warnings;
use strict;
use Test::More tests => 37;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
    $ENV{'THRUK_TEST_NO_LOG'} = 1;
}

use_ok 'Thruk::Controller::remote';
use_ok 'Thruk::Config';

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
    'like'         => '(already compiled|\d+ templates precompiled in \d+\.\d+s)',
    'skip_doctype' => 1,
);

TestUtils::test_page(
    'url'          => '/thruk/cgi-bin/remote.cgi?log',
    'post'         => { 'test log data' => '' },
    'like'         => 'OK',
    'skip_doctype' => 1,
);

# make sure we have a secret key
if(!Thruk::Config::secret_key()) {
    require Thruk;
    local $ENV{'THRUK_MODE'} = 'FASTCGI';
    Thruk::_create_secret_file();
}
TestUtils::test_page(
    'url'          => '/thruk/cgi-bin/remote.cgi',
    'post'         => { data => '{"options":{"action": "raw", "sub":"get_processinfo"},"credential":"'.Thruk::Config::secret_key().'"}' },
    'like'         => ['version', 'configtool', 'data_source_version'],
    'unlike'       => ['ARRAY'],
);
