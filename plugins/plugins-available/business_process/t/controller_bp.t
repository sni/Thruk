use strict;
use warnings;
use Test::More tests => 89;
use File::Copy qw/copy/;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $bpid = 9999;
copy('t/xt/business_process/data/'.$bpid.'.tbp', 'var/bp/'.$bpid.'.tbp');
ok(-f 'var/bp/'.$bpid.'.tbp', 'business process exists');

###########################################################
# test some pages
my $pages = [
    '/thruk/cgi-bin/bp.cgi',
    '/thruk/cgi-bin/bp.cgi?action=details&bp='.$bpid,
    { url => '/thruk/cgi-bin/bp.cgi?action=refresh&bp='.$bpid, like => 'Test App', skip_doctype => 1 },
    { url => '/thruk/cgi-bin/bp.cgi?action=rename_node&bp='.$bpid.'&node=node1&label=renamed', skip_doctype => 1, like => 'OK' },
    { url => '/thruk/cgi-bin/bp.cgi?action=remove_node&bp='.$bpid.'&node=node3', skip_doctype => 1, like => 'OK' },
    { url => '/thruk/cgi-bin/bp.cgi?action=add_node&bp='.$bpid.'&node=node1&bp_arg1=Critical&function=Fixed&bp_label=addednode', skip_doctype => 1, like => 'OK' },
    { url => '/thruk/cgi-bin/bp.cgi?action=refresh&bp='.$bpid, like => 'Worst state is CRITICAL: addednode', skip_doctype => 1 },
    { url => '/thruk/cgi-bin/bp.cgi?action=remove&bp='.$bpid, follow => 1 },
];

for my $url (@{$pages}) {
    my $test = TestUtils::make_test_hash($url, {'like' => 'Business Process'});
    TestUtils::test_page(%{$test});
}

ok(!-f 'var/bp/'.$bpid.'.tbp', 'business process removed');