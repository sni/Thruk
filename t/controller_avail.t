use strict;
use warnings;
use Test::More tests => 51;

BEGIN { use_ok 'Catalyst::Test', 'Thruk' }
BEGIN { use_ok 'Thruk::Controller::avail' }

ok( request('/avail')->is_success, 'Avail Request should succeed' );
my $request = request('/thruk/cgi-bin/avail.cgi');
ok( $request->is_success, 'Avail Request should succeed' );
my $content = $request->content;
like($content, qr/Availability Report/, "Content contains: Availability Report");
unlike($content, qr/internal\ server\ error/mx, "Content contains error");

# get a sample host / service
my $request = request('/thruk/cgi-bin/status.cgi?host=all');
ok( $request->is_success, 'Extinfo Tests need a proper status page' ) or diag(Dumper($request));
my $page = $request->content;
my($host,$service);
if($page =~ m/extinfo\.cgi\?type=2&amp;host=(.*?)&amp;service=(.*?)&/) {
    $host    = $1;
    $service = $2;
}
isnt($host, undef, "got a host from status.cgi");
isnt($service, undef, "got a host from status.cgi");

my $pages = [
# Step 2
    '/thruk/cgi-bin/avail.cgi?report_type=hosts',
    '/thruk/cgi-bin/avail.cgi?report_type=hostgroups',
    '/thruk/cgi-bin/avail.cgi?report_type=services',
    '/thruk/cgi-bin/avail.cgi?report_type=servicegroups',

# Step 3
    '/thruk/cgi-bin/avail.cgi?get_date_parts=&report_type=hostgroups&hostgroup=down',
    '/thruk/cgi-bin/avail.cgi?get_date_parts=&report_type=hosts&host='.$host,
    '/thruk/cgi-bin/avail.cgi?get_date_parts=&report_type=services&service='.$host.';'.$service,
    '/thruk/cgi-bin/avail.cgi?get_date_parts=&report_type=servicegroups&servicegroup=critical',

# Report
    '/thruk/cgi-bin/avail.cgi?host='.$host.'&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=0&backtrack=4',
    '/thruk/cgi-bin/avail.cgi?host=all&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=0&backtrack=4',
    '/thruk/cgi-bin/avail.cgi?servicegroup=critical&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=0&backtrack=4',
    '/thruk/cgi-bin/avail.cgi?hostgroup=down&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=0&backtrack=4',
    '/thruk/cgi-bin/avail.cgi?services='.$service.'&host='.$host.'&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=0&backtrack=4',
    '/thruk/cgi-bin/avail.cgi?services=all&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=0&backtrack=4',
];

for my $url (@{$pages}) {
    my $request = request($url);
    ok( $request->is_success, 'Request '.$url.' should succeed' );
    my $content = $request->content;
    like($content, qr/Availability Report/, "Content contains: Availability Report");
    unlike($content, qr/internal\ server\ error/mx, "Content contains error");
}