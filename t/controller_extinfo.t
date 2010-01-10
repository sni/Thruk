use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 25;

BEGIN { use_ok 'Catalyst::Test', 'Thruk' }
BEGIN { use_ok 'Thruk::Controller::extinfo' }

ok( request('/extinfo')->is_success, 'Extinfo Request should succeed' );
ok( request('/thruk/cgi-bin/extinfo.cgi')->is_success, 'Extinfo Request should succeed' );

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

for(0..8) {
    my $type = $_;
    my $extra = "";
    if($type == 1) { $extra = '&host='.$host;                      }
    if($type == 2) { $extra = '&host='.$host.'&service='.$service; }
    if($type == 5) { $extra = '&hostgroup=down';                   }
    if($type == 8) { $extra = '&servicegroup=flap';                }

    my $request = request('/thruk/cgi-bin/extinfo.cgi?type='.$type.$extra);
    ok( $request->is_success, 'Extinfo Type '.$type.' Request should succeed' ) or diag(Dumper($request));
    my $content = $request->content;
    unlike($content, qr/internal\ server\ error/mx, "Content contains error");
}
