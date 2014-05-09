use strict;
use warnings;
use Test::More;
use JSON::XS;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan tests => 192;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

    use_ok 'Thruk::Controller::panorama';
};

my $pages = [
    { url => '/thruk/cgi-bin/panorama.cgi', like => 'Thruk Panorama' },
    { url => '/thruk/cgi-bin/panorama.cgi?readonly=1', like => 'Thruk Panorama' },
    { url => '/thruk/usercontent/backgrounds/world.png', like => 'PNG' },
];


for my $page (@{$pages}) {
    TestUtils::test_page(%{$page});
}

# json pages
$pages = [
    '/thruk/cgi-bin/panorama.cgi?task=server_stats',
    '/thruk/cgi-bin/panorama.cgi?task=stats_core_metrics',
    '/thruk/cgi-bin/panorama.cgi?task=stats_check_metrics',
    '/thruk/cgi-bin/panorama.cgi?task=show_logs',
    '/thruk/cgi-bin/panorama.cgi?task=site_status',
    '/thruk/cgi-bin/panorama.cgi?task=hosts',
    '/thruk/cgi-bin/panorama.cgi?task=hosttotals',
    '/thruk/cgi-bin/panorama.cgi?task=hosts_pie',
    '/thruk/cgi-bin/panorama.cgi?task=services',
    '/thruk/cgi-bin/panorama.cgi?task=servicetotals',
    '/thruk/cgi-bin/panorama.cgi?task=services_pie',
    '/thruk/cgi-bin/panorama.cgi?task=stats_gearman',
    '/thruk/cgi-bin/panorama.cgi?task=stats_gearman_grid',
    '/thruk/cgi-bin/panorama.cgi?task=pnp_graphs',
    '/thruk/cgi-bin/panorama.cgi?task=dashboard_list',
    '/thruk/cgi-bin/panorama.cgi?task=userdata_backgroundimages',
    '/thruk/cgi-bin/panorama.cgi?task=userdata_images',
    '/thruk/cgi-bin/panorama.cgi?task=userdata_sounds',
];

for my $url (@{$pages}) {
    my $page = TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/json; charset=utf-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'HASH', "json result is an array: ".$url);
    if($url !~ m/gearman/mx) {
        ok(scalar keys %{$data} > 0, "json result has content: ".$url);
    }
}
