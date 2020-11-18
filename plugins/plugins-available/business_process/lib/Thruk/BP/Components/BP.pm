package Thruk::BP::Components::BP;

use strict;
use warnings;
use Data::Dumper;
use Carp;
use File::Temp;
use File::Copy qw/move/;
use Fcntl qw/:DEFAULT/;
use Thruk::Utils;
use Thruk::Utils::IO;
use Thruk::BP::Components::Node;
use Time::HiRes qw/gettimeofday tv_interval/;
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::BP::Components::Node - BP Class

=head1 DESCRIPTION

Business Process

=head1 METHODS

=cut

my @extra_json_keys = qw/id draft/;
my @stateful_keys   = qw/status status_text last_check last_state_change time affected_peers bp_backend/;
my @saved_keys      = qw/name template rankDir state_type filter create_host_object/;

##########################################################

=head2 new

return new business process

=cut

sub new {
    my($class, $c, $file, $bpdata, $editmode) = @_;

    my $self = {
        'id'                 => undef,
        'editmode'           => $editmode,
        'name'               => undef,
        'site'               => '',
        'template'           => $bpdata->{'template'} || '',
        'filter'             => [],
        'nodes'              => [],
        'nodes_by_id'        => {},
        'nodes_by_name'      => {},
        'need_update'        => {},
        'need_save'          => 0,
        'file'               => undef,
        'datafile'           => undef,
        'editfile'           => undef,

        'time'               => 0,
        'status'             => 4,
        'status_text'        => 'not yet checked',
        'last_check'         => 0,
        'last_state_change'  => 0,
        'rankDir'            => 'TB',
        'state_type'         => 'both',

        'exported_nodes'     => {},
        'testmode'           => 0,
        'draft'              => 0,
        'create_host_object' => 1,      # 0 - do no create a host object, 1 - create naemon host object
    };
    bless $self, $class;
    $self->set_file($c, $file);
    if(!-e $file) {
        $self->{'draft'} = 1;
    }

    if($editmode and -e $self->{'editfile'}) { $file = $self->{'editfile'}; }
    if(-s $file) {
        $bpdata = Thruk::Utils::IO::json_lock_retrieve($file);
        return unless $bpdata;
        return unless $bpdata->{'name'};
    }
    for my $key (@saved_keys) {
        $self->{$key} = $bpdata->{$key} if defined $bpdata->{$key};
    }
    $self->set_label($c, $bpdata->{'name'});

    return unless $self->{'name'};

    # read in nodes
    for my $n (@{Thruk::Utils::list($bpdata->{'nodes'} || [])}) {
        my $node = Thruk::BP::Components::Node->new($n);
        $self->add_node($node, 1);
    }

    $self->load_runtime_data();

    # add default filter
    $self->{'default_filter'} = Thruk::Utils::list($c->config->{'Thruk::Plugin::BP'}->{'default_filter'});

    $self->save() if $self->{'need_save'};

    for my $n (@{$self->{'nodes'}}) {
        $n->update_parents($self);
    }

    confess("status_text cannot be empty") unless defined $self->{'status_text'};

    our $default_state_order;
    if(!$default_state_order) {
        $default_state_order = $c->config->{'Thruk::Plugin::BP'}->{'default_state_order'} // $c->config->{'default_state_order'};
        $default_state_order = [split(/\s*,\s*/mx, $default_state_order)];
    }
    $self->{'default_state_order'} = $default_state_order;

    return $self;
}

##########################################################

=head2 fullid

return id and optional peer key

=cut
sub fullid {
    my($self) = @_;
    return($self->{'bp_backend'}.':'.$self->{'id'}) if $self->{'bp_backend'};
    return($self->{'id'});
}

##########################################################

=head2 filter

return list of filters + default filter

=cut
sub filter {
    my($self) = @_;
    return(Thruk::Utils::array_uniq([@{$self->{'default_filter'}}, @{$self->{'filter'}}]));
}

##########################################################

=head2 load_runtime_data

update runtime data

=cut
sub load_runtime_data {
    my($self) = @_;

    my $file = $self->{'datafile'};
    if($self->{'editmode'} and -s $self->{'datafile'}.'.edit') {
        $file = $self->{'datafile'}.'.edit';
    }

    return unless -s $file;

    my $data = Thruk::Utils::IO::json_lock_retrieve($file);
    for my $key (@stateful_keys) {
        $self->{$key} = $data->{$key} if defined $data->{$key};
    }

    for my $n (@{$self->{'nodes'}}) {
        $n->load_runtime_data($data->{'nodes'}->{$n->{'id'}});
    }
    return;
}

##########################################################

=head2 update_status

    update_status($c, [$type])

type:
    0 / undef:      update everything
    1:              only recalculate

