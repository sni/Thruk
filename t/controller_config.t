use strict;
use warnings;
use Test::More tests => 6;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::config' }

ok( request('/config')->is_success, 'Config Request should succeed' );

my $request = request('/nagios/cgi-bin/config.cgi');
ok( $request->is_success, 'Config Request should succeed' );
my $content = $request->content;
TODO: {
    local $TODO = "needs to be implemented";
    like($content, qr/Configuration/, "Content contains: Configuration");
};
unlike($content, qr/errorMessage/mx, "Content doesnt contains: errorMessage");