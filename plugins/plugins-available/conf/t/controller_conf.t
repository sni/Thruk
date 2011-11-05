use strict;
use warnings;
use Test::More tests => 700;
use JSON::XS;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}


###########################################################
# test modules
use_ok 'Thruk::Controller::conf';
use_ok 'Monitoring::Config::Object';

###########################################################
my($host,$service) = TestUtils::get_test_service();

###########################################################
# initialize object config
TestUtils::test_page(
    'url'      => '/thruk/cgi-bin/conf.cgi?sub=objects',
    'follow'   => 1,
    'unlike'   => [ 'internal server error', 'HASH', 'ARRAY' ],
    'like'     => 'Config Tool',
);

###########################################################
# test some pages
my $pages = [
    '/conf',
    '/thruk/cgi-bin/conf.cgi',
    '/thruk/cgi-bin/conf.cgi?sub=cgi',
    '/thruk/cgi-bin/conf.cgi?sub=thruk',
    '/thruk/cgi-bin/conf.cgi?sub=users',
    '/thruk/cgi-bin/conf.cgi?sub=users&action=change&data.username=testuser',
    '/thruk/cgi-bin/conf.cgi?sub=objects',
    '/thruk/cgi-bin/conf.cgi?sub=objects&apply=yes',
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=browser',
    '/thruk/cgi-bin/conf.cgi?sub=objects&action=move&type=host&data.name='.$host,
];

for my $type (@{$Monitoring::Config::Object::Types}) {
    push @{$pages}, '/thruk/cgi-bin/conf.cgi?sub=objects&type='.$type,
}

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Config Tool',
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}

my $redirects = [
    '/thruk/cgi-bin/conf.cgi?sub=cgi&action=store',
    '/thruk/cgi-bin/conf.cgi?sub=thruk&action=store',
    '/thruk/cgi-bin/conf.cgi?sub=users&action=store&data.username=testuser',
];
for my $url (@{$redirects}) {
    TestUtils::test_page(
        'url'      => $url,
        'redirect' => 1,
        'unlike'   => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}

# json export
for my $type (@{$Monitoring::Config::Object::Types}, 'icon') {
    my $page = TestUtils::test_page(
        'url'          => '/thruk/cgi-bin/conf.cgi?action=json&type='.$type,
        'unlike'       => [ 'internal server error', 'HASH', 'ARRAY' ],
        'content_type' => 'application/json; charset=utf-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'ARRAY', "json result is an array") or diag("got: ".Dumper($data));
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

    TestUtils::test_page(
        'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&type='.$type.'data.name='.$data->[0]->{'data'}->[0],
        'like'    => [ 'Config Tool', $type, $data->[0]->{'data'}->[0]],
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );

    # new object
    TestUtils::test_page(
        'url'     => '/thruk/cgi-bin/conf.cgi?sub=objects&action=new&type=service',
        'like'    => [ 'Config Tool', "new $type"],
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}
