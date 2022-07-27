use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 34;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
{
    my $test = {
        cmd    => '/usr/bin/env thruk -l',
        like   => ['/tier1a/', '/tier3a/'],
    };
    TestUtils::test_command($test);
    is(scalar(split/\n/, $test->{'stdout'}), 11, "output number of lines ok");
};

###########################################################
{
    my $test = {
        cmd    => '/usr/bin/env thruk -l -b tier2a',
        like   => ['/tier2a/'],
    };
    TestUtils::test_command($test);
    is(scalar(split/\n/, $test->{'stdout'}), 5, "output number of lines ok");
};

###########################################################
{
    my $test = {
        cmd    => '/usr/bin/env thruk -l -b tier3b',
        like   => ['/tier3b/'],
    };
    TestUtils::test_command($test);
    is(scalar(split/\n/, $test->{'stdout'}), 5, "output number of lines ok");
};

###########################################################
{
    my $test = {
        cmd    => '/usr/bin/env thruk -l -b Default',
        like   => ['/tier1a/', '/tier2b/', '/tier2c/'],
    };
    TestUtils::test_command($test);
    is(scalar(split/\n/, $test->{'stdout'}), 8, "output number of lines ok");
};

###########################################################
{
    my $test = {
        cmd    => '/usr/bin/env thruk -l -b /Default',
        like   => ['/tier1a/', '/tier2b/', '/tier2c/'],
    };
    TestUtils::test_command($test);
    is(scalar(split/\n/, $test->{'stdout'}), 8, "output number of lines ok");
};
