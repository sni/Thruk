use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-f 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan tests => 2365;
}

BEGIN {
    $ENV{'THRUK_TEST_CMD_NO_LOG'} = 1;
    use lib('t');
    require TestUtils;
    import TestUtils;
}

BEGIN { use_ok 'Thruk::Controller::cmd' }

for my $file (sort glob("templates/cmd/*")) {
    if($file eq '.' or $file eq '..') {}
    elsif($file =~ m/templates\/cmd\/cmd_typ_(\d+)\.tt/mx) {
        TestUtils::test_page(
            'url'     => '/thruk/cgi-bin/cmd.cgi?cmd_typ='.$1,
            'like'    => 'External Command Interface',
        );
        TestUtils::test_page(
            'url'     => '/thruk/cgi-bin/cmd.cgi?cmd_typ='.$1.'&cmd_mod=2&test_only=1',
            'like'    => 'External Command Interface',
        );
    }
    elsif($file =~ m/templates\/cmd\/cmd_typ_c(\d+)\.tt/mx) {
        TestUtils::test_page(
            'url'     => '/thruk/cgi-bin/cmd.cgi?quick_command='.$1.'&confirm=no',
            'like'    => 'External Command Interface',
        );
    }
    else {
        BAIL_OUT("found file which does not match cmd template: ".$file);
    }
}
