use strict;
use warnings;
use Test::More;
use JSON::XS;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 49;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::status' }

my($host,$service) = TestUtils::get_test_service();

my $pages = [
   { url => '/thruk/cgi-bin/parts.cgi?part=_header_prefs', like => 'Sounds:' },
   { url => '/thruk/cgi-bin/parts.cgi?part=_host_comments&host='.$host, like => 'Author' },
   { url => '/thruk/cgi-bin/parts.cgi?part=_host_downtimes&host='.$host, like => 'Author' },
   { url => '/thruk/cgi-bin/parts.cgi?part=_service_comments&host='.$host.'&service='.$service, like => 'Author' },
   { url => '/thruk/cgi-bin/parts.cgi?part=_service_downtimes&host='.$host.'&service='.$service, like => 'Author' },
];

for my $url (@{$pages}) {
    my $test = TestUtils::make_test_hash($url, {skip_doctype => 1});
    TestUtils::test_page(%{$test});
}
