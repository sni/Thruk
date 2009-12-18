use strict;
use warnings;
use Test::More tests => 188;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::cmd' }

for my $file (glob("templates/cmd/*")) {
    if($file eq '.' or $file eq '..') {}
    elsif($file =~ m/templates\/cmd\/cmd_typ_(\d+)\.tt/mx) {
        my $request = request('/cmd?cmd_typ='.$1);
        ok( $request->is_success, 'Request should succeed: cmd typ: '.$1 );
        my $content = $request->content;
        unlike($content, qr/errorMessage/mx, "Content doesnt contains: errorMessage");
    }
    else {
        BAIL_OUT("found file which does not match cmd template: ".$file);
    }
}
