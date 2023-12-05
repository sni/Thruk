use warnings;
use strict;
use Cpanel::JSON::XS;
use HTML::Entities;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 64;
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
is(scalar keys %{$ids}, 12, 'got backend ids') || die("all backends required");
ok(defined $ids->{'tier1a'}, 'got backend ids II');

###########################################################
# backend selection by section
{
    my $test = {
        cmd    => './script/thruk -l',
        like   => ['/tier1a/', '/tier2b/', '/tier2c/'],
    };
    TestUtils::test_command($test);
    is(scalar(split/\n/, $test->{'stdout'}), 16, "output number of lines ok");

    $test = {
        cmd    => './script/thruk -l -b tier1a/tier2a',
        like   => ['/tier2a/', '/tier3a/', '/tier3b/'],
    };
    TestUtils::test_command($test);
    is(scalar(split/\n/, $test->{'stdout'}), 8, "output number of lines ok");

    $test = {
        cmd    => './script/thruk -l -b /tier1a/tier2a',
        like   => ['/tier2a/', '/tier3a/', '/tier3b/'],
    };
    TestUtils::test_command($test);
    is(scalar(split/\n/, $test->{'stdout'}), 8, "output number of lines ok");

    $test = {
        cmd    => './script/thruk -l -b /tier1a/tier2a/',
        like   => ['/tier2a/', '/tier3a/', '/tier3b/'],
    };
    TestUtils::test_command($test);
    is(scalar(split/\n/, $test->{'stdout'}), 8, "output number of lines ok");

    $test = {
        cmd    => './script/thruk -l -b /tier1a',
        like   => ['/tier2a/', '/tier3a/', '/tier3b/'],
    };
    TestUtils::test_command($test);
    is(scalar(split/\n/, $test->{'stdout'}), 12, "output number of lines ok");

    $test = TestUtils::test_page(
        'url'    => '/thruk/r/csv/processinfo?columns=peer_name&backends=/tier1d',
        'like'   => [ 'tier1d', 'tier2d' ],
    );
    is(scalar(split/\n/, $test->{'content'}), 3, "output number of lines ok");

    $test = TestUtils::test_page(
        'url'    => '/thruk/r/csv/processinfo?columns=peer_name&backends=tier1a/tier2a',
        'like'   => [ 'tier2a', 'tier3a' ],
    );
    is(scalar(split/\n/, $test->{'content'}), 5, "output number of lines ok");
};

###############################################################################
