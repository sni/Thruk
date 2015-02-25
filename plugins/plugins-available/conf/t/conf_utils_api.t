use strict;
use warnings;
use Carp;
use utf8;
use Test::More;
use Data::Dumper;
use IO::Socket::UNIX;
use IO::Socket::INET;
use File::Temp qw/tempdir/;
use File::Copy qw/copy/;
use File::Slurp qw/read_file/;
use Storable qw/dclone/;

BEGIN {
    plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
    plan skip_all => 'local test only' if defined $ENV{'CATALYST_SERVER'};
    plan tests => 28;
    $SIG{'ALRM'} = sub { confess('alarm'); };
    alarm(60);
    $ENV{'THRUK_TEST_NO_STDOUT_LOG'} = 1;
}

###########################################################
my $testport;
BEGIN {
    my $start = 50000;
    for my $x (0..99) {
        $testport = $start + $x;
        my $socket = IO::Socket::INET->new(Listen    => 5,
                                           LocalAddr => '127.0.0.1',
                                           LocalPort => $testport,
                                           Proto     => 'tcp');
        last if($socket);
    }
    BAIL_OUT('got no testport') unless $testport;
}

###########################################################
my($http_dir, $local_dir, $input_dir,$test_name);
BEGIN {
    if($ENV{THRUK_LEAK_CHECK}) {
        $input_dir = 'core.d';
        $test_name = 'testname';
    } else {
        $input_dir = 'core.d.utf8';
        $test_name = 'utf8-é';
    }
    # prepare sites
    $http_dir  = tempdir();
    $local_dir = tempdir();
    ok(-d $http_dir, 'got http folder: '.$http_dir);
    ok(-d $local_dir, 'got local folder: '.$local_dir);
    mkdir($http_dir.'/tmp');
    mkdir($local_dir.'/tmp');
    `cp -rp t/xt/conf/data/local/* $local_dir/`;
    `cp -rp t/xt/conf/data/http_api/* $http_dir/`;
    `cp -p thruk.conf $local_dir/`;
    `cp -p thruk.conf $http_dir/`;
    open(my $fh, '>>', $local_dir.'/thruk_local.conf') or die("open failed: ".$!);
    print $fh "var_path  = ".$local_dir."/var\n";
    print $fh "tmp_path  = ".$local_dir."/tmp\n";
    close($fh);
    open($fh, '>>', $http_dir.'/thruk_local.conf') or die("open failed: ".$!);
    print $fh "var_path  = ".$http_dir."/var\n";
    print $fh "tmp_path  = ".$http_dir."/tmp\n";
    close($fh);
    my $cmd = "cat $local_dir/thruk_local.conf | sed -e 's|/tmp/live|$local_dir/tmp/live|g' -e 's|= plugins/.*\$|$local_dir/$input_dir|g' > $local_dir/thruk_local.conf2 && mv $local_dir/thruk_local.conf2 $local_dir/thruk_local.conf";
    `$cmd`;

    $cmd = "cat $http_dir/thruk_local.conf | sed -e 's|%TESTPORT%|$testport|g' > $http_dir/thruk_local.conf2 && mv $http_dir/thruk_local.conf2 $http_dir/thruk_local.conf";
    `$cmd`;

    $ENV{'CATALYST_CONFIG'} = $http_dir;
    use lib('t');
    require TestUtils;
    import TestUtils;
}
use Catalyst::Test 'Thruk';


###########################################################
# start test server
my $httppid = fork();
if(!$httppid) {
    exec("CATALYST_CONFIG=".$local_dir." ./script/waitmax 60 ./script/thruk_server.pl -p ".$testport." >".$http_dir.'/tmp/server.log 2>&1') or
        fail(read_file($http_dir.'/tmp/server.log'));
    exit 1;
}
my $now = time();
for my $x (1..15) {
    my $socket = IO::Socket::INET->new('127.0.0.1:'.$testport);
    last if($socket and $socket->connected());
    sleep(1);
}
ok($httppid, 'test server started: '.$httppid);
sleep(2);
alarm(30);

