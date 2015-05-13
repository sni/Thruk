use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 2374;
}

BEGIN {
    $ENV{'THRUK_TEST_CMD_NO_LOG'} = 1;
    use lib('t');
    require TestUtils;
    import TestUtils;
}

BEGIN { use_ok 'Thruk::Controller::cmd' }

TestUtils::set_test_user_token();
my($host,$service) = TestUtils::get_test_service();
my $hostgroup      = TestUtils::get_test_hostgroup();
my $servicegroup   = TestUtils::get_test_servicegroup();
my $post           = { test_only => 1, cmd_mod => 2, host => $host, 'service' => $service, 'servicegroup' => $servicegroup, 'hostgroup' => $hostgroup };

for my $file (sort glob("templates/cmd/*")) {
    next if($file eq '.' or $file eq '..');

    # normal commands
    if($file =~ m/templates\/cmd\/cmd_typ_(\d+)\.tt/mx) {
        $post->{cmd_typ} = $1;
        TestUtils::test_page(
            'url'     => '/thruk/cgi-bin/cmd.cgi?cmd_typ='.$1,
            'like'    => 'External Command Interface',
        );
        TestUtils::test_page(
            'url'     => '/thruk/cgi-bin/cmd.cgi',
            'post'    => $post,
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
        BAIL_OUT("$0: found file which does not match cmd template: ".$file);
    }
}
