use strict;
use warnings;
use Test::More tests => 81;
use File::Temp qw/ tempfile /;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}


###########################################################
# test modules
use_ok 'Thruk::Controller::conf';
use_ok 'Thruk::Utils::Conf::Defaults';
use_ok 'Thruk::Utils::Conf';
use_ok 'Catalyst::Test', 'Thruk';

###########################################################
# get a context object
my($res, $c) = ctx_request('/thruk/main.html');

###########################################################
# test some functions
my $conf_in = "# blah comment
# blah comment 2

test = 1
# more comments
blub = 2
foo = 2


";
my $conf_exp = "# blah comment
# blah comment 2

test=10,1,5
# more comments
blub=5
foo = 2


";
my $data = { test => ["10","1","5"], blub => "5" };
my $got  = Thruk::Utils::Conf::merge_conf($conf_in, $data);
is($got, $conf_exp, "merge config");

###########################################################
# test some functions
$conf_in = "
test = 1
test = 2
test = 3
";
$conf_exp = "
test=1,4,5
blub=5
";
$data = { test => ["1","4","5"], blub => "5" };
$got  = Thruk::Utils::Conf::merge_conf($conf_in, $data);
is($got, $conf_exp, "merge config II");

###########################################################
# test reading htpasswd
my $expected = { "testuser" => "zTOzpj/AEVckE" };
my($fh, $filename) = tempfile();
print $fh <<EOF;
# test htpasswd
testuser:zTOzpj/AEVckE
EOF
close($fh);
my $htpasswd = Thruk::Utils::Conf::read_htpasswd($filename);
is_deeply($htpasswd, $expected, 'reading htpasswd: '.$filename);
unlink($filename);

###########################################################
# test reading thruk.conf
my $thruk_conf_defaults    = Thruk::Utils::Conf::Defaults->get_thruk_cfg($c);
is(ref $thruk_conf_defaults, 'HASH', 'get thruk conf defaults');
is_deeply($thruk_conf_defaults->{'use_pager'},   ['BOOL', '1'],  'sample entry in thruk.conf I');
is_deeply($thruk_conf_defaults->{'plugin_path'}, ['STRING', ''], 'sample entry in thruk.conf II');

###########################################################
($fh, $filename) = tempfile();
print $fh <<EOF;
# default states for commands option checkboxes
<cmd_defaults>
    ahas                   = 0  # For Hosts Too
    broadcast_notification = 0  # Broadcast
    force_check            = 1  # Forced Check
    force_notification     = 0  # Forced Notification
    send_notification      = 1  # Send Notification
    sticky_ack             = 1  # Sticky Acknowledgement
    persistent_comments    = 1  # Persistent Comments
    persistent_ack         = 0  # Persistent Acknowledgement Comments
    ptc                    = 0  # For Child Hosts Too
</cmd_defaults>

######################################
# use paged data instead of all data in one huge page
use_pager           = 1
default_page_size   = 10 # should be one of the paging steps below
paging_steps        = 10
paging_steps        = 500
paging_steps        = 1000
paging_steps        = 5000
paging_steps        = all

######################################
# Backend Configuration, enter your backends here
<Component Thruk::Backend>
    <peer>
        name   = TestBackend1
        type   = livestatus
        hidden = 1
        <options>
            peer   = /tmp/sock1
       </options>
    </peer>
    <peer>
        name   = TestBackend2
        type   = livestatus
        hidden = 0
        <options>
            peer   = 127.0.1.1:9999
       </options>
    </peer>
</Component>
EOF
close($fh);
my($content, $thruk, $md5) = Thruk::Utils::Conf::read_conf($filename, $thruk_conf_defaults);
use Data::Dumper;
print Dumper($thruk);
$expected = [ 'CATEGORY', {
                'send_notification'      => [ 'BOOL', '1' ],
                'persistent_comments'    => [ 'BOOL', '1' ],
                'sticky_ack'             => [ 'BOOL', '1' ],
                'force_check'            => [ 'BOOL', '1' ],
                'broadcast_notification' => [ 'BOOL', '0' ],
                'ptc'                    => [ 'BOOL', '0' ],
                'persistent_ack'         => [ 'BOOL', '0' ],
                'ahas'                   => [ 'BOOL', '0' ],
                'force_notification'     => [ 'BOOL', '0' ]
            }];
pop @{$thruk->{'cmd_defaults'}};
is_deeply($thruk->{'cmd_defaults'}, $expected, 'reading thruk.conf: '.$filename);
unlink($filename);
#exit;

###########################################################
# test some pages
my $pages = [
    '/conf',
    '/thruk/cgi-bin/conf.cgi',
    '/thruk/cgi-bin/conf.cgi?type=cgi',
    '/thruk/cgi-bin/conf.cgi?type=thruk',
    '/thruk/cgi-bin/conf.cgi?type=users',
    '/thruk/cgi-bin/conf.cgi?type=users&action=change&data.username=testuser',
];
for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Config Tool',
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}

my $redirects = [
    '/thruk/cgi-bin/conf.cgi?type=cgi&action=store',
    '/thruk/cgi-bin/conf.cgi?type=thruk&action=store',
    '/thruk/cgi-bin/conf.cgi?type=users&action=store&data.username=testuser',
];
for my $url (@{$redirects}) {
    TestUtils::test_page(
        'url'      => $url,
        'redirect' => 1,
    );
}
