use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan skip_all => 'local test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan tests => 91;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::broadcast' }

TestUtils::test_page( 'url' => '/thruk/cgi-bin/tac.cgi' );


use_ok 'Thruk::Utils::IO';

#############################
# prepare user and remove all settings
my($res, $c) = ctx_request('/thruk/side.html');
Thruk::Utils::IO::mkdir_r($c->config->{'var_path'}.'/broadcast/');
my $data = Thruk::Utils::get_user_data($c);
delete $data->{'broadcast'};
Thruk::Utils::store_user_data($c, $data);

#############################
# normal broadcasts
my $test_file = $c->config->{'var_path'}.'/broadcast/zzzzzz.json';
my $now = time();
my $test_broadcast =<<EOT;
{
  "text": "<b>test news:</b> time:$now",
  "contacts": [],
  "contactgroups": [],
  "expires": "",
  "hide_before": ""
}
EOT
Thruk::Utils::IO::write($test_file, $test_broadcast);

TestUtils::test_page( 'url' => '/thruk/cgi-bin/tac.cgi', like => ["time:$now"] );
unlink($test_file);
TestUtils::test_page( 'url' => '/thruk/cgi-bin/tac.cgi', unlike => ["time:$now"] );

#############################
# dismiss
Thruk::Utils::IO::write($test_file, $test_broadcast);
TestUtils::test_page( 'url' => '/thruk/cgi-bin/tac.cgi', like => ["time:$now"] );
TestUtils::test_page( 'url' => '/thruk/cgi-bin/broadcast.cgi?action=dismiss', like => ["ok"] );
TestUtils::test_page( 'url' => '/thruk/cgi-bin/tac.cgi', unlike => ["time:$now"] );
TestUtils::test_page( 'url' => '/thruk/cgi-bin/broadcast.cgi', like => ["test news:"] );
unlink($test_file);
TestUtils::test_page( 'url' => '/thruk/cgi-bin/broadcast.cgi?action=edit&id=new', like => ["Create Broadcast"] );

#############################
# broken files
$test_broadcast =<<EOT;
{
  "broken json
EOT
Thruk::Utils::IO::write($test_file, $test_broadcast);

{
    local $ENV{'THRUK_TEST_NO_LOG'} = "";
    TestUtils::test_page( 'url' => '/thruk/cgi-bin/tac.cgi', like => ["Tactical Monitoring Overview"] );
    like($ENV{'THRUK_TEST_NO_LOG'}, "/could not read broadcast file/", "log output ok");
}

unlink($test_file);