update status of business process

=cut
sub update_status {
    my ( $self, $c, $type ) = @_;
    die("no context") unless $c;

    $c->stats->profile(begin => "update_status");
    my $t0 = [gettimeofday];

    # set backends to default list, bp result should be deterministic
    $c->{'db'}->enable_default_backends();

    $type = 0 unless defined $type;
    my $last_state = $self->{'status'};

    my $results = [];
    my($livedata);
    if($type == 0) {
        $livedata = $self->bulk_fetch_live_data($c);
        my $previous_affected = $self->{'affected_peers'};
        $self->{'affected_peers'} = $self->_extract_affected_backends($livedata);
        my $failed = $self->_list_failed_backends($c, $previous_affected, $c->stash->{'failed_backends'});
        if(scalar @{$failed} > 0 && ($self->{'last_check'} > (time() - 180))) {
            _warn("not updating business process '".$self->{'name'}."' because the backends ".join(",", @{$failed})." are available. Waiting 3 minutes to recover, last successful update: ".(scalar localtime $self->{'last_check'}));
            return;
        }
        for my $n (@{$self->{'nodes'}}) {
            my $r = $n->update_status($c, $self, $livedata);
            push @{$results}, $n->{'id'} if $r;
        }
    }

    my $iterations = 0;
    while(scalar keys %{$self->{'need_update'}} > 0) {
        $iterations++;
        for my $id (keys %{$self->{'need_update'}}) {
            my $r = $self->{'nodes_by_id'}->{$id}->update_status($c, $self, $livedata, $type);
            push @{$results}, $id if $r;
        }
        die("circular dependenies? Still have these on the update list: ".Dumper($self->{'need_update'})) if $iterations > 10;
    }

    $results = Thruk::Utils::array_uniq($results);

    # update last check time
    my $now = time();
    $self->{'last_check'} = $now;
    if($last_state != $self->{'status'}) {
        $self->{'last_state_change'} = $now;
    }

    # everything else is non-edit only
    return if $self->{'testmode'};
    if($self->{'editmode'}) {
        $self->save_runtime();
        return;
    }

    # submit back to core
    $c->stats->profile(begin => "_submit_results_to_core");
    $self->_submit_results_to_core($c, $results);
    $c->stats->profile(end => "_submit_results_to_core");

    # sync ack/downtime status
    $c->stats->profile(begin => "_sync_ack_downtime_status");
    $self->_sync_ack_downtime_status($c, $results);
    $c->stats->profile(end => "_sync_ack_downtime_status");

    # save runtime
    $self->{'time'} = tv_interval($t0);

    # store runtime data
    $self->save_runtime();

    $c->stats->profile(end => "update_status");
    return;
}

##########################################################

=head2 set_label

set label for this business process

=cut
sub set_label {
    my($self, $c, $label) = @_;
    $self->{'name'} = $label;
    return;
}

##########################################################

=head2 set_status

set status for this business process

=cut
sub set_status {
    my($self, $state, $text) = @_;
    confess("status text cannot be empty") unless defined $text;

    my $last_state = $self->{'status'};

    # update last check time
    my $now = time();
    $self->{'last_check'} = $now;

    $self->{'status'}      = $state;
    $self->{'status_text'} = $text;

    if($last_state != $state) {
        $self->{'last_state_change'} = $now;
    }
    return;
}

##########################################################

=head2 set_file

set file for this business process

=cut
sub set_file {
    my($self, $c, $file) = @_;
    my $basename = $file;
    $basename    =~ s/^.*\///mx;
    $self->{'file'}     = Thruk::BP::Utils::bp_base_folder($c).'/'.$basename;
    $self->{'datafile'} = $c->config->{'var_path'}.'/bp/'.$basename.'.runtime';
    $self->{'editfile'} = $c->config->{'var_path'}.'/bp/'.$basename.'.edit';
    if($basename =~ m/(\d+).tbp/mx) {
        $self->{'id'} = $1;
    } else {
        die("wrong file format in ".$basename);
    }
    return;
}

##########################################################

=head2 get_node

return node by id

=cut
sub get_node {
    my ( $self, $node_id ) = @_;
    return $self->{'nodes_by_id'}->{$node_id};
}

##########################################################

=head2 get_json_nodes

return nodes as json array

