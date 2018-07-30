use strict;
use warnings;
use Test::More;
use File::Slurp qw/read_file/;
use Cpanel::JSON::XS qw/decode_json/;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 268;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::rest_v1' }

my($host,$service) = TestUtils::get_test_service();

my $list_pages = [
    '/',
    '/v1/',
    '/index',
    '/commands',
    '/comments',
    '/contactgroups',
    '/contacts',
    '/downtimes',
    '/hostgroups',
    '/hosts',
    '/hosts/'.$host,
    '/hosts/'.$host.'/services',
    '/logs',
    '/alerts',
    '/notifications',
    '/processinfo',
    '/servicegroups',
    '/services',
    '/timeperiods',
    '/lmd/sites',
    '/thruk/bp',
    '/thruk/cluster',
    '/thruk/jobs',
    '/thruk/panorama',
    '/thruk/reports',
];

my $hash_pages = [
    '/checks/stats',
    '/hosts/stats',
    '/hosts/totals',
    '/processinfo/stats',
    '/services/stats',
    '/services/totals',
    '/thruk',
    '/thruk/config',
];

for my $url (@{$list_pages}) {
    my $page = TestUtils::test_page(
        'url'          => '/thruk/r'.$url,
        'content_type' => 'application/json;charset=UTF-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'ARRAY', "json result is an array: ".$url);
}


for my $url (@{$hash_pages}) {
    my $page = TestUtils::test_page(
        'url'          => '/thruk/r'.$url,
        'content_type' => 'application/json;charset=UTF-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'HASH', "json result is a hash: ".$url);
}

################################################################################
my $content = read_file(__FILE__);
my($paths, $keys, $docs) = Thruk::Controller::rest_v1::get_rest_paths();
for my $p (sort keys %{$paths}) {
    if($paths->{$p}->{'GET'}) {
        next if $p =~ m%<%mx;
        next if $p =~ m%heartbeat%mx;
        if($content !~ m%$p%mx) {
            fail("missing test case for ".$p);
        }
    }
}
