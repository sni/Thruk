use strict;
use warnings;
use Test::More;
use JSON::XS;
use Thruk::Config;
use Data::Dumper;
use Encode qw(encode_utf8 decode_utf8);

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    my $tests = 1318;
    $tests    = $tests - 12 if $ENV{'THRUK_TEST_NO_RELOADS'};
    plan tests => $tests;
}

BEGIN {
    $ENV{'THRUK_TEST_CONF_NO_LOG'} = 1;
    use lib('t');
    require TestUtils;
    import TestUtils;
}


###########################################################
# test modules
if(defined $ENV{'CATALYST_SERVER'}) {
    unshift @INC, 'plugins/plugins-available/conf/lib';
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

    use_ok 'Thruk::Controller::conf';
};
use_ok 'Monitoring::Config::Object';

###########################################################
TestUtils::set_test_user_token();
my($host,$service) = TestUtils::get_test_service();

###########################################################
# initialize object config
TestUtils::test_page(
    'url'             => '/thruk/cgi-bin/conf.cgi?sub=objects',
    'follow'          => 1,
    'like'            => 'Config Tool',
    'fail_message_ok' => 1,
);

###########################################################
# test connection check
my $config = Thruk::Config::get_config();
my $firstbackend;
if(ref $config->{'Thruk::Backend'}->{'peer'} eq 'HASH') { $config->{'Thruk::Backend'}->{'peer'} = [$config->{'Thruk::Backend'}->{'peer'}]; }
for my $p (@{$config->{'Thruk::Backend'}->{'peer'}}) {
    if(!$p->{'hidden'} and lc($p->{'type'}) ne 'configonly') { $firstbackend = $p; last }
}
my $options = $firstbackend->{'options'};
$options->{'action'} = 'check_con';
$options->{'sub'}    = 'backends';
$options->{'type'}   = $firstbackend->{'type'};
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi',
    'post'    => $options,
    'like'    => '"ok" : 1',
);

###########################################################
# test some pages
my $pages = [
    '/thruk/cgi-bin/conf.cgi',
    '/thruk/cgi-bin/conf.cgi?sub=cgi',
    '/thruk/cgi-bin/conf.cgi?sub=thruk',
    '/thruk/cgi-bin/conf.cgi?sub=users',
    '/thruk/cgi-bin/conf.cgi?sub=plugins',
    '/thruk/cgi-bin/conf.cgi?sub=users&action=change&data.username=testuser',
    { url => '/thruk/cgi-bin/conf.cgi?sub=objects', fail_message_ok => 1 },
    '/thruk/cgi-bin/conf.cgi?edit&host='.$host,
    '/thruk/cgi-bin/conf.cgi?edit&host='.$host.'&service='.$service,
    '/thruk/cgi-bin/conf.cgi?sub=objects&apply=yes',
    { url => '/thruk/cgi-bin/conf.cgi', post => { 'sub' => 'objects', 'apply' => 'yes', 'check' => 'yes' }},
    '/thruk/cgi-bin/conf.cgi?sub=objects&apply=yes&diff=yes',
    { url => '/thruk/cgi-bin/conf.cgi', post => { 'sub' => 'objects', 'apply' => 'yes', 'reload' => 'yes' }},
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=browser',
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=move&type=host&data.name='.$host,
    { url => '/thruk/cgi-bin/conf.cgi', post => { 'sub' => 'objects', 'action' => 'clone', 'type' => 'host', 'data.name' => $host }},
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=listservices&data.name='.$host,
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=listref&data.name='.$host,
    '/thruk/cgi-bin/conf.cgi?sub=objects&tools=start',
    '/thruk/cgi-bin/conf.cgi?sub=objects&tools=check_object_references',
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=tree',
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=tree_objects&type=command',
    '/thruk/cgi-bin/conf.cgi?sub=backends',
    { url => '/thruk/cgi-bin/conf.cgi', post => { 'sub' => 'thruk', 'action' => 'store'}, 'startup_to_url' => '/thruk/cgi-bin/conf.cgi?sub=thruk', 'follow' => 1 },
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=history',
];

for my $type (@{$Monitoring::Config::Object::Types}) {
    push @{$pages}, '/thruk/cgi-bin/conf.cgi?sub=objects&type='.$type;
    my $img = "plugins/plugins-available/conf/root/images/obj_".$type.".png";
    ok(-f $img, "object image $img exists");
}

for my $url (@{$pages}) {
    my $test = TestUtils::make_test_hash($url, {'like' => 'Config Tool'});
    # reloading breaks running multiple tests against same core
    if($test->{'url'} =~ m/reload=yes/mx and $ENV{'THRUK_TEST_NO_RELOADS'}) {
        # silently skip this test
    } else {
        TestUtils::test_page(%{$test});
    }
}

my $redirects = [
    { url => '/thruk/cgi-bin/conf.cgi', post => { 'sub' => 'cgi', 'action' => 'store' }, redirect => 1 },
    { url => '/thruk/cgi-bin/conf.cgi', post => { 'sub' => 'users', 'action' => 'store', 'data.username' => 'testuser' }, redirect => 1 },
    { url => '/thruk/cgi-bin/conf.cgi', post => { 'sub' => 'objects', 'action' => 'revert', 'type' => 'host', 'data.name' => $host }, redirect => 1 },
];
for my $page (@{$redirects}) {
    TestUtils::test_page(%{$page});
}

