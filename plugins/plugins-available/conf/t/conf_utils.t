use strict;
use warnings;
use utf8;
use Test::More;
use Data::Dumper;
use Storable qw/ dclone /;
use File::Slurp;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan tests => 664;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###########################################################
# load modules
if(defined $ENV{'CATALYST_SERVER'}) {
    unshift @INC, 'plugins/plugins-available/conf/lib';
}
use_ok 'Monitoring::Config';
use_ok 'Monitoring::Config::Help';
use_ok 'Monitoring::Config::Object';
use_ok 'Thruk::Utils::Conf::Defaults';
use_ok 'Thruk::Utils::Conf';

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
# _array_diff
my $a1 = [1]; my $a2 = [];
is(Monitoring::Config->_array_diff($a1, $a2), 1, '_list 1');

$a1 = [1]; $a2 = undef;
is(Monitoring::Config->_array_diff($a1, $a2), 1, '_list 2');

$a1 = [1]; $a2 = [1,2];
is(Monitoring::Config->_array_diff($a1, $a2), 1, '_list 3');

$a1 = [1,2]; $a2 = [1,2];
is(Monitoring::Config->_array_diff($a1, $a2), 0, '_list 4');

###########################################################
# test reading htpasswd
my $expected = { "testuser" => "zTOzpj/AEVckE" };
my($fh, $filename) = File::Temp::tempfile();
print $fh <<EOF;
# test htpasswd
testuser:zTOzpj/AEVckE
EOF
close($fh);
my $htpasswd = Thruk::Utils::Conf::read_htpasswd($filename);
is_deeply($htpasswd, $expected, 'reading htpasswd: '.$filename);
unlink($filename);


###########################################################
# check object definitions
for my $type (@{$Monitoring::Config::Object::Types}) {
    use_ok 'Monitoring::Config::Object::'.ucfirst($type);
    my $obj = Monitoring::Config::Object->new(type => $type, coretype => 'any');
    isa_ok( $obj, 'Monitoring::Config::Object::'.ucfirst($type) );
    for my $attr ( keys %{$obj->{'default'}}) {
        my $field = $obj->{'default'}->{$attr};
        next if $field->{'type'} eq 'DEPRECATED';
        if($field->{'type'} eq 'ALIAS') {
            is(defined $obj->{'default'}->{$field->{'name'}}, 1, "$type: $attr alias does exist");
            next;
        }
        my $help;
        if(defined $field->{'help'}) {
            $help = $obj->get_help($field->{'help'});
        } else {
            $help = $obj->get_help($attr);
        }
        unlike( $help, '/topic does not exist/', "$type: $attr has help" );
    }
}


###########################################################
# simple object loaded
my $objects = Monitoring::Config->new({ obj_dir => './t/xt/conf/data/1' });
$objects->init();
isa_ok( $objects, 'Monitoring::Config' );
is( scalar @{ $objects->{'files'} }, 1, 'number of files parsed' ) or BAIL_OUT("useless without parsed files:\n".Dumper($objects));
my $parsedfile = $objects->{'files'}->[0];
is( $parsedfile->{'md5'}, 'bf6f91fcc7c569f4cc96bcdf8e926811', 'files md5 sum' );
like( $parsedfile->{'parse_errors'}->[0], '/unknown object type \'blah\'/', 'parse error' );
my $obj = $parsedfile->{'objects'}->[0];
my $host = {
    '_CUST1'         => 'cust 1 val',
    '_CUST2'         => 'cust 2 val',
    '_CUST3'         => 'cust 3 val multiline',
    'use'            => [ 'generic-host' ],
    'hostgroups'     => [ 'hostgroup1', 'hostgroup2' ],
    'host_name'      => 'hostname1',
    'icon_image'     => 'base/icon.gif',
    'address'        => '127.0.0.1',
    'icon_image_alt' => 'icon alt',
    'alias'          => 'alias1         # one more',
    'contact_groups' => [ 'group1', 'group2' ],
    'parents'        => [ 'parent_host' ],
};
is_deeply($obj->{'conf'}, $host, 'parsed host');
is( scalar @{ $obj->{'comments'} }, 3, 'number of comments' );
my $keys = $obj->get_sorted_keys();
my $exp_keys = [
           'host_name',
           'alias',
           'address',
           'parents',
           'use',
           'contact_groups',
           'hostgroups',
           'icon_image',
           'icon_image_alt',
           '_CUST1',
           '_CUST2',
           '_CUST3',
];

