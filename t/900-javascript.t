use strict;
use warnings;
use Test::More;
use Data::Dumper;
use Cwd;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR_JS} to a true value to run.' unless $ENV{TEST_AUTHOR_JS};
plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
eval "use WWW::Mechanize::Firefox";
plan skip_all => 'WWW::Mechanize::Firefox required' if $@;

my $pidfile  = getcwd."/test.pid";
my $testport = 51234;

#####################################################################
# start test catalyst server
$SIG{INT} = sub { do_clean_exit(); };
END {
    do_clean_exit();
};
my $cmd="./script/thruk_server.pl --pidfile=$pidfile --port=$testport --background";
my $out = `$cmd`;
my $rc = $?;
ok($rc == 0, 'test server started') or BAIL_OUT('need test server');
my $pid = `cat $pidfile`;
ok($pid > 0, 'got a pid from '.$pidfile) or BAIL_OUT('need test server');
`ps -p $pid`;
ok($? == 0, 'test server alive') or BAIL_OUT('need test server');

#####################################################################
# start mechanizer
$ENV{'DISPLAY'} = ':0.0';
my $mech = WWW::Mechanize::Firefox->new(
             launch   => '/usr/bin/firefox', # launch if needed
             activate => 1,                  # active current tab
);
isa_ok($mech, 'WWW::Mechanize::Firefox');

#####################################################################
# do some requests
my($host,$service) = TestUtils::get_test_service();
my $servicegroup   = TestUtils::get_test_servicegroup();
my $hostgroup      = TestUtils::get_test_hostgroup();
my $timeperiod     = TestUtils::get_test_timeperiod();

# get pages from other tests
my @pages = `grep '/thruk/cgi-bin' t/*.t t/xt/*/*.t`;
my @cleanpages;
for my $page (@pages) {
    chomp($page);
    $page =~ s/("|')\.\$hostgroup(\."|\.'|,)/$hostgroup/mx;
    $page =~ s/("|')\.\$host(\."|\.'|,)/$host/mx;
    $page =~ s/("|')\.\$servicegroup(\."|\.'|,)/$servicegroup/mx;
    $page =~ s/("|')\.\$service(\."|\.'|,)/$service/mx;
    $page =~ s/("|')\.\$timeperiod(\."|\.'|,)/$timeperiod/mx;
    next unless $page =~ m#^.*:\s*('|"|)(/thruk/[^'"]+)('|"|,|$)#mx;
    $page = $2;
    push @cleanpages, $page;
}

for my $page (sort @cleanpages) {
    $mech->clear_js_errors();
    my $res;
    ok($page, $page);
    eval {
        $res = $mech->get('http://localhost:'.$testport.$page);
    };
    fail($@) if $@;
    isa_ok($res, 'HTTP::Response');
    ok($res->is_success, $page.' is_success');
    check_js_errors($mech->js_errors());
}

do_clean_exit();
done_testing();


#####################################################################
# SUBS
#####################################################################
sub do_clean_exit {
    kill(15, $pid)   if defined $pid;
    unlink($pidfile) if defined $pidfile;
}

#####################################################################
sub check_js_errors {
    for my $err (@_) {
        next if $err->{'message'} =~ m/JavaScript\ Warning:/mx;
        fail($err->{'message'});
    }
    return;
}
