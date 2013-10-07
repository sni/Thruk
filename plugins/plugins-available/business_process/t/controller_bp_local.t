use strict;
use warnings;
use Test::More;
use File::Copy qw/copy/;
use JSON::XS;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan skip_all => 'internal test only' if defined $ENV{'CATALYST_SERVER'};
    plan tests => 214;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $bpid = 9999;
my $c    = TestUtils::get_c();

###########################################################
# copy sample bp
my $created_dir = 0;
if(!-d 'bp') {
    mkdir('bp') or die("cannot create bp: ".$!);
    $created_dir = 1;
}
copy('t/xt/business_process/data/'.$bpid.'.tbp', './bp/'.$bpid.'.tbp') or die("copy failed: ".$!);
ok(-f './bp/'.$bpid.'.tbp', 'business process exists');

###########################################################
# test some pages
my $pages = [
    '/thruk/cgi-bin/bp.cgi',
    '/thruk/cgi-bin/bp.cgi?action=details&bp='.$bpid,
    '/thruk/cgi-bin/bp.cgi?action=details&bp='.$bpid.'&minimal=1',
    '/thruk/cgi-bin/bp.cgi?action=details&bp='.$bpid.'&edit=1',
    '/thruk/cgi-bin/bp.cgi?action=details&bp='.$bpid.'&testmode=1',
    '/thruk/cgi-bin/bp.cgi?action=details&bp='.$bpid.'&debug=1',
    { url => '/thruk/cgi-bin/bp.cgi?action=refresh&bp='.$bpid, like => 'Test App', skip_doctype => 1 },
    { url => '/thruk/cgi-bin/bp.cgi?action=rename_node&bp='.$bpid.'&node=node1&label=Test App Renamed', skip_doctype => 1, like => 'OK' },
    { url => '/thruk/cgi-bin/bp.cgi?action=remove_node&bp='.$bpid.'&node=node3', skip_doctype => 1, like => 'OK' },
    { url => '/thruk/cgi-bin/bp.cgi?action=edit_node&bp='.$bpid.'&bp_node_id=new&node=node1&bp_arg1_fixed=Critical&bp_function=Fixed&bp_label_fixed=addednode', skip_doctype => 1, like => 'OK' },
    { url => '/thruk/cgi-bin/bp.cgi?action=refresh&edit=1&bp='.$bpid, like => 'Worst state is CRITICAL: addednode', skip_doctype => 1 },
    { url => '/thruk/cgi-bin/bp.cgi?action=edit_node&bp='.$bpid.'&node=node2&bp_arg1_fixed=Warning&bp_arg2_fixed=newnodetest&bp_function=Fixed&bp_label_fixed=newnode&bp_node_id=new', skip_doctype => 1, like => 'OK' },
    { url => '/thruk/cgi-bin/bp.cgi?action=refresh&edit=1&bp='.$bpid, like => 'newnodetest', skip_doctype => 1 },
    { url => '/thruk/cgi-bin/bp.cgi?action=clone&bp='.$bpid, follow => 1, like => 'Clone of Test App' },
    { url => '/thruk/cgi-bin/bp.cgi?action=remove&bp='.$bpid, follow => 1 },
    { url => '/thruk/cgi-bin/bp.cgi?action=new&bp_label=New Test Business Process', follow => 1, like => 'New Test Business Process' },
    { url => '/thruk/cgi-bin/bp.cgi?bp=9999', like => ['Business Process', 'no such business process' ], fail => 1, fail_message_ok => 1 },
];

for my $url (@{$pages}) {
    my $test = TestUtils::make_test_hash($url, {'like' => 'Business Process'});
    TestUtils::test_page(%{$test});
}

###########################################################
ok(!-f './bp/'.$bpid.'.tbp', 'business process removed');

###########################################################
# test json some pages
copy('t/xt/business_process/data/'.$bpid.'.tbp', './bp/'.$bpid.'.tbp') or die("copy failed: ".$!);
ok(-f './bp/'.$bpid.'.tbp', 'business process exists');

my $json_pages = [
    '/thruk/cgi-bin/bp.cgi?view_mode=json',
    '/thruk/cgi-bin/bp.cgi?view_mode=json&bp=9999',
];

for my $url (@{$json_pages}) {
    my $page = TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/json; charset=utf-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'HASH', "json result is an hash: ".$url);
}
TestUtils::test_page(url => '/thruk/cgi-bin/bp.cgi?action=remove&bp='.$bpid, follow => 1);

###########################################################
# cleanup
use_ok('Thruk::BP::Utils');
Thruk::BP::Utils::clean_orphaned_edit_files($c, 0);

# if it was empty, remove it again
rmdir('bp') if $created_dir;