=cut
sub get_json_nodes {
    my($self, $c) = @_;
    my $list = [];
    for my $n (@{$self->{'nodes'}}) {
        push @{$list}, {
          id                        => $n->{'id'},
          label                     => $n->{'label'},
          host                      => $n->{'host'},
          service                   => $n->{'service'},
          hostgroup                 => $n->{'hostgroup'},
          servicegroup              => $n->{'servicegroup'},
          template                  => $n->{'template'},
          create_obj                => $n->{'create_obj'} ? Cpanel::JSON::XS::true : Cpanel::JSON::XS::false,
          create_obj_ok             => $n->{'create_obj_ok'} ? Cpanel::JSON::XS::true : Cpanel::JSON::XS::false,
          status                    => $n->{'status'},
          status_text               => $n->{'status_text'},
          short_desc                => $n->{'short_desc'},
          last_check                => $n->{'last_check'} ? Thruk::Utils::Filter::date_format($c, $n->{'last_check'}) : 'never',
          duration                  => $n->{'last_state_change'} ? Thruk::Utils::Filter::duration(time() - $n->{'last_state_change'}) : '',
          acknowledged              => $n->{'acknowledged'}."",
          scheduled_downtime_depth  => $n->{'scheduled_downtime_depth'}."",
          bp_ref                    => $n->{'bp_ref'},
          bp_ref_peer               => $n->{'bp_ref_peer'},
          depends                   => $n->{'depends'},
          func                      => $n->{'function'},
          func_args                 => $n->{'function_args'},
          contacts                  => $n->{'contacts'},
          contactgroups             => $n->{'contactgroups'},
          notification_period       => $n->{'notification_period'},
          max_check_attempts        => $n->{'max_check_attempts'},
          event_handler             => $n->{'event_handler'},
          filter                    => $n->{'filter'},
        }
    }
    return(Thruk::Utils::Filter::json_encode($list));
}

##########################################################

=head2 add_node

add new node to business process

=cut
sub add_node {
    my ( $self, $node, $init ) = @_;
    push @{$self->{'nodes'}}, $node;
    if(!$init) {
        # verify uniq id
        my $id = $node->{'id'} || $self->make_new_node_id();
        if($self->{'nodes_by_id'}->{$id}) {
            $node->set_id($self->make_new_node_id());
        }
        $node->set_id($id);
    } else {
        if(!$node->{'id'}) {
            my $id = $self->make_new_node_id();
            $node->set_id($id);
        }
    }
    $self->{'nodes_by_id'}->{$node->{'id'}}      = $node if $node->{'id'};
    $self->{'nodes_by_name'}->{$node->{'label'}} = $node;

    if($self->{'exported_nodes'}->{$node->{'label'}}) {
        $node->{'create_obj_ok'} = 0;
        $node->{'create_obj'}    = 0;
    } elsif($node->{'create_obj'}) {
        $self->{'exported_nodes'}->{$node->{'label'}} = 1;
    }

    return;
}

##########################################################

=head2 remove_node

remove node from business process

=cut
sub remove_node {
    my ( $self, $node_id ) = @_;
    my $node = $self->{'nodes_by_id'}->{$node_id};
    delete $self->{'nodes_by_id'}->{$node_id};
    delete $self->{'nodes_by_name'}->{$node->{'label'}};

    # remove connections
    for my $p (@{$node->parents($self)}) {
        my @depends;
        for my $d (@{$p->depends($self)}) {
            push @depends, $d->{'id'} unless $d->{'id'} eq $node_id;
        }
        $p->{'depends'} = \@depends;
    }

    for my $d (@{$node->depends($self)}) {
        my @parents;
        for my $p (@{$d->parents($self)}) {
            push @parents, $p->{'id'} unless $p->{'id'} eq $node_id;
        }
        $d->{'parents'} = \@parents;
    }

    my @nodes;
    for my $n (@{$self->{'nodes'}}) {
        push @nodes, $n unless $n->{'id'} eq $node_id;
    }
    $self->{'nodes'} = \@nodes;

    if($node->{'create_obj'}) {
        delete $self->{'exported_nodes'}->{$node->{'label'}};
    }

    return;
}

##########################################################

=head2 remove

remove business process along with all data files

=cut
sub remove {
    my ( $self ) = @_;
    unlink($self->{'file'});     # may not exist, if removed before first commit
    unlink($self->{'datafile'}); # can fail if not updated before removal
    unlink($self->{'editfile'}); # may also not exist
    unlink($self->{'datafile'}.'.edit');
    return;
}

##########################################################

=head2 commit

commit business process data to file

