use strict;
use warnings;
use Test::More;

plan tests => 11;

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

