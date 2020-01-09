use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 69;
$Data::Dumper::Sortkeys = 1;

use_ok('Thruk::Backend::Provider::Mysql');

my $m = Thruk::Backend::Provider::Mysql->new({options => {peer => 'mysql://test:test@host:3306/dbname', peer_key => 'abcd'}});
isa_ok($m, 'Thruk::Backend::Provider::Mysql');

#####################################################################
# test some connection examples
my $connection_strings = [
    'mysql://test:test@host:3306/dbname' => {
        'dbhost' => 'host',
        'dbport' => '3306',
        'dbname' => 'dbname',
        'dbuser' => 'test',
        'dbpass' => 'test',
    },
    'mysql://test@host:3306/dbname' => {
        'dbhost' => 'host',
        'dbport' => '3306',
        'dbname' => 'dbname',
        'dbuser' => 'test',
        'dbpass' => '',
    },
    'mysql://test:test@host/dbname' => {
        'dbhost' => 'host',
        'dbport' => '',
        'dbname' => 'dbname',
        'dbuser' => 'test',
        'dbpass' => 'test',
    },
    'mysql://test@host/dbname' => {
        'dbhost' => 'host',
        'dbport' => '',
        'dbname' => 'dbname',
        'dbuser' => 'test',
        'dbpass' => '',
    },
    'mysql://test:test@/tmp/mysql.sock/dbname' => {
        'dbhost' => 'localhost',
        'dbsock' => '/tmp/mysql.sock',
        'dbport' => '',
        'dbname' => 'dbname',
        'dbuser' => 'test',
        'dbpass' => 'test',
    },
    'mysql://test@/tmp/mysql.sock/dbname' => {
        'dbsock' => '/tmp/mysql.sock',
        'dbhost' => 'localhost',
        'dbport' => '',
        'dbname' => 'dbname',
        'dbuser' => 'test',
        'dbpass' => '',
    }
];
my $x = 0;
while($x < scalar @{$connection_strings}) {
    my $con = $connection_strings->[$x];
    my $exp = $connection_strings->[$x+1];
    ok($con, $con);
    my $m   = Thruk::Backend::Provider::Mysql->new({options => {peer => $con, peer_key => 'abcd'}});
    isa_ok($m, 'Thruk::Backend::Provider::Mysql');
    for my $key (sort keys %{$exp}) {
        is($m->{$key}, $exp->{$key}, $key.' config');
    }
    $x = $x + 2;
}

#####################################################################
test_filter(
    'empty list',
    [],  # input
    "",  # expected
);

#####################################################################
test_filter(
    'simple match',
    [{ 'name' => 'test' }],  # input
    " WHERE name = 'test'",  # expected
);

#####################################################################
test_filter(
    'cascaded match',
    [{ 'name' => { '=' => 'test' }}], # input
    " WHERE name = 'test'",           # expected
);

#####################################################################
test_filter(
    'regular expression',
    [{ 'name' => { '~~' => 'no_worker' } }],  # input
    " WHERE name RLIKE 'no_worker'",          # expected
);

#####################################################################
test_filter(
    'negate regular expression',
    [{ 'name' => { '!~~' => 'no_worker' } }],    # input
    " WHERE name NOT RLIKE 'no_worker'",         # expected
);

#####################################################################
test_filter(
    'in list',
    [[{ '-or' => { 'groups' => { '>=' => [ 'no_worker' ] } } }]],
    " WHERE groups = 'no_worker'",
);

#####################################################################
test_filter(
    'in list 2',
    [[{ '-or' => { 'groups' => { '>=' => [ 'g1', 'g2' ] } } }]],
    " WHERE (groups = 'g1' OR groups = 'g2')",
);

#####################################################################
test_filter(
    'not in list',
    [ { 'groups' => { '!>=' => 'no_worker' } } ],
    " WHERE groups != 'no_worker'",
);

#####################################################################
test_filter(
    'list or',
    [{ '-or' => [ 'host_name', { '=' => 'child' },
                  'host_alias', { '=' => 'child' },
                  'host_address', { '=' => 'child' }
                ]
    }],
    " WHERE (host_name = 'child' OR host_alias = 'child' OR host_address = 'child')",
);

