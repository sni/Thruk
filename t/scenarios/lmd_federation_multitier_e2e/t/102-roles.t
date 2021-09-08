use warnings;
use strict;
use Cpanel::JSON::XS;
use HTML::Entities;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 39;
}


BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###############################################################################
# fetch backend ids
my $test = TestUtils::test_page(
    'url'    => '/thruk/cgi-bin/extinfo.cgi?type=0&view_mode=json',
    'like'   => [
                'peer_addr',
                'https://127.0.0.3:60443/demo/thruk/',
                'data_source_version',
            ],
);
my $procinfo = Cpanel::JSON::XS::decode_json($test->{'content'});
my $ids      = {map { $_->{'peer_name'} => $_->{'peer_key'} } values %{$procinfo}};
is(scalar keys %{$ids}, 10, 'got backend ids') || die("all backends required");
ok(defined $ids->{'tier1a'}, 'got backend ids II');

###############################################################################
# test role propagation
for my $name (qw/tier1a tier2a/) {
    my $id = $ids->{$name};
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/proxy.cgi/'.$id.'/demo/thruk/cgi-bin/user.cgi',
        'like'   => [
                    'Effective Roles',
                    'authorized_for_admin',
                    'User Profile',
                    qr"var cookie_path = '/thruk/cgi-bin/proxy.cgi/$id/demo/'",
                ],
    );
}

###############################################################################