# json export
for my $type (@{$Monitoring::Config::Object::Types}) {
    my $page = TestUtils::test_page(
        'url'          => '/thruk/cgi-bin/conf.cgi?action=json&type='.$type,
        'content_type' => 'application/json; charset=utf-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'ARRAY', "json result is an array") or diag("got: ".Dumper($data));
    next if $type eq 'module';
    next if $type eq 'escalation';
    next if $type eq 'discoveryrule';
    next if $type eq 'discoveryrun';
    next if $type eq 'notificationway';
    next if $type eq 'realm';
    ok(scalar @{$data} == 2, "json result size is: ".(scalar @{$data}));

    is($data->[0]->{'name'}, $type."s", "json result has correct type");
    my $min = 1;
    if($type eq 'hostextinfo' or $type eq 'hostextinfo' or $type eq 'hostdependency' or $type eq 'hostescalation' or $type eq 'serviceextinfo' or $type eq 'servicedependency' or $type eq 'serviceescalation') {
        $min = 0;
    }
    ok(scalar @{$data->[0]->{'data'}} >= $min, "json result for ".$type." has data ( >= $min )");

    $data->[0]->{'data'}->[0] = "none" unless defined $data->[0]->{'data'}->[0];
    $data->[0]->{'data'}->[0] = encode_utf8($data->[0]->{'data'}->[0]);
    my $testname = $data->[0]->{'data'}->[0];

    TestUtils::test_page(
        'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&type='.$type.'&data.name='.$data->[0]->{'data'}->[0],
        'like'    => [ 'Config Tool', $type, "\Q$testname\E"],
    );

    # new object
    TestUtils::test_page(
        'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&action=new&type='.$type,
        'like'    => [ 'Config Tool', "new $type"],
    );
}

# other json pages
my $plugin = "";
my $other_json = [
    { url => '/thruk/cgi-bin/conf.cgi', post => { 'action' => 'json', 'type' => 'dig', 'host' => 'localhost'}, like => '"address" :', jtype => 'HASH' },
    { url => '/thruk/cgi-bin/conf.cgi?action=json&type=icon',           like => '"icons"' },
    { url => '/thruk/cgi-bin/conf.cgi?action=json&type=plugin',         like => '"plugins"' },
    { url => '/thruk/cgi-bin/conf.cgi?action=json&type=macro',          like => [ '"macros"', 'HOSTADDRESS'] },
    { url => '/thruk/cgi-bin/conf.cgi', post => { 'action' => 'json', 'type' => 'pluginhelp', 'plugin' => '##PLUGIN##'}, like => '"plugin_help" :' },
    { url => '/thruk/cgi-bin/conf.cgi', post => { 'action' => 'json', 'type' => 'pluginpreview' }, like => '"plugin_output" :' },
    { url => '/thruk/cgi-bin/conf.cgi?action=json&type=servicemembers', like => '"servicemembers"' },
];
for my $url (@{$other_json}) {
    $url->{'post'}->{'plugin'} =~ s/\#\#PLUGIN\#\#/$plugin/gmx if($url->{'post'} and $url->{'post'}->{'plugin'});
    my $test = TestUtils::make_test_hash($url, {'content_type' => 'application/json; charset=utf-8'});
    my $page = TestUtils::test_page(%{$test});
    my $data = decode_json($page->{'content'});
    $url->{'jtype'} = 'ARRAY' unless defined $url->{'jtype'};
    is(ref $data, $url->{'jtype'}, "json result ref is ".$url->{'jtype'}) or diag("got: ".Dumper($data));
    if($url->{'jtype'} eq 'ARRAY') {
        ok(scalar @{$data} == 1, "json result size is: ".(scalar @{$data}));
    }

    if(ref $data eq 'ARRAY'
       and defined $data->[0]->{'name'}
       and $data->[0]->{'name'} eq 'plugins'
       and defined $data->[0]->{'data'}->[0]
    ) {
        $plugin = $data->[0]->{'data'}->[0];
    }
}


# create new host
my $r = TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi',
    'post'    => { 'sub' => 'objects', 'type' => 'host', 'data.id' => 'new', 'action' => 'store', 'data.file', => '%2Ftest.cfg', 'obj.host_name' => 'test', 'obj.alias' => 'test', 'obj.address' => 'test', 'obj.use' => 'generic-host', 'conf_comment' => '' },
    'like'    => [ 'Host:\s+test'],
    'follow'  => 1,
);
my($id) = $r->{'content'} =~ m/name="data\.id"\s+value="([^"]+)"/;
isnt($id, undef, 'got id for host');
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&apply=yes',
    'like'    => [ 'The following files have been changed', 'test.cfg'],
);
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi',
    'post'    => { 'sub' => 'objects', 'data.id' => $id, 'action' => 'movefile', 'newfile' => 'test2.cfg', 'move' => 'move' },
    'like'    => [ 'test2.cfg'],
    'follow'  => 1,
);
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi',
    'post'    => { 'sub' => 'objects', 'apply' => 'commit', 'discard' => 'discard all unsaved changes' },
    'like'    => [ 'There are no pending changes to commit'],
    'follow'  => 1,
);