###########################################################
# start fake live socket
my $socketpid = fork();
if(!$socketpid) {
    $SIG{'INT'}  = sub { exit }; # clean exit
    $SIG{'TERM'} = sub { exit };
    while(1) {
        my $listner = IO::Socket::UNIX->new(
            Type   => SOCK_STREAM,
            Local  => $local_dir.'/tmp/live',
            Listen => SOMAXCONN,
        ) or die("Can't create server socket: $!\n");

        while(my $socket = $listner->accept()) {
            my $query = '';
            while(my $line = <$socket>) {
                chomp($line);
                $query .= $line."\n";
                last if $line eq '';
            }
            if($query =~ m/^GET status/) {
                print $socket '200          81',"\n";
                print $socket '[[1,1,1,0,1,1,1,0,1,1,1364065557,0,"1.2.2b3",31496,0,0,1,1364041912,"3.2.3",60]]',"\n\n";
            }
            elsif($query =~ m/^GET contactgroups/) {
                print $socket '200           3',"\n";
                print $socket '[]',"\n\n";
            }
            elsif($query =~ m/^GET contacts/) {
                print $socket '200          19',"\n";
                print $socket '[[1,"thrukadmin"]]',"\n\n";
            } else {
                diag(Dumper("unknown", $query));
            }
        }
    }
}
ok($socketpid, 'live socket started: '.$socketpid);

###########################################################
# wait till server starts
my $started = 0;
for my $x (1..30) {
    my($res, $c) = ctx_request('/thruk/cgi-bin/extinfo.cgi?type=0');
    if($res->is_success and scalar keys %{$c->stash->{'failed_backends'}} == 0) {
        ok(1, 'server started in '.(time() - $now).'s');
        $started = 1;
        last;
    }
    sleep(1);
}
bail_out_with_kill('server did not start') unless $started;

###########################################################
# init our components
my($res, $c) = ctx_request('/thruk/cgi-bin/conf.cgi?sub=objects');
is(scalar @{$c->stash->{'backends'}}, 1, 'number of backends');
is($c->stash->{'failed_backends'}->{'http'}, undef, 'test connection successful') or bail_out_with_kill("got no connection");

###########################################################
# config backend intialized?
is($c->config->{'var_path'}, $http_dir.'/var', 'got right var folder');
my $rpeer = $c->{'db'}->get_peer_by_key('http');
isa_ok($rpeer, 'Thruk::Backend::Peer');
isa_ok($c->{'obj_db'}, 'Monitoring::Config');
is($c->{'obj_db'}->is_remote(), 1, 'got a remote peer');

###########################################################
# check remote config settings
my $settings = $c->{'obj_db'}->_remote_do($c, 'configsettings');
is_deeply($settings,
          { 'files_root' => $local_dir.'/'.$input_dir },
          'got remote config settings'
);

###########################################################
# config mirror created?
TestUtils::test_command({
    cmd   => '/usr/bin/diff -ru '.$http_dir.'/tmp/localconfcache/http'.$local_dir.'/'.$input_dir.'/'.
                                ' plugins/plugins-available/conf/t/data/local/'.$input_dir.'/',
    like => ['/^$/'],
});

my $service = $c->{'obj_db'}->{'files'}->[0]->{'objects'}->[0];
isa_ok($service, 'Monitoring::Config::Object::Service');
is_deeply($service->{'conf'},
          {
            'name'                  => $test_name,
            'notification_interval' => '0',
            'register'              => 0
          },
          'service has right config'
);

###########################################################
# change test service
my $newdata = dclone($service->{'conf'});
$newdata->{'notification_interval'} = 1;
$c->{'obj_db'}->update_object($service, $newdata);

# save it to disk
$c->{'obj_db'}->commit($c);

# should differ
TestUtils::test_command({
    cmd   => '/usr/bin/diff -ru '.$local_dir.'/'.$input_dir.'/'.
                                ' plugins/plugins-available/conf/t/data/local/'.$input_dir.'',
    like => ['/notification_interval\s+1/'],
    exit => 1,
});

# and change it back
$newdata->{'notification_interval'} = 0;
$c->{'obj_db'}->update_object($service, $newdata);

# save it to disk
$c->{'obj_db'}->commit($c);

# should not differ
TestUtils::test_command({
    cmd   => '/usr/bin/diff -ru '.$local_dir.'/'.$input_dir.'/'.
                                ' plugins/plugins-available/conf/t/data/local/'.$input_dir.'/',
    like => ['/^$/'],
});

###########################################################
# clean up
###########################################################
# stop test server
my $nr = kill(2, $httppid);
ok($nr, 'test http server killed');
$nr = kill(2, $socketpid);
ok($nr, 'test live server killed');
sleep(1);

###########################################################
# really stop test server
END {
    `ps auxww | grep -- '-p $testport' | awk '{ print \$2 }' | xargs kill >/dev/null 2>&1` if $httppid;
    kill(9, $socketpid) if $socketpid;
    `rm -rf $http_dir $local_dir`;
}

###########################################################
sub bail_out_with_kill {
    my($msg) = @_;
    `ps -efl | grep -- '-p $testport' | awk '{ print \$4 }' | xargs kill >/dev/null 2>&1`;
    kill(9, $socketpid)             if $socketpid;
    `rm -rf $http_dir $local_dir`;
    BAIL_OUT($msg);
}

