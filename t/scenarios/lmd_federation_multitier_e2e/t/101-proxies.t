use warnings;
use strict;
use Cpanel::JSON::XS;
use HTML::Entities;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 124;
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
is(scalar keys %{$ids}, 11, 'got backend ids') || die("all backends required");
ok(defined $ids->{'tier1a'}, 'got backend ids II');

###############################################################################
# make sure all proxies work
{
    my $like = ["Service Status Details For All Host"];
    for my $backend (sort keys %{$ids}) {
        push @{$like}, '/thruk/cgi-bin/proxy.cgi/'.$ids->{$backend}.'/demo/';
    }
    my $test = TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/status.cgi?host=all',
        'like'   => $like,
    );
    my @matches = $test->{'content'} =~ m|'/thruk/cgi-bin/proxy\.cgi/[^']+'|gmx;
    map { $_ =~ s|&amp;|&|gmx; $_ =~ s|'||gmx } @matches;
    @matches = grep(/(srv|service|)=Load/mx, @matches);
    @matches = grep(!/\/popup/mx, @matches);
    @matches = grep(!/-solo\//, @matches);
    is(scalar @matches, 11, 'got all proxy links');
    for my $url (sort @matches) {
        $url =~ s|'||gmx;
        next if $url =~ m/tier1d/mx; # does not work with basic auth
        next if $url =~ m/tier2d/mx; # does not work with basic auth
        TestUtils::test_page(
            'waitfor'        => '(grafanaBootData|grafana\-app|\/pnp4nagios\/index\.php\/image)',
            'url'            => $url,
            'skip_html_lint' => 1
        );
        TestUtils::test_page(
            'url'            => $url,
            'unlike'         => ['/does not exist/'],
            'skip_html_lint' => 1
        );
    }
}

###############################################################################
