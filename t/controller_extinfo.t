use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 22;

BEGIN { use_ok 'Catalyst::Test', 'Thruk' }
BEGIN { use_ok 'Thruk::Controller::extinfo' }

ok( request('/extinfo')->is_success, 'Extinfo Request should succeed' );
ok( request('/thruk/cgi-bin/extinfo.cgi')->is_success, 'Extinfo Request should succeed' );

for(0..8) {
    my $type = $_;
    my $extra = "";
    if($type == 1) { $extra = '&host=test_host_00';                    }
    if($type == 2) { $extra = '&host=test_host_07&service=test_ok_00'; }
    if($type == 5) { $extra = '&hostgroup=down';                       }
    if($type == 8) { $extra = '&servicegroup=flap';                    }

    my $request = request('/thruk/cgi-bin/extinfo.cgi?type='.$type.$extra);
    ok( $request->is_success, 'Extinfo Type '.$type.' Request should succeed' ) or diag(Dumper($request));
    my $content = $request->content;
    unlike($content, qr/internal\ server\ error/mx, "Content contains error");
}
