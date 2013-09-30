use strict;
use warnings;
use Test::More;
use File::Copy qw/copy/;

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'CATALYST_SERVER'};
    plan tests => 160;
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
copy('t/xt/business_process/data/'.$bpid.'.tbp', './bp/'.$bpid.'.tbp');
ok(-f './bp/'.$bpid.'.tbp', 'business process exists');

###########################################################
# test some pages
my $pages = [
    '/thruk/cgi-bin/bp.cgi',
    '/thruk/cgi-bin/bp.cgi?action=details&bp='.$bpid,
    '/thruk/cgi-bin/bp.cgi?action=details&bp='.$bpid.'&minimal=1',
    '/thruk/cgi-bin/bp.cgi?action=details&bp='.$bpid.'&edit=1',
    { url => '/thruk/cgi-bin/bp.cgi?action=refresh&bp='.$bpid, like => 'Test App', skip_doctype => 1 },
    { url => '/thruk/cgi-bin/bp.cgi?action=rename_node&bp='.$bpid.'&node=node1&label=Test App Renamed', skip_doctype => 1, like => 'OK' },
    { url => '/thruk/cgi-bin/bp.cgi?action=remove_node&bp='.$bpid.'&node=node3', skip_doctype => 1, like => 'OK' },
    { url => '/thruk/cgi-bin/bp.cgi?action=edit_node&bp='.$bpid.'&bp_node_id=new&node=node1&bp_arg1=Critical&function=Fixed&bp_label=addednode', skip_doctype => 1, like => 'OK' },
    { url => '/thruk/cgi-bin/bp.cgi?action=refresh&edit=1&bp='.$bpid, like => 'Worst state is CRITICAL: addednode', skip_doctype => 1 },
    { url => '/thruk/cgi-bin/bp.cgi?action=edit_node&bp='.$bpid.'&node=node2&bp_arg1=Warning&bp_arg2=newnodetest&function=Fixed&bp_label=newnode&bp_node_id=new', skip_doctype => 1, like => 'OK' },
    { url => '/thruk/cgi-bin/bp.cgi?action=refresh&edit=1&bp='.$bpid, like => 'newnodetest', skip_doctype => 1 },
    { url => '/thruk/cgi-bin/bp.cgi?action=clone&bp='.$bpid, follow => 1, like => 'Clone of Test App' },
    { url => '/thruk/cgi-bin/bp.cgi?action=remove&bp='.$bpid, follow => 1 },
    { url => '/thruk/cgi-bin/bp.cgi?action=new&bp_label=New Test Business Process', follow => 1, like => 'New Test Business Process' },
];

for my $url (@{$pages}) {
    my $test = TestUtils::make_test_hash($url, {'like' => 'Business Process'});
    TestUtils::test_page(%{$test});
}

ok(!-f './bp/'.$bpid.'.tbp', 'business process removed');

###########################################################
# cleanup
use_ok('Thruk::BP::Utils');
Thruk::BP::Utils::clean_orphaned_edit_files($c, 0);