=cut
sub commit {
    my ( $self, $c ) = @_;

    # run pre hook
    if($c->config->{'Thruk::Plugin::BP'}->{'pre_save_cmd'}) {
        local $ENV{'THRUK_BP_FILE'}  = $self->{'file'};
        local $ENV{'THRUK_BP_STAGE'} = 'pre';
        my($rc, $out) = Thruk::Utils::IO::cmd($c, $c->config->{'Thruk::Plugin::BP'}->{'pre_save_cmd'});
        if($rc != 0) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'pre save hook failed: '.$rc.': '.$out, escape => 0 });
            return;
        }
    }

    if(-e $self->{'editfile'}) {
        move($self->{'editfile'}, $self->{'file'}) or die('cannot commit changes to '.$self->{'file'}.': '.$!);
        unlink($self->{'editfile'});
    }
    unlink($self->{'datafile'}.'.edit');

    # run post hook
    if($c->config->{'Thruk::Plugin::BP'}->{'post_save_cmd'}) {
        local $ENV{'THRUK_BP_FILE'}  = $self->{'file'};
        local $ENV{'THRUK_BP_STAGE'} = 'post';
        my($rc, $out) = Thruk::Utils::IO::cmd($c, $c->config->{'Thruk::Plugin::BP'}->{'post_save_cmd'});
        if($rc != 0) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'post save hook failed: '.$rc.': '.$out, escape => 0 });
            return;
        }
    }

    return 1;
}

##########################################################

=head2 save

save business process data to temporary edit file

=cut
sub save {
    my ( $self, $c ) = @_;

    return if $self->{'testmode'};

    my $obj = {
        nodes     => [],
    };

    for my $key (@saved_keys) {
        $obj->{$key} = $self->{$key};
    }

    for my $n (@{$self->{'nodes'}}) {
        push @{$obj->{'nodes'}}, $n->get_save_obj();
    }

    Thruk::Utils::IO::json_lock_store($self->{'editfile'}, $obj, { pretty => 1 });
    $self->{'need_save'} = 0;

    return 1;
}

##########################################################

=head2 get_objects_conf

    get_objects_conf()

return object config.

=cut
sub get_objects_conf {
    my($self) = @_;
    my $obj = {
        'hosts'    => {},
        'services' => {},
    };
    for my $n (@{$self->{'nodes'}}) {
        my $nodedata = $n->get_objects_conf($self);
        Thruk::BP::Utils::merge_obj_hash($obj, $nodedata) if $nodedata;
    }
    return $obj;
}

##########################################################

=head2 save_runtime

save run time data

=cut
sub save_runtime {
    my ( $self ) = @_;
    return if $self->{'testmode'};
    my $data = {};
    for my $key (@stateful_keys) {
        $data->{$key} = $self->{$key};
    }
    for my $n (@{$self->{'nodes'}}) {
        $data->{'nodes'}->{$n->{'id'}} = $n->get_stateful_data();
    }
    if($self->{'editmode'}) {
        Thruk::Utils::IO::json_lock_store($self->{'datafile'}.'.edit', $data);
    } else {
        Thruk::Utils::IO::json_lock_store($self->{'datafile'}, $data);
    }
    return;
}

##########################################################

=head2 make_new_node_id

generate new uniq id

=cut
sub make_new_node_id {
    my ( $self ) = @_;
    my $num = 1;
    my $id  = 'node'.$num;
    while($self->{'nodes_by_id'}->{$id}) {
        $id = 'node'.++$num;
    }
    $self->{'need_save'} = 1;
    return $id;
}

##########################################################

=head2 bulk_fetch_live_data

return all live data needed for this business process