is_deeply($keys, $exp_keys, 'sort keys') or diag("got:\n".Dumper($keys)."\nexpected:\n".Dumper($exp_keys));
###########################################################
# compare that with configs read from text blob
my $cloneconf = dclone($obj->{'conf'});
$parsedfile->update_objects_from_text('');
is(scalar @{$parsedfile->{'objects'}}, 0, 'emptied objects');
my $text      = read_file($parsedfile->{'path'});
$parsedfile->update_objects_from_text($text);
ok(scalar @{$parsedfile->{'objects'}} > 0, 'read objects from text');
$obj          = $parsedfile->{'objects'}->[0];
is_deeply($obj->{'conf'}, $cloneconf, 'parsed host from text');

###########################################################
for my $type (@{$Monitoring::Config::Object::Types}) {
    my $objs = $objects->get_objects_by_type($type);
    is(ref $objs, 'ARRAY', "get objects of type: ".$type);

    is(scalar @{$objs}, 1, "number of objects") if $type eq 'host';
    is(scalar @{$objs}, 0, "number of objects") if $type ne 'host';
}


###########################################################
# check deeply cascaded templates
$objects = Monitoring::Config->new({ obj_dir => './t/xt/conf/data/2' });
$objects->init();
my $tmp = $objects->get_objects_by_name('host', 'host_name');
$obj = $tmp->[0];
isa_ok( $obj, 'Monitoring::Config::Object::Host' );
is( $obj->get_type(), 'host', 'got a type' );
is( $obj->get_name(), 'host_name', 'got a name' );
is( $obj->get_long_name(), 'host_name', 'got a long name' );
is( $obj->get_id(), 'de894', 'got a id' );
my $templates = $obj->get_used_templates($objects);
$expected     = [
          'template1',
          'sub_template1_1',
          'sub_template1_2',
          'sub_template1_2_1',
          'template2',
          'sub_template2_1',
          'sub_template2_2',
];
is_deeply($templates, $expected, 'templates parsing') or diag("expected: ".Dumper($expected)."\nbut got: ".Dumper($templates));



###########################################################
# timeperiod parsing
$objects = Monitoring::Config->new({ obj_dir => './t/xt/conf/data/3' });
$objects->init();
$parsedfile = $objects->{'files'}->[0];
$obj = $parsedfile->{'objects'}->[0];
my $t1 = {
    'timeperiod_name'      => 'misc-single-days',
    'alias'                => 'Misc Single Days',
    '1999-01-28'           => '00:00-24:00',
    'monday 3'             => '00:00-24:00',
    'day 2'                => '00:00-24:00',
    'february 10'          => '00:00-24:00',
    'february -1'          => '00:00-24:00',
    'friday -2'            => '00:00-24:00, 10:30-12:00',
    'thursday -1 november' => '00:00-14:00,18-24:00',
};
is_deeply($obj->{'conf'}, $t1, 'parsed timeperiod 1');


$obj = $parsedfile->{'objects'}->[1];
my $t2 = {
    'timeperiod_name'                => 'misc-date-ranges',
    'alias'                          => 'Misc Date Ranges',
    'july 10 - 15'                   => '00:00-24:00',
    'day 20 - -1'                    => '00:00-24:00',
    'day 1 - 15'                     => '00:00-24:00',
    '2007-01-01 - 2008-02-01'        => '00:00-24:00',
    'tuesday 1 april - friday 2 may' => '00:00-24:00',
    'april 10 - may 15'              => '00:00-24:00',
    'monday 3 - thursday 4'          => '00:00-24:00'
};
is_deeply($obj->{'conf'}, $t2, 'parsed timeperiod 2');

