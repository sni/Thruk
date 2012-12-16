use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan tests => 2372;
}

BEGIN {
    $ENV{'THRUK_TEST_CMD_NO_LOG'} = 1;
    use lib('t');
    require TestUtils;
    import TestUtils;
}

BEGIN { use_ok 'Thruk::Controller::cmd' }

my($host,$service) = TestUtils::get_test_service();
my $hostgroup      = TestUtils::get_test_hostgroup();
my $servicegroup   = TestUtils::get_test_servicegroup();
my $urlext         = '&host='.$host.'&service='.$service.'&servicegroup='.$servicegroup.'&hostgroup='.$hostgroup;

for my $file (sort glob("templates/cmd/*")) {
    next if($file eq '.' or $file eq '..');

    # normal commands
    if($file =~ m/templates\/cmd\/cmd_typ_(\d+)\.tt/mx) {
        TestUtils::test_page(
            'url'     => '/thruk/cgi-bin/cmd.cgi?cmd_typ='.$1.$urlext,
            'like'    => 'External Command Interface',
        );
        TestUtils::test_page(
            'url'     => '/thruk/cgi-bin/cmd.cgi?cmd_typ='.$1.'&cmd_mod=2&test_only=1'.$urlext,
            'like'    => 'External Command Interface',
        );
    }

    # quick commands
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