=cut
sub bulk_fetch_live_data {
    my($self, $c, $expand_groups) = @_;

    # check if have filters in place which requires fetching all hosts / services for group filters
    my $has_filters = 0;
    if(scalar @{$self->filter()} > 0) {
        $has_filters = 1;
    } else {
        for my $n (@{$self->{'nodes'}}) {
            if(scalar @{$n->{'filter'}} > 0) {
                $has_filters = 1;
                last;
            }
        }
    }
    $expand_groups = 1 if $has_filters;

    # bulk fetch live data
    my $hostfilter         = {};
    my $servicefilter      = {};
    my $hostgroupfilter    = {};
    my $servicegroupfilter = {};
    my $hostdata           = {};
    my $servicedata        = {};
    my $hostgroupdata      = {};
    my $servicegroupdata   = {};
    for my $n (@{$self->{'nodes'}}) {
        if(lc $n->{'function'} eq 'status') {
            if($n->{'host'} and $n->{'service'}) {
                $servicefilter->{$n->{'host'}}->{$n->{'service'}} = $n->{'function_args'}->[2] || '=';
            }
            elsif($n->{'host'}) {
                $hostfilter->{$n->{'host'}} = 1;
            }
        }
        elsif(lc $n->{'function'} eq 'groupstatus') {
            if($n->{'hostgroup'}) {
                $hostgroupfilter->{$n->{'hostgroup'}} = 1;
            }
            elsif($n->{'servicegroup'}) {
                $servicegroupfilter->{$n->{'servicegroup'}} = 1;
            }
        }
    }


    if($expand_groups) {
        # set empty group statistics for requested host/servicegroups
        for my $hostgroupname (keys %{$hostgroupfilter}) {
            $hostgroupdata->{$hostgroupname} = Thruk::Utils::Status::summary_set_group_defaults();
        }
        for my $servicegroupname (keys %{$servicegroupfilter}) {
            $servicegroupdata->{$servicegroupname} = Thruk::Utils::Status::summary_set_group_defaults();
        }
    }

    if(scalar keys %{$hostfilter} > 0) {
        my @filter;
        for my $hostname (keys %{$hostfilter}) {
            push @filter, { name => $hostname };
        }
        if($expand_groups && scalar keys %{$hostgroupfilter} > 0) {
            for my $hostgroupname (keys %{$hostgroupfilter}) {
                push @filter, { groups => { '>=' => $hostgroupname } };
            }
        }
        my $filter = Thruk::Utils::combine_filter( '-or', \@filter );
        my $data   = $c->{'db'}->get_hosts(filter => [$filter], extra_columns => [qw/long_plugin_output last_hard_state last_hard_state_change/]);
        $hostdata  = Thruk::Utils::array2hash($data, 'name');
    }
    if(scalar keys %{$servicefilter} > 0) {
        my @filter;
        for my $hostname (keys %{$servicefilter}) {
            for my $description (keys %{$servicefilter->{$hostname}}) {
                my $op = $servicefilter->{$hostname}->{$description} || '=';
                if($op ne '=') {
                    $description =~ s/^(b|w)://gmx;
                    my $full_op = {
                            '=' =>  '=',
                           '!=' => '!=',
                            '~' => '~~',
                           '!~' => '!~',
                        }->{$op} || '~~';
                    if($op eq '~' || $op eq '!~') {
                        $description = Thruk::Utils::convert_wildcards_to_regex($description);
                    }
                    push @filter, { '-and' => { host_name => $hostname, description => { $full_op => $description }}};
                } else {
                    push @filter, { '-and' => { host_name => $hostname, description => $description }};
                }
            }
        }
        if($expand_groups && scalar keys %{$hostgroupfilter} > 0) {
            for my $hostgroupname (keys %{$hostgroupfilter}) {
                push @filter, { host_groups => { '>=' => $hostgroupname } };
            }
        }
        if($expand_groups && scalar keys %{$servicegroupfilter} > 0) {
            for my $servicegroupname (keys %{$servicegroupfilter}) {
                push @filter, { groups => { '>=' => $servicegroupname } };
            }
        }
        my $filter = Thruk::Utils::combine_filter( '-or', \@filter );
        my $data   = $c->{'db'}->get_services(filter => [$filter], extra_columns => [qw/long_plugin_output last_hard_state last_hard_state_change/]);
        $servicedata = Thruk::Utils::array2hash($data, 'host_name', 'description');
    }
    if(!$expand_groups) {
        if(scalar keys %{$hostgroupfilter} > 0) {
            my @filter;
            for my $hostgroupname (keys %{$hostgroupfilter}) {
                push @filter, { name => $hostgroupname };
            }
            my $filter = Thruk::Utils::combine_filter( '-or', \@filter );
            my $data   = $c->{'db'}->get_hostgroups(filter => [$filter], columns => [qw/name num_hosts num_hosts_down num_hosts_pending
                                                                                     num_hosts_unreach num_hosts_up num_services num_services_crit
                                                                                     num_services_ok num_services_pending num_services_unknown
                                                                                     num_services_warn worst_service_state worst_host_state/]);
            $hostgroupdata  = Thruk::Utils::array2hash($data, 'name');
        }
        if(scalar keys %{$servicegroupfilter} > 0) {
            my @filter;
            for my $servicegroupname (keys %{$servicegroupfilter}) {
                push @filter, { name => $servicegroupname };
            }
            my $filter = Thruk::Utils::combine_filter( '-or', \@filter );
            my $data   = $c->{'db'}->get_servicegroups(filter => [$filter], columns => [qw/name num_services num_services_crit
                                                                                           num_services_ok num_services_pending num_services_unknown
                                                                                           num_services_warn worst_service_state/]);
            $servicegroupdata  = Thruk::Utils::array2hash($data, 'name');
        }
    }

    my $livedata = {
        'hosts'         => $hostdata,
        'services'      => $servicedata,
        'hostgroups'    => $hostgroupdata,
        'servicegroups' => $servicegroupdata,
    };

    # calculate group statistics from given hosts / services
    if($expand_groups) {
        $self->recalculate_group_statistics($livedata, 0);
    }

    return($livedata);
}

##########################################################

=head2 recalculate_group_statistics

recalculate group statistics for given hosts / services

