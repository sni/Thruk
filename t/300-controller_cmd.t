use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 2121;
}

BEGIN {
    $ENV{'THRUK_TEST_CMD_NO_LOG'} = 1;
    use lib('t');
    require TestUtils;
    import TestUtils;
}

BEGIN { use_ok 'Thruk::Controller::cmd' }

TestUtils::set_test_user_token();
my $c              = TestUtils::get_c();
my($host,$service) = TestUtils::get_test_service();
my $hostgroup      = TestUtils::get_test_hostgroup();
my $servicegroup   = TestUtils::get_test_servicegroup();
my $post           = { test_only => 1, cmd_mod => 2, host => $host, 'service' => $service, 'servicegroup' => $servicegroup, 'hostgroup' => $hostgroup };

# test quick commands
my $backends = $c->{'db'}->get_peers();
SKIP: {
    my $num = 21;
    skip "test is useless with only a single backend",                $num if (scalar @{$backends} <= 1);
    skip "test is requires authorized_for_all_service_commands role", $num if !$c->user->check_user_roles('authorized_for_all_service_commands');
    skip "test is requires authorized_for_all_host_commands role",    $num if !$c->user->check_user_roles('authorized_for_all_host_commands');

    TestUtils::test_page(
        'url'      => '/thruk/cgi-bin/cmd.cgi',
        'post'     => {
              'quick_command'       => '1',
              'selected_hosts'      => '',
              'selected_services'   => "host1;svc1;".$backends->[0]->{'key'}.',host1;svc1;'.$backends->[1]->{'key'},
              'spread'              => '0',
              'start_time'          => POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time()+10)),
              'referer'             => 'status.cgi',
        },
        'like'     => 'This item has moved',
        'redirect' => 1,
    );
    like($ENV{'THRUK_TEST_CMD_NO_LOG'}, '/\['.$backends->[0]->{'name'}.'\] cmd: COMMAND \[\d+\] SCHEDULE_SVC_CHECK;host1;svc1;\d+/', 'got first command');
    like($ENV{'THRUK_TEST_CMD_NO_LOG'}, '/\['.$backends->[1]->{'name'}.'\] cmd: COMMAND \[\d+\] SCHEDULE_SVC_CHECK;host1;svc1;\d+/', 'got second command');

    $ENV{'THRUK_TEST_CMD_NO_LOG'} = 1;
    TestUtils::test_page(
        'url'      => '/thruk/cgi-bin/cmd.cgi',
        'post'     => {
              'cmd_mod'      => '2',
              'cmd_typ'      => '11',
              'start_time'   => POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time()+10)),
              'referer'      => 'status.cgi',
              'backend'      => [$backends->[0]->{'key'}, $backends->[1]->{'key'}],
        },
        'like'     => 'This item has moved',
        'redirect' => 1,
    );
    like($ENV{'THRUK_TEST_CMD_NO_LOG'}, '/\['.$backends->[0]->{'key'}.','.$backends->[1]->{'key'}.'\] cmd: COMMAND \[\d+\] DISABLE_NOTIFICATIONS/', 'got combined command');
};

TestUtils::test_page(
    'url'      => '/thruk/cgi-bin/cmd.cgi?cmd_typ=96&host='.$host.'&backend='.$backends->[0]->{'key'}.'&backend='.$backends->[0]->{'key'},
    'like'     => 'Command Options',
);


for my $file (sort glob("templates/cmd/*")) {
    next if($file eq '.' or $file eq '..');

    # normal commands
    if($file =~ m/templates\/cmd\/cmd_typ_(\d+)\.tt/mx) {
        next if($1 == 200 || $1 == 201);
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
