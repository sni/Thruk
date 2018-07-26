use strict;
use warnings;
use Test::More;
use URI::Escape;

eval "use Test::Cmd";
plan skip_all => 'Test::Cmd required' if $@;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $config = Thruk::config;
plan skip_all => 'objects_save_file not set' unless $config->{'Thruk::Plugin::BP'}->{'objects_save_file'};

my $BIN = defined $ENV{'THRUK_BIN'} ? $ENV{'THRUK_BIN'} : './script/thruk';
$BIN    = $BIN.' --local' unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

###########################################################
# create test BP
TestUtils::set_test_user_token();
my $test = TestUtils::test_page(url => '/thruk/cgi-bin/bp.cgi?action=new&bp_label=New Test Business Process', follow => 1, like => 'New Test Business Process');
$test->{'content'} =~ m|\&amp;bp=(\d+)\&amp;|mx;
my $bpid = $1;
ok($bpid, "got bp id: ".$bpid) or BAIL_OUT("got no bp id, cannot test");
TestUtils::test_page(url => '/thruk/cgi-bin/bp.cgi', post => { 'action' => 'commit', 'bp' => $bpid }, follow => 1, like => 'business process updated sucessfully');

my $test_pdf_reports = [{
        'name'                   => 'New Test Business Process Report',
        'template'               => 'sla_business_process.tt',
        'params.sla'             => 95,
        'params.graph_min_sla'   => 90,
        'params.decimals'        => 2,
        'params.timeperiod'      => 'last12months',
        'params.businessprocess' => "New Test Business Process",
        'params.breakdown'       => 'months',
        'params.unavailable'     => [ 'critical', 'unknown' ],
        'params.includeoutages'  => 1,
    }
];

###########################################################
# test report
for my $report (@{$test_pdf_reports}) {
    # create report
    my $args = [];
    for my $key (keys %{$report}) {
        for my $val (ref $report->{$key} eq 'ARRAY' ? @{$report->{$key}} : $report->{$key}) {
            push @{$args}, $key.'='.$val;
        }
    }
    TestUtils::test_command({
        cmd  => $BIN.' "/thruk/cgi-bin/reports2.cgi?action=save&report=9999&'.join('&', @{$args}).'"',
        like => ['/^OK - report updated$/'],
    });

    my $like = [];
    if(!defined $report->{'type'} or $report->{'type'} eq 'pdf') {
        $like = [ '/%PDF\-1\.4/', '/%%EOF/' ];
    }
    elsif($report->{'type'} eq 'xls') {
        $like = [ '/Arial1/', '/Tahoma1/' ];
    }
    elsif($report->{'type'} eq 'html') {
        $like = [ '/<html/' ];
    }

    # make sure sla reports contain the graph
    if($report->{'template'} =~ m/^sla_/mx) {
        push @{$like}, '/Width 530/';
        push @{$like}, '/Height 300/';
    }

    # generate report
    TestUtils::test_command({
        cmd  => $BIN.' -a report=9999 --local',
        like => $like,
    }) or BAIL_OUT("report failed in ".$0);
    TestUtils::test_command({
        cmd  => $BIN.' -a report=9999',
        like => $like,
    });

    # update report
    TestUtils::test_command({
        cmd  => $BIN.' "/thruk/cgi-bin/reports2.cgi?action=update&report=9999"',
        like => ['/^OK - report scheduled for update$/'],
    });

    TestUtils::test_page(
        url     => '/thruk/cgi-bin/reports2.cgi',
        waitfor => 'reports2.cgi\?report=9999\&amp;refresh=0',
        unlike => '<span[^>]*style="color:\ red;".*?\'([^\']*)\'',
    );
}

# remove report
TestUtils::test_command({
    cmd  => $BIN.' "/thruk/cgi-bin/reports2.cgi?action=remove&report=9999"',
    like => ['/^OK - report removed$/'],
});

# remove bp
TestUtils::test_page(url => '/thruk/cgi-bin/bp.cgi', post => { 'action' => 'remove', 'bp' => $bpid }, follow => 1, like => 'business process sucessfully removed');

done_testing();