=cut
sub recalculate_group_statistics {
    my($self, $livedata, $reset) = @_;

    my $hostdata         = $livedata->{'hosts'};
    my $servicedata      = $livedata->{'services'};
    my $hostgroupdata    = $livedata->{'hostgroups'};
    my $servicegroupdata = $livedata->{'servicegroups'};

    if($reset) {
        # set empty group statistics for requested host/servicegroups
        for my $hostgroupname (keys %{$hostgroupdata}) {
            $hostgroupdata->{$hostgroupname} = Thruk::Utils::Status::summary_set_group_defaults();
        }
        for my $servicegroupname (keys %{$servicegroupdata}) {
            $servicegroupdata->{$servicegroupname} = Thruk::Utils::Status::summary_set_group_defaults();
        }
    }

    # calculate group statistics from given hosts / services
    for my $hostname ( keys %{$hostdata} ) {
        my $host = $hostdata->{$hostname};
        for my $groupname ( @{ $host->{'groups'} } ) {
            next unless $hostgroupdata->{$groupname};
            Thruk::Utils::Status::summary_add_host_stats("", $hostgroupdata->{$groupname}, $host);
        }
    }
    for my $hostname ( keys %{$servicedata} ) {
        for my $description ( keys %{$servicedata->{$hostname}} ) {
            my $service = $servicedata->{$hostname}->{$description};
            for my $groupname ( @{ $service->{'groups'} } ) {
                next unless $servicegroupdata->{$groupname};
                Thruk::Utils::Status::summary_add_service_stats($servicegroupdata->{$groupname}, $service);
            }
            for my $groupname ( @{ $service->{'host_groups'} } ) {
                next unless $hostgroupdata->{$groupname};
                Thruk::Utils::Status::summary_add_service_stats($hostgroupdata->{$groupname}, $service);
            }
        }
    }
    # map keys to the ones we expect
    for my $group (values %{$hostgroupdata}) {
        $group->{num_hosts}         = $group->{'hosts_total'} || 0;
        $group->{num_hosts_down}    = $group->{'hosts_down'};
        $group->{num_hosts_pending} = $group->{'hosts_pending'};
        $group->{num_hosts_unreach} = $group->{'hosts_unreachable'};
        $group->{num_hosts_up}      = $group->{'hosts_up'};
    }
    for my $group (values %{$servicegroupdata}, values %{$hostgroupdata}) {
        $group->{num_services}         = $group->{'services_total'} || 0;
        $group->{num_services_crit}    = $group->{'services_critical'};
        $group->{num_services_ok}      = $group->{'services_ok'};
        $group->{num_services_pending} = $group->{'services_pending'};
        $group->{num_services_unknown} = $group->{'services_unknown'};
        $group->{num_services_warn}    = $group->{'services_warning'};
    }
    return;
}

##########################################################
sub _submit_results_to_core {
    my($self, $c, $results) = @_;
    return unless scalar @{$results} > 0;

    if($c->config->{'Thruk::Plugin::BP'}->{'result_backend'}) {
        return $self->_submit_results_to_core_backend($c, $results);
    }
    elsif($c->config->{'Thruk::Plugin::BP'}->{'spool_dir'}) {
        return $self->_submit_results_to_core_spool($c, $results);
    }
    else {
        # if there is only on backend, use that
        my $peers = $c->{'db'}->get_peers();
        if(scalar @{$peers} == 1) {
            $c->config->{'Thruk::Plugin::BP'}->{'result_backend'} = $peers->[0]->peer_key();
            return $self->_submit_results_to_core_backend($c, $results);
        }
    }
    # log a warning that there is nothing to send result too
    if(!$c->{'no_result_warned'}) {
        _warn("no result_backend set, cannot send results to core. Either set result_backend or spool_dir when having multiple backends.");
        $c->{'no_result_warned'} = 1;
    }
    return;
}

##########################################################
sub _submit_results_to_core_backend {
    my($self, $c, $results) = @_;

    my $name = $c->config->{'Thruk::Plugin::BP'}->{'result_backend'};
    my $peer = $c->{'db'}->get_peer_by_key($name);
    die("no backend found by name ".$name) unless $peer;
    my $pkey = $peer->peer_key();

    for my $id (@{$results}) {
        my $cmds = $self->{'nodes_by_id'}->{$id}->result_to_cmd($self);
        my $options = {
            'command' => 'COMMAND '.join("\n\nCOMMAND ", @{$cmds}),
            'backend' => [ $pkey ],
        };
        $c->{'db'}->send_command( %{$options} );
    }

    return;
}

