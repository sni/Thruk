use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 19;
$Data::Dumper::Sortkeys = 1;

use_ok('Thruk::Backend::Provider::Mongodb');

my $m = Thruk::Backend::Provider::Mongodb->new({peer => 'localhost:12345/dbname'});
isa_ok($m, 'Thruk::Backend::Provider::Mongodb');

#####################################################################
test_filter(
    'empty list',
    [],  # input
    {},  # expected
);

#####################################################################
test_filter(
    'simple match',
    [{ 'name' => 'test' }],  # input
    { 'name' => 'test' },    # expected
);

#####################################################################
test_filter(
    'cascaded match',
    [{ 'name' => { '=' => 'test' }}], # input
    { 'name' => 'test' },             # expected
);

#####################################################################
test_filter(
    'regular expression',
    [{ 'name' => { '~~' => 'no_worker' } }],  # input
    { 'name' => qr/no_worker/imx },           # expected
);

#####################################################################
test_filter(
    'negate regular expression',
    [{ 'name' => { '!~~' => 'no_worker' } }],    # input
    { 'name' => { '$not' => qr/no_worker/mxi }}, # expected
);

#####################################################################
test_filter(
    'in list',
    [[{ '-or' => { 'groups' => { '>=' => [ 'no_worker' ] } } }]],
    { 'groups' => { '$in' => [ 'no_worker' ] } },
);

#####################################################################
test_filter(
    'not in list',
    [ { 'groups' => { '!>=' => 'no_worker' } } ],
    { 'groups' => { '$nin' => [ 'no_worker' ] } },
);

#####################################################################
test_filter(
    'list or',
    [{ '-or' => [ 'host_name', { '=' => 'child' },
                  'host_alias', { '=' => 'child' },
                  'host_address', { '=' => 'child' }
                ]
    }],
    { '$or' => [ { 'host_name' => 'child' },
                 { 'host_alias' => 'child' },
                 { 'host_address' => 'child'},
    ]},
);

#####################################################################
test_filter(
    'list or',
    [{ '-and' => [ 'last_state_change', { '!=' => 0 },
                   'last_state_change', { '>=' => 1336941620 }
                 ]
    }],
    { '$and' => [{ 'last_state_change' => { '$ne' => 0 } },
                 { 'last_state_change' => { '$gte' => 1336941620 } }
                ]
    },
);

#####################################################################
test_filter(
    'simple and',
    [ { 'host_name' => 'host', 'description' => 'service' } ],
    [ { 'host_name' => 'host' }, { 'description' => 'service' } ],
);

#####################################################################
test_filter(
    'advanced list',
    [{ 'host_name' => 'child' },
     { 'host_alias' => 'child' },
     { 'host_address' => 'child'}
    ],
    { '$and' => [{ 'host_name' => 'child' },
                 { 'host_alias' => 'child' },
                 { 'host_address' => 'child'}
                ]
    },
);

#####################################################################
test_filter(
    'scalar list',
    [ 'name', 'child' ],
    { 'name' => 'child' },
);

#####################################################################
test_filter(
    'in list',
    [ { 'groups' => { '>=' => 'test' } } ],
    { 'groups' => { '$in' => [ 'test' ] } },
);

#####################################################################
test_filter(
    'hash list',
    [{ '-or' => [ { 'service_description' => { '!=' => undef } }, { 'service_description' => undef } ] }, 'service_description', undef ],
    { '$and' => [ { '$or' => [ { 'service_description' => { '$ne' => '' } }, { 'service_description' => '' } ] }, { 'service_description' => '' } ] },
);

#####################################################################
test_filter(
    'hash list',
    { '-and' => { 'state' => 1, 'has_been_checked' => 1 } },
    { '$and' => [ { 'state' => 1 }, { 'has_been_checked' => 1 } ] }
);

#####################################################################
test_filter(
    'undef in list',
    { '-and' => [ { 'type' => 'SERVICE ALERT' }, undef ] },
    { 'type' => 'SERVICE ALERT' },
);

#####################################################################
test_filter(
    'tripple filter',
    { '-and' => [ { 'type' => 'SERVICE ALERT' }, { 'service_description' => { '!=' => undef },   'state' => 1 } ] },
    { '$and' => [ { 'type' => 'SERVICE ALERT' }, { 'service_description' => { '$ne' => '' } }, { 'state' => 1 } ] },
);

#####################################################################
# SUBS
sub test_filter {
    my($name, $inp, $out) = @_;
    my $tst = $m->_get_filter($inp);
    is_deeply($out, $tst, 'filter: '.$name) or diag("input:\n".Dumper($inp)."\nexpected:\n".Dumper($out)."\ngot:\n".Dumper($tst));
}
