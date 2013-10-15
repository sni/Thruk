use strict;
use warnings;
use Test::More;
use JSON::XS;
use Thruk::Config;
use Data::Dumper;
use Encode qw(encode_utf8 decode_utf8);

BEGIN {
    my $tests = 1232;
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan tests => $tests     if !defined $ENV{'CATALYST_SERVER'};
    plan tests => ($tests+1) if  defined $ENV{'CATALYST_SERVER'};
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
my $options = "";
for my $opt (keys %{$firstbackend->{'options'}}) {
    $options .= '&'.$opt.'='.$firstbackend->{'options'}->{$opt};
}
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi?action=check_con&sub=backends&type='.$firstbackend->{'type'}.$options,
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
    '/thruk/cgi-bin/conf.cgi?sub=objects&apply=yes&check=yes',
    '/thruk/cgi-bin/conf.cgi?sub=objects&apply=yes&diff=yes',
    '/thruk/cgi-bin/conf.cgi?sub=objects&apply=yes&reload=yes',
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=browser',
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=move&type=host&data.name='.$host,
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=clone&type=host&data.name='.$host,
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=listservices&data.name='.$host,
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=listref&data.name='.$host,
    '/thruk/cgi-bin/conf.cgi?sub=objects&tools=start',
    '/thruk/cgi-bin/conf.cgi?sub=objects&tools=check_object_references',
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=tree',
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=tree_objects&type=command',
    '/thruk/cgi-bin/conf.cgi?sub=backends',
    { url => '/thruk/cgi-bin/conf.cgi?sub=thruk&action=store', 'startup_to_url' => '/thruk/cgi-bin/conf.cgi?sub=thruk', 'follow' => 1 },
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=history',
];

for my $type (@{$Monitoring::Config::Object::Types}) {
    push @{$pages}, '/thruk/cgi-bin/conf.cgi?sub=objects&type='.$type;
    my $img = "plugins/plugins-available/conf/root/images/obj_".$type.".png";
    ok(-f $img, "object image $img exists");
}

for my $url (@{$pages}) {
    my $test = TestUtils::make_test_hash($url, {'like' => 'Config Tool'});
    TestUtils::test_page(%{$test});
}

my $redirects = [
    '/thruk/cgi-bin/conf.cgi?sub=cgi&action=store',
    '/thruk/cgi-bin/conf.cgi?sub=users&action=store&data.username=testuser',
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=revert&type=host&data.name='.$host,
];
for my $url (@{$redirects}) {
    TestUtils::test_page(
        'url'      => $url,
        'redirect' => 1,
    );
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
    ok(scalar @{$data} == 2, "json result size is: ".(scalar @{$data}));

    is($data->[0]->{'name'}, $type."s", "json result has correct type");
    my $min = 1;
    if($type eq 'hostextinfo' or $type eq 'hostextinfo' or $type eq 'hostdependency' or $type eq 'hostescalation' or $type eq 'serviceextinfo' or $type eq 'servicedependency' or $type eq 'serviceescalation') {
        $min = 0;
    }
    ok(scalar @{$data->[0]->{'data'}} >= $min, "json result for ".$type." has data ( >= $min )");

    $data->[0]->{'data'}->[0] = "none" unless defined $data->[0]->{'data'}->[0];
    $data->[0]->{'data'}->[0] = encode_utf8($data->[0]->{'data'}->[0]);

    TestUtils::test_page(
        'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&type='.$type.'&data.name='.$data->[0]->{'data'}->[0],
        'like'    => [ 'Config Tool', $type, $data->[0]->{'data'}->[0]],
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
    { url => '/thruk/cgi-bin/conf.cgi?action=json&type=dig&host=localhost',           like => '"address" :', jtype => 'HASH' },
    { url => '/thruk/cgi-bin/conf.cgi?action=json&type=icon',                         like => '"icons"' },
    { url => '/thruk/cgi-bin/conf.cgi?action=json&type=plugin',                       like => '"plugins"' },
    { url => '/thruk/cgi-bin/conf.cgi?action=json&type=macro',                        like => [ '"macros"', 'HOSTADDRESS'] },
    { url => '/thruk/cgi-bin/conf.cgi?action=json&type=pluginhelp&plugin=##PLUGIN##', like => '"plugin_help" :' },
    { url => '/thruk/cgi-bin/conf.cgi?action=json&type=pluginpreview',                like => '"plugin_output" :' },
    { url => '/thruk/cgi-bin/conf.cgi?action=json&type=servicemembers',               like => '"servicemembers",' },
];
for my $url (@{$other_json}) {
    $url->{'url'} =~ s/\#\#PLUGIN\#\#/$plugin/gmx;
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
    'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&type=host&data.id=new&action=store&data.file=%2Ftest.cfg&obj.host_name=test&obj.alias=test&obj.address=test&obj.use=generic-host&conf_comment=',
    'like'    => [ 'Host:\s+test'],
    'follow'  => 1,
);
my($id) = $r->{'content'} =~ m/data\.id=([^']*)'>Clone\ this\ host/;
isnt($id, undef, 'got id for host: '.$id);
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&apply=yes',
    'like'    => [ 'The following files have been changed', 'test.cfg'],
);
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&data.id='.$id.'&action=movefile&newfile=test2.cfg&move=move',
    'like'    => [ 'test2.cfg'],
    'follow'  => 1,
);
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&apply=commit&discard=discard+all+unsaved+changes',
    'like'    => [ 'There are no pending changes to commit'],
    'follow'  => 1,
);