##########################################################
sub _submit_results_to_core_spool {
    my($self, $c, $results) = @_;

    my $results_str = [];
    for my $id (@{$results}) {
        push @{$results_str}, $self->{'nodes_by_id'}->{$id}->result_to_string($self);
    }

    my $spool = $c->config->{'Thruk::Plugin::BP'}->{'spool_dir'};
    if($spool) {
        die("spool folder does not exist ".$spool.": ".$!) unless -d $spool;
        my $fh = File::Temp->new(
            TEMPLATE => "cXXXXXX",
            DIR      => $spool,
        );
        $fh->unlink_on_destroy(0);
        binmode($fh, ":encoding(UTF-8)");
        print $fh "### Active Check Result File ###\n";
        print $fh sprintf("file_time=%d\n\n",time);
        for my $r (@{$results_str}) {
            print $fh $r,"\n";
        }
        Thruk::Utils::IO::close($fh, $fh->filename);
        chmod(0664, $fh->filename); # make sure the core can read it

        my $file = $fh->filename.'.ok';
        sysopen my $t,$file,O_WRONLY|O_CREAT|O_NONBLOCK|O_NOCTTY
            or croak("Can't create $file : $!");
        Thruk::Utils::IO::close($t, $file);
    }

    return;
}

##########################################################
sub _sync_ack_downtime_status {
    my($self, $c, $results) = @_;
    return unless scalar @{$results} > 0;

    # disabled by configuration?
    if(!defined $c->config->{'Thruk::Plugin::BP'}->{'sync_downtime_ack_state'} || $c->config->{'Thruk::Plugin::BP'}->{'sync_downtime_ack_state'} < 2) {
        return;
    }

    my $peer;
    if($c->config->{'Thruk::Plugin::BP'}->{'result_backend'}) {
        my $b = $c->config->{'Thruk::Plugin::BP'}->{'result_backend'};
        $peer = $c->{'db'}->get_peer_by_key($b) || $c->{'db'}->get_peer_by_name($b);
    }
    else {
        # if there is only on backend, use that
        my $peers = $c->{'db'}->get_peers();
        if(scalar @{$peers} == 1) {
            $peer = $peers->[0];
        }
    }
    # log a warning that there is nothing to send result too
    if(!$c->{'no_result_warned'} && !$peer) {
        _warn("no result_backend set, cannot sync acknowledgement / downtime status to core.");
        $c->{'no_result_warned'} = 1;
        return;
    }
    my $pkey   = $peer->peer_key();
    my $author = "(thruk)";

    # get all downtimes for this bp
    my $downtimes = $c->db->get_downtimes(filter => [{ 'host_custom_variables' => { '=' => 'THRUK_BP_ID '.$self->{'id'}}}, 'author' => $author ], backend => $pkey);
    $downtimes = Thruk::Utils::array2hash($downtimes, "host_name", "service_description");

    my $acks = $c->db->get_comments(filter => [{ 'host_custom_variables' => { '=' => 'THRUK_BP_ID '.$self->{'id'}}}, 'author' => $author ], backend => $pkey);
    $acks = Thruk::Utils::array2hash($acks, "host_name", "service_description");

    my $cmds = [];
    for my $id (@{$results}) {
        my $node = $self->{'nodes_by_id'}->{$id};
        if($node->{'scheduled_downtime_depth'}) {
            my $current_downtime = $downtimes->{$self->{'name'}}->{$node->{'label'}};
            if($current_downtime) {
                # if current downtime expires within the next 30 minutes, renew it
                if($current_downtime->{'end_time'} < time() + (30*60)) {
                    my $cmd = sprintf("[%d] DEL_SVC_DOWNTIME;%d",
                                                time(),
                                                $downtimes->{$self->{'name'}}->{$node->{'label'}}->{'id'},
                                    );
                    push @{$cmds}, $cmd;
                } else {
                    next;
                }
            }
            my $comment = "automatic downtime, all child nodes are in downtime.";
            my $start   = time();
            my $end     = $start + 86400;
            my $cmd = sprintf("[%d] SCHEDULE_SVC_DOWNTIME;%s;%s;%d;%d;1;0;%d;%s;%s",
                                        time(),
                                        $self->{'name'},
                                        $node->{'label'},
                                        $start,
                                        $end,
                                        $end - $start,
                                        $author,
                                        $comment,
                            );
            push @{$cmds}, $cmd;
        } else {
            if($downtimes->{$self->{'name'}}->{$node->{'label'}}) {
                # remove exceeding downtime
                my $cmd = sprintf("[%d] DEL_SVC_DOWNTIME;%d",
                                            time(),
                                            $downtimes->{$self->{'name'}}->{$node->{'label'}}->{'id'},
                                );
                push @{$cmds}, $cmd;
            }
        }

        if($node->{'acknowledged'}) {
            if($acks->{$self->{'name'}}->{$node->{'label'}}) {
                next;
            }
            my $comment = "automatic acknowledgment, all child nodes are acknowledged.";
            my $cmd = sprintf("[%d] ACKNOWLEDGE_SVC_PROBLEM;%s;%s;1;1;0;%s;%s",
                                        time(),
                                        $self->{'name'},
                                        $node->{'label'},
                                        $author,
                                        $comment,
                            );
            push @{$cmds}, $cmd;
        } else {
            if($acks->{$self->{'name'}}->{$node->{'label'}}) {
                # remove exceeding acknowledgement
                my $cmd = sprintf("[%d] REMOVE_SVC_ACKNOWLEDGEMENT;%s;%s",
                                            time(),
                                            $self->{'name'},
                                            $node->{'label'},
                                );
                push @{$cmds}, $cmd;
            }
        }
    }

    if(scalar @{$cmds} > 0) {
        my $options = {
            'command' => 'COMMAND '.join("\n\nCOMMAND ", @{$cmds}),
            'backend' => [ $pkey ],
        };
        $c->{'db'}->send_command( %{$options} );
    }

    return;
}

