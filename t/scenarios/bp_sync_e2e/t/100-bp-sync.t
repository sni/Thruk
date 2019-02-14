use strict;
use warnings;
use Test::More;

BEGIN {
    plan tests => 27;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

$ENV{'THRUK_TEST_AUTH'} = 'omdadmin:omd';

my $page = TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/status.cgi?host=all',
    'waitfor' => 'Test\ BP',
);
my $link;
if($page->{'content'} =~ m/href="(bp\.cgi\?action=details[^"]+)"/mx) {
    $link = $1;
    $link =~ s/&amp;/&/gmx;
}
ok($link, "got bp link");

TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/bp.cgi',
    'waitfor' => 'Test\ BP',
);

TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/bp.cgi',
    'like'    => ['Test BP'],
);

TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/'.$link,
    'like'    => ['Test BP'],
);