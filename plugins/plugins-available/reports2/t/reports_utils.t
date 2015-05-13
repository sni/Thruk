use strict;
use warnings;
use Test::More;
use Data::Dumper;

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan tests => 17;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok("Thruk::Utils::Reports::Render");
$Thruk::Utils::Reports::Render::c = TestUtils::get_c();

###########################################################
# _replace_link
my($baseurl,$a,$b,$url,$d,$e) = ('http://test.local/thruk/cgi-bin/', '', '',  '', '', '');

$url = '#';
is(Thruk::Utils::Reports::Render::_replace_link($baseurl,$a,$b,$url,$d,$e), "#", "_replace_link($url)");

$url = 'avail.cgi';
is(Thruk::Utils::Reports::Render::_replace_link($baseurl,$a,$b,$url,$d,$e), "http://test.local/thruk/cgi-bin/avail.cgi", "_replace_link($url)");

$url = '/index.html';
is(Thruk::Utils::Reports::Render::_replace_link($baseurl,$a,$b,$url,$d,$e), "http://test.local/index.html", "_replace_link($url)");


###########################################################
# page_splice
my $data  = [0..33];
my $paged = Thruk::Utils::Reports::Render::page_splice($data, 7, 3);
is(scalar @{$paged}, 3, "page_splice() pages size");
is(scalar @{$paged->[0]}, 7, "page_splice() slice size");

$paged = Thruk::Utils::Reports::Render::page_splice($data, 7, 20);
is(scalar @{$paged}, 5, "page_splice() pages size");
is(scalar @{$paged->[0]}, 7, "page_splice() slice size");
is(scalar @{$paged->[4]}, 6, "page_splice() slice size");

###########################################################
# _absolutize_url
my $urls = [
    [ 'http://test.com',                'test.html',            'http://test.com/test.html' ],
    [ 'http://test.com/',               'test.html',            'http://test.com/test.html' ],
    [ '',                               '/thruk/test.html',     '/thruk/test.html' ],
    [ 'http://test.com/blah/',          '../test.html',         'http://test.com/test.html' ],
    [ 'http://test.com/blah/',          '/test.html',           'http://test.com/test.html' ],
    [ 'http://test.com/css/style.css',  '../images/test.png',   'http://test.com/images/test.png' ],
    [ 'http://test.com/css/style.css',  '/test.png',            'http://test.com/test.png' ],
    [ 'http://test.com',                'http://test2.com/',    'http://test2.com/' ],
];
for my $url (@{$urls}) {
    is(Thruk::Utils::Reports::Render::_absolutize_url($url->[0], $url->[1]), $url->[2], '_absolutize_url('.($url->[0]||'').', '.$url->[1].') -> '.$url->[2]);
}
