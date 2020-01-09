use strict;
use warnings;
use Test::More;
use Cpanel::JSON::XS qw/decode_json/;
use Thruk::Config;
use Data::Dumper;
use Encode qw(encode_utf8 decode_utf8);
use File::Temp qw/tempfile/;
use Thruk::Utils::IO;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    my $tests = 1383;
    $tests    = $tests - 11 if $ENV{'THRUK_TEST_NO_RELOADS'};
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
if(defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'}) {
    unshift @INC, 'plugins/plugins-available/conf/lib';
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

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

SKIP: {
    skip 'external tests', 52 if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

    my $c = TestUtils::get_c();
    delete $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'};
    my $page = TestUtils::test_page(
        'url'               => '/thruk/cgi-bin/conf.cgi?action=user_password&referer=/thruk/cgi-bin/tac.cgi',
        'like'              => ['Changing passwords is disabled', 'Tactical Monitoring Overview'],
        'follow'            => 1,
        'fail_message_ok'   => 1,
    );

    my($fh, $tmp_htpasswd) = tempfile();
    $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'} = $tmp_htpasswd;

    $page = TestUtils::test_page(
        'url'               => '/thruk/cgi-bin/conf.cgi?action=user_password&referer=/thruk/cgi-bin/tac.cgi',
        'like'              => ['Your password cannot be changed', 'Tactical Monitoring Overview'],
        'follow'            => 1,
        'fail_message_ok'   => 1,
    );

    # add user with password test
    my $user = TestUtils::get_test_user();
    Thruk::Utils::IO::write($tmp_htpasswd, $user.":wizDR5wi.JkYc\n");

    $page = TestUtils::test_page(
        'url'               => '/thruk/cgi-bin/conf.cgi?action=user_password&referer=/thruk/cgi-bin/tac.cgi',
        'like'              => ['User: '.$user, 'Change Password'],
    );

    # change password
    $page = TestUtils::test_page(
        'url'               => '/thruk/cgi-bin/conf.cgi',
        'like'              => ['Password changed successfully'],
        'post'              => {
            'action'         => 'user_password',
            'save'           => 'Update',
            'data.old'       => 'test',
            'data.password'  => 'test.new',
            'data.password2' => 'test.new',
        },
        follow              => 1,
    );

    unlink($tmp_htpasswd);
};

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
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=listservices&type=host&data.name='.$host,
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=listref&type=host&data.name='.$host,
    '/thruk/cgi-bin/conf.cgi?sub=objects&tools=start',
    '/thruk/cgi-bin/conf.cgi?sub=objects&tools=DuplicateTemplateAttributes',
    '/thruk/cgi-bin/conf.cgi?sub=objects&tools=ObjectReferences',
    '/thruk/cgi-bin/conf.cgi?sub=objects&tools=UnusedObjects',
    '/thruk/cgi-bin/conf.cgi?sub=objects&tools=SuggestPossibleTemplates',
    '/thruk/cgi-bin/conf.cgi?sub=objects&tools=PerformanceDataTemplates',
    '/thruk/cgi-bin/conf.cgi?sub=objects&tools=Naglint',
    { url => '/thruk/cgi-bin/conf.cgi?sub=objects&tools=reset_ignores&oldtool=ObjectReferences', follow => 1 },
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=tree',
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=tree_objects&type=command',
    '/thruk/cgi-bin/conf.cgi?sub=backends',
    { url => '/thruk/cgi-bin/conf.cgi', post => { 'sub' => 'thruk', 'action' => 'store'}, 'startup_to_url' => '/thruk/cgi-bin/conf.cgi?sub=thruk', 'follow' => 1 },
    { url => '/thruk/cgi-bin/conf.cgi?sub=objects&action=history', unlike => [ 'ARRAY', 'HASH' ] },
    {url => '/thruk/cgi-bin/conf.cgi?sub=plugins&action=preview&pic=minemap', like => 'PNG', 'content_type' => 'image/png'},
];

for my $type (@{$Monitoring::Config::Object::Types}) {
    push @{$pages}, '/thruk/cgi-bin/conf.cgi?sub=objects&type='.$type;
    my $img = "plugins/plugins-available/conf/root/images/obj_".$type.".png";
    ok(-f $img, "object image $img exists");
}

for my $url (@{$pages}) {
    my $test = TestUtils::make_test_hash($url, {'like' => 'Config Tool'});
    # reloading breaks running multiple tests against same core
    if($test->{'post'} and $test->{'post'}->{'reload'} and $ENV{'THRUK_TEST_NO_RELOADS'}) {
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
        'content_type' => 'application/json;charset=UTF-8',
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
        'url'             => '/thruk/cgi-bin/conf.cgi?sub=objects&type='.$type.'&data.name='.$data->[0]->{'data'}->[0],
        'like'            => [ 'Config Tool', $type, "\Q$testname\E"],
        'fail_message_ok' => $data->[0]->{'data'}->[0] eq 'none' ? 1 : undef,
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
    { url => '/thruk/cgi-bin/conf.cgi?action=json&long=1&type=host&filter='.$host,       like => '"hosts"', jsize => '>=' },
    { url => '/thruk/cgi-bin/conf.cgi?action=json&long=1&type=service&filter='.$service, like => '"hosts"', jsize => '>=' },
];
for my $url (@{$other_json}) {
    $url->{'post'}->{'plugin'} =~ s/\#\#PLUGIN\#\#/$plugin/gmx if($url->{'post'} and $url->{'post'}->{'plugin'});
    my $test = TestUtils::make_test_hash($url, {'content_type' => 'application/json;charset=UTF-8'});
    my $page = TestUtils::test_page(%{$test});
    my $data = decode_json($page->{'content'});
    $url->{'jtype'} = 'ARRAY' unless defined $url->{'jtype'};
    is(ref $data, $url->{'jtype'}, "json result ref is ".$url->{'jtype'}) or diag("got: ".Dumper($data));
    if($url->{'jtype'} eq 'ARRAY') {
        if($url->{'jsize'} && $url->{'jsize'} eq '>=') {
            ok(scalar @{$data} >= 1, "json result size is: ".(scalar @{$data}));
        } else {
            ok(scalar @{$data} == 1, "json result size is: ".(scalar @{$data}));
        }
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
my $testhost = "test-host-".rand();
my $r = TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi',
    'post'    => { 'sub' => 'objects', 'type' => 'host', 'data.id' => 'new', 'action' => 'store', 'data.file', => '/test.cfg', 'obj.host_name' => $testhost, 'obj.alias' => 'test', 'obj.address' => 'test', 'obj.use' => 'generic-host', 'conf_comment' => '' },
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
