use strict;
use warnings;
use Test::More tests => 1025;
use JSON::XS;
use Encode qw(encode_utf8 decode_utf8);

BEGIN {
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
];

for my $type (@{$Monitoring::Config::Object::Types}) {
    push @{$pages}, '/thruk/cgi-bin/conf.cgi?sub=objects&type='.$type,
}

for my $url (@{$pages}) {
    my $test = TestUtils::make_test_hash($url, {'like' => 'Config Tool'});
    TestUtils::test_page(%{$test});
}

my $redirects = [
    '/thruk/cgi-bin/conf.cgi?sub=cgi&action=store',
    '/thruk/cgi-bin/conf.cgi?sub=thruk&action=store',
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
for my $type (@{$Monitoring::Config::Object::Types}, 'icon') {
    my $page = TestUtils::test_page(
        'url'          => '/thruk/cgi-bin/conf.cgi?action=json&type='.$type,
        'content_type' => 'application/json; charset=utf-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'ARRAY', "json result is an array") or diag("got: ".Dumper($data));
    next if $type eq 'module';
    if($type eq 'icon') {
        ok(scalar @{$data} == 1, "json result size is: ".(scalar @{$data}));
    } else {
        ok(scalar @{$data} == 2, "json result size is: ".(scalar @{$data}));
    }

    is($data->[0]->{'name'}, $type."s", "json result has correct type");
    my $min = 1;
    if($type eq 'hostextinfo' or $type eq 'hostextinfo' or $type eq 'hostdependency' or $type eq 'hostescalation' or $type eq 'serviceextinfo' or $type eq 'servicedependency' or $type eq 'serviceescalation') {
        $min = 0;
    }
    ok(scalar @{$data->[0]->{'data'}} >= $min, "json result for ".$type." has data ( >= $min )");

    next if $type eq 'icon';

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
