use strict;
use warnings;
use Test::More;
use Data::Dumper;

eval "use Test::Cmd";
plan skip_all => 'Test::Cmd required' if $@;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $BIN = defined $ENV{'CATALYST_SERVER'} ? '/usr/bin/thruk' : './script/thruk';

my $oldextsrv = $ENV{'CATALYST_SERVER'};
delete $ENV{'CATALYST_SERVER'};

TestUtils::test_command({
    cmd  => $BIN.' -l',
    like => ['/\s+\*\s*\w{5}\s*\w+/',
             '/Def\s+Key\s+Name/'
            ],
});

# Excel export
TestUtils::test_command({
    cmd  => '/bin/sh -c \''.$BIN.' -A thrukadmin -a "url=status.cgi?view_mode=xls&host=all" > /tmp/allservices.xls\'',
});
TestUtils::test_command({
    cmd  => '/usr/bin/file /tmp/allservices.xls',
    like => ['/(Microsoft Office|CDF V2) Document/',
            ],
});
unlink('/tmp/allservices.xls');

# restore env
defined $oldextsrv ? $ENV{'CATALYST_SERVER'} = $oldextsrv : delete $ENV{'CATALYST_SERVER'};
done_testing();
