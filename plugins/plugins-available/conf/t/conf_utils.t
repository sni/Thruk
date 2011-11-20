use strict;
use warnings;
use Test::More tests => 350;
use Data::Dumper;
use File::Temp qw/ tempfile /;
use File::Slurp;
use Storable qw/ dclone /;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###########################################################
# load modules
use_ok 'Monitoring::Config';
use_ok 'Monitoring::Config::Help';
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
# check object definitions
for my $type (@{$Monitoring::Config::Object::Types}) {
    use_ok 'Monitoring::Config::Object::'.ucfirst($type);
    my $obj = Monitoring::Config::Object->new(type => $type);
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
is( scalar @{ $objects->{'files'} }, 1, 'number of files parsed' ) or BAIL_OUT("useless without parsed files");
my $parsedfile = $objects->{'files'}->[0];
is( $parsedfile->{'md5'}, 'bf6f91fcc7c569f4cc96bcdf8e926811', 'files md5 sum' );
like( $parsedfile->{'errors'}->[0], '/unknown object type \'blah\'/', 'parse error' );
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
           'use',
           'address',
           'contact_groups',
           'hostgroups',
           'icon_image',
           'icon_image_alt',
           'parents',
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
is(scalar @{$objects->{'errors'}}, 0, "number of errors");
is(scalar @{$objs}, 2, "number of objects");
$objs = $objects->get_objects_by_type('host');
is(scalar @{$objs}, 1, "number of hosts");
$objs = $objects->get_objects_by_name('host', 'name');
is(scalar @{$objs}, 1, "number of hosts by name");

#$Data::Dumper::Sortkeys = \&my_filter;
#use Data::Dumper; print STDERR Dumper($objs);
#use Data::Dumper; print STDERR Dumper($objects);
#sub my_filter {
#    my ($hash) = @_;
#    delete $hash->{'default'};
#    my @keys   = keys %{$hash};
#    return [ sort @keys ];
#}

1;
