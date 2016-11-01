package Thruk::BP::Components::BP;

use strict;
use warnings;
use Data::Dumper;
use Carp;
use File::Temp;
use File::Copy qw/move/;
use Fcntl qw/:DEFAULT/;
use Scalar::Util qw/weaken isweak/;
use Thruk::Utils;
use Thruk::Utils::IO;
use Thruk::BP::Components::Node;
use Time::HiRes qw/gettimeofday tv_interval/;

=head1 NAME

Thruk::BP::Components::Node - BP Class

=head1 DESCRIPTION

Business Process

=head1 METHODS

=cut

my @extra_json_keys = qw/id/;
my @stateful_keys   = qw/status status_text last_check last_state_change time/;
my @saved_keys      = qw/name template rankDir state_type/;

##########################################################

=head2 new

return new business process

=cut

sub new {
    my ( $class, $c, $file, $bpdata, $editmode ) = @_;

    my $self = {
        'id'                => undef,
        'editmode'          => $editmode,
        'name'              => undef,
        'template'          => $bpdata->{'template'} || '',
        'nodes'             => [],
        'nodes_by_id'       => {},
        'nodes_by_name'     => {},
        'need_update'       => {},
        'need_save'         => 0,
        'file'              => undef,
        'datafile'          => undef,
        'editfile'          => undef,

        'time'              => 0,
        'status'            => 4,
        'status_text'       => 'not yet checked',
        'last_check'        => 0,
        'last_state_change' => 0,
        'rankDir'           => 'TB',
        'state_type'        => 'both',

        'exported_nodes'    => {},
        'testmode'          => 0,
        'draft'             => 0,
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

    $self->_resolve_nodes();
    $self->load_runtime_data();

    $self->save() if $self->{'need_save'};

    # avoid circular refs
    for my $n (@{$self->{'nodes'}}) {
        weaken($self->{'nodes_by_id'}->{$n->{'id'}})      unless isweak($self->{'nodes_by_id'}->{$n->{'id'}});
        weaken($self->{'nodes_by_name'}->{$n->{'label'}}) unless isweak($self->{'nodes_by_name'}->{$n->{'label'}});
    }

    return $self;
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

    my $t0 = [gettimeofday];

    $type = 0 unless defined $type;
    my $last_state = $self->{'status'};

    my $results = [];
    my($livedata);
    if($type == 0) {
        $livedata = $self->bulk_fetch_live_data($c);
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
    $self->_submit_results_to_core($c, $results);

    # save runtime
    $self->{'time'} = tv_interval($t0);

    # store runtime data
    $self->save_runtime();

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
          create_obj                => $n->{'create_obj'} ? JSON::XS::true : JSON::XS::false,
          create_obj_ok             => $n->{'create_obj_ok'} ? JSON::XS::true : JSON::XS::false,
          status                    => $n->{'status'},
          status_text               => $n->{'status_text'},
          short_desc                => $n->{'short_desc'},
          last_check                => $n->{'last_check'} ? Thruk::Utils::Filter::date_format($c, $n->{'last_check'}) : 'never',
          duration                  => $n->{'last_state_change'} ? Thruk::Utils::Filter::duration(time() - $n->{'last_state_change'}) : '',
          acknowledged              => $n->{'acknowledged'}."",
          scheduled_downtime_depth  => $n->{'scheduled_downtime_depth'}."",
          depends                   => $n->depends_list,
          func                      => $n->{'function'},
          func_args                 => $n->{'function_args'},
          contacts                  => $n->{'contacts'},
          contactgroups             => $n->{'contactgroups'},
          notification_period       => $n->{'notification_period'},
          event_handler             => $n->{'event_handler'},
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
    for my $p (@{$node->{'parents'}}) {
        my @depends;
        for my $d (@{$p->{'depends'}}) {
            push @depends, $d unless $d->{'id'} eq $node_id;
        }
        $p->{'depends'} = \@depends;
    }

    for my $d (@{$node->{'depends'}}) {
        my @parents;
        for my $p (@{$d->{'parents'}}) {
            push @parents, $p unless $p->{'id'} eq $node_id;
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
# replace list of node names/ids with references
sub _resolve_nodes {
    my($self) = @_;

    for my $node (@{$self->{'nodes'}}) {
        # make sure we have an id now
        if(!$node->{'id'}) {
            $node->set_id($self->make_new_node_id());
            $self->{'nodes_by_id'}->{$node->{'id'}} = $node;
        }
        $node->resolve_depends($self);
    }

    return;
}

##########################################################

=head2 remove

remove business process data to file

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
        local $ENV{REMOTE_USER} = $c->stash->{'remote_user'};
        local $SIG{CHLD}        = 'DEFAULT';
        system($c->config->{'Thruk::Plugin::BP'}->{'pre_save_cmd'}, 'pre', $self->{'file'});
        if($? == -1) {
            Thruk::Utils::set_message( $c, 'fail_message', 'pre save hook failed: '.$?.': '.$! );
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
        local $ENV{REMOTE_USER} = $c->stash->{'remote_user'};
        local $SIG{CHLD}        = 'DEFAULT';
        system($c->config->{'Thruk::Plugin::BP'}->{'post_save_cmd'}, 'post', $self->{'file'});
        if($? == -1) {
            Thruk::Utils::set_message( $c, 'fail_message', 'post save hook failed: '.$?.': '.$! );
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

    Thruk::Utils::IO::json_lock_store($self->{'editfile'}, $obj, 1);
    $self->{'need_save'} = 0;

    return 1;
}

##########################################################

=head2 get_objects_conf

return object config

=cut
sub get_objects_conf {
    my ( $self ) = @_;
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
    my($self, $c) = @_;

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
                $servicefilter->{$n->{'host'}}->{$n->{'service'}} = 1;
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
    if(scalar keys %{$hostfilter} > 0) {
        my @filter;
        for my $hostname (keys %{$hostfilter}) {
            push @filter, { name => $hostname };
        }
        my $filter = Thruk::Utils::combine_filter( '-or', \@filter );
        my $data   = $c->{'db'}->get_hosts(filter => [$filter], extra_columns => [qw/last_hard_state last_hard_state_change/]);
        $hostdata  = Thruk::Utils::array2hash($data, 'name');
    }
    if(scalar keys %{$servicefilter} > 0) {
        my @filter;
        for my $hostname (keys %{$servicefilter}) {
            for my $description (keys %{$servicefilter->{$hostname}}) {
                if($self->looks_like_regex($description)) {
                    $description =~ s/^(b|w)://gmx;
                    push @filter, { host_name => $hostname, description => { '~~' => $description }};
                } else {
                    push @filter, { host_name => $hostname, description => $description };
                }
            }
        }
        my $filter = Thruk::Utils::combine_filter( '-or', \@filter );
        my $data   = $c->{'db'}->get_services(filter => [$filter], extra_columns => [qw/last_hard_state last_hard_state_change/]);
        $servicedata = Thruk::Utils::array2hash($data, 'host_name', 'description');
    }
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

    return({
        'hosts'         => $hostdata,
        'services'      => $servicedata,
        'hostgroups'    => $hostgroupdata,
        'servicegroups' => $servicegroupdata,
    });
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

=head2 looks_like_regex

    looks_like_regex($str)

returns true if $string looks like a regular expression

=cut
sub looks_like_regex {
    my($self, $str) = @_;
    if($str =~ m%[\^\|\*\{\}\[\]]%gmx) {
        return(1);
    }
    return;
}

##########################################################


=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
