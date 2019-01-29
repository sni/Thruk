use strict;
use warnings;
use Test::More;
use Digest::MD5 qw(md5_hex);

plan tests => 270;

BEGIN {
    $ENV{'THRUK_TEST_CONF_NO_LOG'} = 1;
    $ENV{'THRUK_AUTHOR'} = 1;
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###########################################################
TestUtils::set_test_user_token();
my($host,$service)  = TestUtils::get_test_service();
my($c)              = TestUtils::get_c();
my $default_user    = Thruk->config->{'cgi_cfg'}->{'default_user_name'};
my $other_user      = 'test_user';
my $default_user_id = md5_hex($default_user);
my $other_user_id   = md5_hex($other_user);

###########################################################
# cleanup
my $var_path = $c->config->{'var_path'};
unlink(glob($c->config->{'var_path'}.'/obj_retention.test.*'));

###########################################################
# initialize object config
TestUtils::test_page(
    'url'             => '/thruk/cgi-bin/conf.cgi?sub=objects',
    'follow'          => 1,
    'like'            => [ 'Config Tool', 'obj_retention.test.dat' ],
    'fail_message_ok' => 1,
);

###########################################################
# view host but dont' change anything
my $r = TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&type=host&data.name=localhost',
    'like'    => [ $default_user, 'Host:\s+localhost', '127\.0\.0', 'obj_retention.test.'.$default_user_id.'.dat' ],
);
my($id) = $r->{'content'} =~ m/name="data\.id"\s+value="([^"]+)"/;
isnt($id, undef, 'got id for host');
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&apply=yes',
    'like'    => [ $default_user, 'There are no pending changes to commit', 'obj_retention.test.'.$default_user_id.'.dat' ],
);

###########################################################
# change host but dont' save to disk
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&type=host&data.name=localhost',
    'like'    => [ $default_user, 'Host:\s+localhost', '127\.0\.0', 'obj_retention.test.'.$default_user_id.'.dat' ],
);
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi',
    'post'    => {
        'sub'                => 'objects',
        'type'               => 'host',
        'data.id'            => $id,
        'action'             => 'store',
        'obj.host_name'      => 'localhost',
        'obj.alias'          => 'localhost',
        'obj.address'        => '127.0.0.2',
        'obj.use'            => 'host-pnp, generic-host',
        'obj.contact_groups' => 'example',
        'obj.icon_image'     => 'linux40.png',
    },
    'like'    => [ $default_user, 'Host:\s+localhost', '127\.0\.0\.2', 'linux40\.png', 'obj_retention.test.'.$default_user_id.'.dat' ],
    'follow'  => 1,
);
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&apply=yes',
    'like'    => [ $default_user, 'The following files have been changed', 'example.cfg', 'obj_retention.test.'.$default_user_id.'.dat' ],
);

###########################################################
# change user
Thruk->config->{'cgi_cfg'}->{'default_user_name'} = $other_user;
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&type=host&data.name=localhost',
    'like'    => [ $other_user, 'Host:\s+localhost', '127\.0\.0\.1', 'linux40\.png', 'obj_retention.test.'.$other_user_id.'.dat' ],
);
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi',
    'post'    => {
        'sub'                => 'objects',
        'type'               => 'host',
        'data.id'            => $id,
        'action'             => 'store',
        'obj.host_name'      => 'localhost',
        'obj.alias'          => 'localhost',
        'obj.address'        => '127.0.0.1',
        'obj.use'            => 'host-pnp, generic-host',
        'obj.contact_groups' => 'example',
        'obj.icon_image'     => 'linux.png',
    },
    'like'    => [ $other_user, 'Host:\s+localhost', '127\.0\.0\.1', 'linux\.png', 'obj_retention.test.'.$other_user_id.'.dat' ],
    'follow'  => 1,
);
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&apply=yes',
    'like'    => [ $other_user, 'The following files have been changed', 'example.cfg', 'obj_retention.test.'.$other_user_id.'.dat'],
);

# save
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi',
    'post'    => { 'sub' => 'objects', 'apply' => 'commit', 'save' => 1 },
    'follow'  => 1,
    'like'    => [ $other_user, 'Changes saved to disk successfully', 'There are no pending changes', 'obj_retention.test.dat' ],
);
# reload
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi',
    'post'    => { 'sub' => 'objects', 'apply' => 'yes', 'reload' => 'yes' },
    'follow'  => 1,
    'like'    => [ $other_user, 'config reloaded successfully', 'Reloading naemon configuration', 'obj_retention.test.dat' ],
);

###########################################################
# change back user to default
Thruk->config->{'cgi_cfg'}->{'default_user_name'} = $default_user;
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&type=host&data.name=localhost',
    'like'    => [ $default_user, 'Host:\s+localhost', '127\.0\.0\.2', 'linux\.png', 'obj_retention.test.'.$default_user_id.'.dat' ],
);
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&apply=yes',
    'like'    => [ $default_user, 'The following files have been changed', 'example.cfg', 'obj_retention.test.'.$default_user_id.'.dat' ],
);

# save
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi',
    'post'    => { 'sub' => 'objects', 'apply' => 'commit', 'save' => 1 },
    'follow'  => 1,
    'like'    => [ $default_user, 'Changes saved to disk successfully', 'There are no pending changes', 'obj_retention.test.dat' ],
);
# reload
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi',
    'post'    => { 'sub' => 'objects', 'apply' => 'yes', 'reload' => 'yes' },
    'follow'  => 1,
    'like'    => [ $default_user, 'config reloaded successfully', 'Reloading naemon configuration', 'obj_retention.test.dat' ],
);

###########################################################
# revert everything
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi',
    'post'    => {
        'sub'                => 'objects',
        'type'               => 'host',
        'data.id'            => $id,
        'action'             => 'store',
        'obj.host_name'      => 'localhost',
        'obj.alias'          => 'localhost',
        'obj.address'        => '127.0.0.1',
        'obj.use'            => 'host-pnp, generic-host',
        'obj.contact_groups' => 'example',
        'obj.icon_image'     => 'linux40.png',
    },
    'like'    => [ $default_user, 'Host:\s+localhost', '127\.0\.0\.1', 'linux40\.png', 'obj_retention.test.'.$default_user_id.'.dat' ],
    'follow'  => 1,
);
# save
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi',
    'post'    => { 'sub' => 'objects', 'apply' => 'commit', 'save' => 1 },
    'follow'  => 1,
    'like'    => [ $default_user, 'Changes saved to disk successfully', 'There are no pending changes', 'obj_retention.test.dat' ],
);
# reload
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi',
    'post'    => { 'sub' => 'objects', 'apply' => 'yes', 'reload' => 'yes' },
    'follow'  => 1,
    'like'    => [ $default_user, 'config reloaded successfully', 'Reloading naemon configuration', 'obj_retention.test.dat' ],
);
