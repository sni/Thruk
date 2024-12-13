use warnings;
use strict;
use Cpanel::JSON::XS qw/decode_json/;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan skip_all => 'local test only'   if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan skip_all => 'test skipped'      if defined $ENV{'NO_DISABLED_PLUGINS_TEST'};

    plan tests => 32;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###########################################################
# test modules
unshift @INC, 'plugins/plugins-available/node-control/lib';
use_ok 'Thruk::Controller::node_control';

###########################################################
# test main page
TestUtils::test_page(
    'url'             => '/thruk/cgi-bin/node_control.cgi',
    'like'            => 'Node Control',
);

###########################################################
# test rest api
{
    my $page = TestUtils::test_page(
        'url'          => '/thruk/r/thruk/nc/nodes',
        'content_type' => 'application/json; charset=utf-8',
    );
    my $data = decode_json($page->{'content'});
    ok(ref $data eq 'ARRAY', "got json data");
    ok(scalar @{$data} > 0, "got json data");
    ok($data->[0]->{'peer_name'}, "got json data");
}
{
    my $page = TestUtils::test_page(
        'url'          => '/thruk/r/thruk/node-control/nodes',
        'content_type' => 'application/json; charset=utf-8',
    );
    my $data = decode_json($page->{'content'});
    ok(ref $data eq 'ARRAY', "got json data");
    ok(scalar @{$data} > 0, "got json data");
    ok($data->[0]->{'peer_name'}, "got json data");
}