##########################################################

=head2 TO_JSON

    TO_JSON()

returns data needed to represent this module in json

=cut
sub TO_JSON {
    my($self) = @_;
    my $data = {};
    for my $key (@extra_json_keys, @stateful_keys, @saved_keys) {
        $data->{$key} = $self->{$key};
    }
    $data->{'nodes'} = [];
    for my $n (@{$self->{'nodes'}}) {
        push @{$data->{'nodes'}}, $n->TO_JSON();
    }
    return $data;
}

##########################################################

=head2 FROM_JSON

    FROM_JSON()

creates BP object from json data

=cut
sub FROM_JSON {
    my($self, $c, $json) = @_;
    my $file  = delete $self->{'file'};
    my $nr    = delete $self->{'id'};
    my $nodes = delete $json->{'nodes'} || [];
    for my $key (keys %{$self}) {
        delete $self->{$key};
    }
    for my $key (keys %{$json}) {
        $self->{$key} = $json->{$key};
    }

    $self->set_file($c, $file);
    $self->{'id'} = $nr;
    $self->set_label($c, $json->{'name'});

    return unless $self->{'name'};

    # read in nodes
    for my $n (@{Thruk::Utils::list($nodes)}) {
        my $node = Thruk::BP::Components::Node->new($n);
        $self->add_node($node, 1);
    }

    $self->load_runtime_data();

    for my $n (@{$self->{'nodes'}}) {
        $n->update_parents($self);
    }

    return $self;
}

##########################################################

=head2 get_outgoing_refs

    get_outgoing_refs()

return list of outgoing bp references

=cut
sub get_outgoing_refs {
    my($self, $c) = @_;
    $c->stats->profile(begin => "get_outgoing_refs");

    my $refs = [];
    for my $n (@{$self->{'nodes'}}) {
        if($n->{'bp_ref'}) {
            my $bps = Thruk::BP::Utils::load_bp_data($c, $n->{'bp_ref'}, undef, undef, $n->{'bp_ref_peer'});
            push @{$refs}, $bps->[0] if $bps->[0];
        }
    }

    $c->stats->profile(end => "get_outgoing_refs");
    return $refs;
}

##########################################################

=head2 get_incoming_refs

    get_incoming_refs()

return list of incoming bp references

=cut
sub get_incoming_refs {
    my($self, $c, $bps) = @_;
    $c->stats->profile(begin => "get_incoming_refs");

    my $refs = [];
    for my $bp (@{$bps}) {
        for my $n (@{$bp->{'nodes'}}) {
            if($n->{'bp_ref'} && $n->{'bp_ref'} == $self->{'id'}) {
                push @{$refs}, $bp;
            }
        }
    }

    $c->stats->profile(end => "get_incoming_refs");
    return $refs;
}

##########################################################
# return list of affected backends from given livestatus data
sub _extract_affected_backends {
    my($self, $livedata) = @_;
    my $peers = {};
    for my $hst (values %{$livedata->{'hosts'}}) {
        $peers->{$hst->{'peer_key'}} = 1;
    }
    for my $hst_name (keys %{$livedata->{'services'}}) {
        for my $svc (values %{$livedata->{'services'}->{$hst_name}}) {
            $peers->{$svc->{'peer_key'}} = 1;
        }
    }
    return([sort keys %{$peers}]);
}

##########################################################
# returns true if there are no failed backends and false if there are any
sub _list_failed_backends {
    my($self, $c, $previous_affected, $failed_backends) = @_;
    my $failed = [];
    return $failed unless $previous_affected;
    $failed_backends = {} unless $failed_backends;
    for my $key (@{$previous_affected}) {
        next unless $failed_backends->{$key};
        my $peer = $c->{'db'}->get_peer_by_key($key);
        push @{$failed}, ($peer ? $peer->{'name'} : $key);
    }
    return $failed;
}

##########################################################

1;
