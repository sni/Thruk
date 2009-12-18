use strict;
use warnings;
use Test::More tests => 95;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::cmd' }

for my $file (glob("templates/cmd/cmd*")) {
    if($file =~ m/templates\/cmd\/cmd_typ_(\d+)\.tt/mx) {
        ok( request('/cmd?cmd_typ='.$1)->is_success, 'Request should succeed: cmd typ: '.$1 );
    }
}