#####################################################################
test_filter(
    'list or',
    [{ '-and' => [ 'last_state_change', { '!=' => 0 },
                   'last_state_change', { '>=' => 1336941620 }
                 ]
    }],
    " WHERE (last_state_change != 0 AND last_state_change >= 1336941620)",
);

#####################################################################
test_filter(
    'simple and',
    [ { 'description' => 'service', 'host_name' => 'host' } ],
    " WHERE (description = 'service' AND host_name = 'host')",
);

#####################################################################
test_filter(
    'advanced list',
    [{ 'host_name' => 'child' },
     { 'host_alias' => 'child' },
     { 'host_address' => 'child'}
    ],
    " WHERE (host_name = 'child' AND host_alias = 'child' AND host_address = 'child')",
);

#####################################################################
test_filter(
    'scalar list',
    [ 'name', 'child' ],
    " WHERE name = 'child'",
);

#####################################################################
test_filter(
    'in list',
    [ { 'groups' => { '>=' => 'test' } } ],
    " WHERE groups IN ('test')",
);

#####################################################################
test_filter(
    'hash list',
    [{ '-or' => [ { 'service_description' => { '!=' => undef } }, { 'service_description' => undef } ] }, 'service_description', undef ],
    " WHERE ((service_description != '' OR service_description = '') AND service_description = '')"
);

#####################################################################
test_filter(
    'hash list',
    { '-and' => { 'state' => 1, 'has_been_checked' => 1 } },
    ' WHERE (has_been_checked = 1 AND state = 1)'
);

#####################################################################
test_filter(
    'undef in list',
    { '-and' => [ { 'type' => 'SERVICE ALERT' }, undef ] },
    " WHERE type = 'SERVICE ALERT'"
);

#####################################################################
test_filter(
    'tripple filter',
    { '-and' => [ { 'type' => 'SERVICE ALERT' }, { 'service_description' => { '!=' => undef },   'state' => 1 } ] },
    " WHERE (type = 'SERVICE ALERT' AND (service_description != '' AND state = 1))"
);

#####################################################################
test_filter(
    'joined lists',
    { '-or' => [
                 [
                   { 'type' => 'HOST ALERT' },
                   { 'state_type' => { '=' => 'HARD' } }
                 ],
                 [
                   { 'type' => 'INITIAL HOST STATE' },
                   { 'state_type' => { '=' => 'HARD' } }
                 ],
               ]
    },
   " WHERE ((type = 'HOST ALERT' AND state_type = 'HARD') OR (type = 'INITIAL HOST STATE' AND state_type = 'HARD'))"
);

#####################################################################
test_filter(
    'time filter',
    [{ '-and' => [
        { 'time' => { '>=' => 1524053699 } },
        { 'time' => { '<' => 1524140099 } }
      ]
    }],
    " WHERE (time >= 1524053699 AND time < 1524140099)",
);

#####################################################################
test_filter(
    'undef list filter',
    [undef, [
        { 'time' => { '>=' => 1524053699 } },
        { 'time' => { '<' => 1524140099 } }
      ]
    ],
    " WHERE (time >= 1524053699 AND time < 1524140099)",
);

#####################################################################
test_filter(
    'undef hash filter',
    [undef,
     { 'time' => { '>=' => 1524053699 } },
    ],
    " WHERE time >= 1524053699",
);

#####################################################################
test_filter(
    'all hosts filter',
    [{ '-and' => [
        { 'host_name'   => { '~~' => '.*' } },
        { 'description' => 'http' }
    ]}],
    " WHERE (host_name RLIKE '.*' AND description = 'http')",
);


#####################################################################
# SUBS
sub test_filter {
    my($name, $inp, $out) = @_;
    my($tst) = $m->_get_filter($inp);
    is_deeply($tst, $out, 'filter: '.$name) or diag("input:\n".Dumper($inp)."\nexpected:\n".Dumper($out)."\ngot:\n".Dumper($tst));
}
