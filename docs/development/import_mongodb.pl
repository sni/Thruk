#!/usr/bin/perl

use strict;
use warnings;
use MongoDB;
use MongoDB::OID;
use Thruk::Backend::Provider::Livestatus;

#########################################################################
my $conn   = MongoDB::Connection->new(host => 'localhost:27017');
my $dbname = 'shinken';

#########################################################################
my $ml = Thruk::Backend::Provider::Livestatus->new(
#                    { peer => '127.0.0.5:6558'     },
                    { peer => '/omd/sites/devel/tmp/run/live'     },
                    {'min_livestatus_version' => 0 }
);

#########################
for my $table (qw/hosts services timeperiods contacts contactgroups commands comments downtimes hostgroups servicegroups processinfo status/) {
    print $table;
    my $db = $conn->$dbname;
    $db->run_command({drop => $table});
    my $col = $db->$table;
    my $data;
    if($table eq 'status') {
        eval '($data) = $ml->get_extra_perf_stats();';
    } else {
        eval '($data) = $ml->get_'.$table.'();';
    }
    if($table eq 'processinfo') { $data = [values %{$data}]; $data->[0]->{'data_source_version'} = "1.0"; }
    if($table eq 'status')      { $data = [$data]; }
    for my $d (@{$data}) {
        print '.';
        $col->insert($d);
    }
    print "\n";
}
