use warnings;
use strict;
use Cpanel::JSON::XS;
use HTML::Entities;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
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
done_testing();