$obj = $parsedfile->{'objects'}->[2];
my $t3 = {
    'timeperiod_name'                    => 'misc-skip-ranges',
    'alias'                              => 'Misc Skip Ranges',
    'monday 3 - thursday 4 / 2'          => '00:00-24:00',
    '2008-04-01 / 7'                     => '00:00-24:00',
    '2007-01-01 - 2008-02-01 / 3'        => '00:00-24:00',
    'tuesday 1 april - friday 2 may / 6' => '00:00-24:00',
    'july 10 - 15 / 2'                   => '00:00-24:00',
    'day 1 - 15 / 5'                     => '00:00-24:00'
};
is_deeply($obj->{'conf'}, $t3, 'parsed timeperiod 3');


###########################################################
$objects = Monitoring::Config->new({ core_conf => './t/xt/conf/data/4/core.cfg' });
$objects->init();
my $objs = $objects->get_objects();
is(scalar @{$objs}, 3, "number of objects");

###########################################################
$objects = Monitoring::Config->new({ obj_dir => './t/xt/conf/data/5/' });
$objects->init();
$objs = $objects->get_objects();
is(scalar @{$objects->{'errors'}}, 0, "number of errors") or diag(Dumper($objects->{'errors'}));
is(scalar @{$objs}, 2, "number of objects");
$objs = $objects->get_objects_by_type('host');
is(scalar @{$objs}, 1, "number of hosts");
$objs = $objects->get_objects_by_name('host', 'name');
is(scalar @{$objs}, 1, "number of hosts by name");

###########################################################
$objects = Monitoring::Config->new({ obj_dir => './t/xt/conf/data/6/' });
$objects->init();
$objs = $objects->get_objects();
is(scalar @{$objects->{'errors'}}, 0, "number of errors") or diag(Dumper($objects->{'errors'}));
is(scalar @{$objs}, 2, "number of objects");
$parsedfile = $objects->get_file_by_path('./t/xt/conf/data/6/servicegroups_iso-8859.cfg');
$obj = $parsedfile->{'objects'}->[0];
my $g1 = {
  'servicegroup_name' => 'project_12345',
  'alias'             => 'Mandantenübergreifender Login',
};
is_deeply($obj->{'conf'}, $g1, 'parsed ISO-8859 group');

my $g2 = {
  'servicegroup_name' => 'project_utf8',
  'alias'             => 'Mandantenübergreifender Login',
};

$parsedfile = $objects->get_file_by_path('./t/xt/conf/data/6/servicegroups_utf8.cfg');
$obj = $parsedfile->{'objects'}->[0];
is_deeply($obj->{'conf'}, $g2, 'parsed UTF-8 group');

###########################################################
$objects = Monitoring::Config->new({ obj_dir => './t/xt/conf/data/7/' });
$objects->init();
$objs = $objects->get_objects();
is(scalar @{$objects->{'errors'}}, 0, "number of errors") or diag(Dumper($objects->{'errors'}));
is(scalar @{$objs}, 2, "number of objects");

###########################################################
# commented objects
$objects = Monitoring::Config->new({ obj_dir => './t/xt/conf/data/8/' });
$objects->init();
$objs = $objects->get_objects();
is(scalar @{$objects->{'errors'}}, 0, "number of errors") or diag(Dumper($objects->{'errors'}));
is(scalar @{$objects->{'parse_errors'}}, 0, "number of parse errors") or diag(Dumper($objects->{'parse_errors'}));
is(scalar @{$objs}, 2, "number of objects");
@{$objs} = sort {uc($a->get_name()) cmp uc($b->get_name())} @{$objs};
is($objs->[0]->{'disabled'}, 0, "first object is enabled");
is($objs->[1]->{'disabled'}, 1, "second object is disabled");

###########################################################
my @comments = split/\n/mx,"
###############################################################################
#
# SERVICES
#
#    http://nagios.sourceforge.net/docs/2_0/xodtemplate.html#service
#
###############################################################################
###BLAH by BLUB
#";
my $orig_comments = dclone(\@comments);
my $com = Monitoring::Config::Object::format_comments(\@comments);
is_deeply($orig_comments, \@comments, 'comments shouldn\'t change');
