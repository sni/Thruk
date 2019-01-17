use strict;
use warnings;
use Test::More;
use HTML::Entities;
use Cpanel::JSON::XS;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 528;
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
is(scalar keys %{$ids}, 8, 'got backend ids') || die("all backends required");
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
TestUtils::test_command({
    cmd     => './script/thruk selfcheck lmd',
    like => ['/lmd running with pid/',
             '/8\/8 backends online/',
            ],
    exit    => 0,
});

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
                ],
    );
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
    for my $url (sort @matches) {
        $url =~ s|'||gmx;
        TestUtils::test_page(
            'waitfor'        => '(grafana\-app|\/pnp4nagios\/index\.php\/image)',
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
# logcache test
for my $name (qw/tier2a tier3a/) {
    my $id = $ids->{"tier2a"};
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/proxy.cgi/'.$id.'/demo/thruk/cgi-bin/showlog.cgi?pattern='.$name.'&backend='.$ids->{$name},
        'waitfor'=> 'EXTERNAL\ COMMAND:',
    );
    my $unlike = [ 'internal server error', 'HASH', 'ARRAY' ];
    if($name eq 'tier2a') {
        push @{$unlike}, qw/;tier2b; ;tier3a; ;tier3b; ;tier1a;/;
    }
    if($name eq 'tier3a') {
        push @{$unlike}, qw/;tier2b; ;tier3b; ;tier1a;/;
    }
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/proxy.cgi/'.$id.'/demo/thruk/cgi-bin/showlog.cgi?pattern='.$name.'&backend='.$ids->{$name},
        'like'   => [
                    'Event Log',
                    'EXTERNAL COMMAND: SCHEDULE_FORCED_SVC_CHECK;'.$name,
                ],
        'unlike' => $unlike,
    );
}
for my $name (qw/tier1a tier2a tier3a/) {
    my $id = $ids->{"tier1a"};
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/proxy.cgi/'.$id.'/demo/thruk/cgi-bin/showlog.cgi?pattern='.$name.'&backend='.$ids->{$name},
        'waitfor'=> 'EXTERNAL\ COMMAND:',
    );
    my $unlike = [ 'internal server error', 'HASH', 'ARRAY' ];
    if($name eq 'tier1a') {
        push @{$unlike}, qw/;tier1b; ;tier2a; ;tier2b; ;tier2c; ;tier3a; ;tier3b;/;
    }
    if($name eq 'tier2a') {
        push @{$unlike}, qw/;tier2b; ;tier3a; ;tier3b; ;tier1a;/;
    }
    if($name eq 'tier3a') {
        push @{$unlike}, qw/;tier2b; ;tier3b; ;tier1a;/;
    }
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/proxy.cgi/'.$id.'/demo/thruk/cgi-bin/showlog.cgi?pattern='.$name.'&backend='.$ids->{$name},
        'like'   => [
                    'Event Log',
                    'EXTERNAL COMMAND: SCHEDULE_FORCED_SVC_CHECK;'.$name,
                ],
        'unlike' => $unlike,
    );
}

###############################################################################
# federated business processes
TestUtils::test_page(
    'url'  => '/thruk/cgi-bin/bp.cgi',
    'like' => ['tier1a bp', 'tier2a bp', 'tier3a bp', 'tier3b bp'],
);
for my $name (qw/tier1a tier2a tier3a tier3b/) {
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/bp.cgi?action=details&bp='.$ids->{$name}.':1',
        'like'   => [$name.' bp', 'Refresh Status'],
        'follow' => 1,
    );
}
# set some services to broken
for my $hst (qw/tier3a tier3b/) {
    for my $svc (qw/Ping Load/) {
        TestUtils::test_page(
            'url'    => '/thruk/r/services/'.$hst.'/'.$svc.'/cmd/disable_svc_check',
            'method' => 'POST',
            'like'   => [ 'Command successfully submitted' ],
        );
        TestUtils::test_page(
            'url'    => '/thruk/r/services/'.$hst.'/'.$svc.'/cmd/process_service_check_result',
            'method' => 'POST',
            'post'   => { plugin_state => 2, plugin_output => "broken" },
            'like'   => [ 'Command successfully submitted' ],
        );
    }
}