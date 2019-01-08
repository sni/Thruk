use strict;
use warnings;
use Test::More;
use HTML::Entities;
use Cpanel::JSON::XS;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 218;
}


BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

$ENV{'THRUK_TEST_CMD_NO_LOG'} = 1;
###############################################################################
TestUtils::test_page(
    'url'    => '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail',
    'like'   => [
                '"total":8', '"disabled":0', '"up":8', ,'"down":0',
            ],
);

###############################################################################
# fetch backend ids
my $test = TestUtils::test_page(
    'url'    => '/thruk/cgi-bin/extinfo.cgi?type=0&view_mode=json',
    'like'   => [
                'peer_addr',
                'https://127.0.0.1:60443/demo/thruk/',
                'data_source_version',
            ],
);
my $procinfo = Cpanel::JSON::XS::decode_json($test->{'content'});
my $ids      = {map { $_->{'peer_name'} => $_->{'peer_key'} } values %{$procinfo}};
is(scalar keys %{$ids}, 8, 'got backend ids');
ok(defined $ids->{'tier1a'}, 'got backend ids II');

###############################################################################
# force reschedule checks
for my $hst (sort keys %{$ids}) {
    TestUtils::test_page(
        'url'    => '/thruk/r/hosts/'.$hst.'/cmd/schedule_forced_host_check',
        'method' => 'POST',
        'like'   => [ 'Command successfully submitted' ],
    );
    for my $svc (qw/Ping Load/) {
        TestUtils::test_page(
            'url'    => '/thruk/r/services/'.$hst.'/'.$svc.'/cmd/schedule_forced_svc_check',
            'method' => 'POST',
            'like'   => [ 'Command successfully submitted' ],
        );
    }
}

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
    is(scalar @matches, 8, 'got all proxy links');
    #for my $url (sort @matches) {
    #    $url =~ s|'||gmx;
    #    my $test = TestUtils::test_page(
    #        'url'    => $url,
    #    );
    #}
}

###############################################################################
TestUtils::test_command({
    cmd     => './script/thruk selfcheck lmd',
    like => ['/lmd running with pid/',
             '/8\/8 backends online/',
            ],
    exit    => 0,
});

###############################################################################
#