package Thruk::BP::Components::Node;

use strict;
use warnings;
use Scalar::Util qw/weaken isweak/;
use Thruk::Utils;
use Thruk::BP::Functions;
use Thruk::BP::Utils;

=head1 NAME

Thruk::BP::Components::Node - Node Class

=head1 DESCRIPTION

Business Process Node

=head1 METHODS

=cut

my @stateful_keys   = qw/status status_text last_check last_state_change short_desc
                       scheduled_downtime_depth acknowledged/;

##########################################################

=head2 new

return new node

=cut

sub new {
    my ( $class, $data ) = @_;
    my $self = {
        'id'                => $data->{'id'},
        'label'             => $data->{'label'},
        'function'          => '',
        'function_ref'      => undef,
        'function_args'     => [],
        'depends'           => Thruk::Utils::list($data->{'depends'} || []),
        'parents'           => $data->{'parents'}       || [],
        'host'              => $data->{'host'}          || '',
        'service'           => $data->{'service'}       || '',
        'hostgroup'         => $data->{'hostgroup'}     || '',
        'servicegroup'      => $data->{'servicegroup'}  || '',
        'template'          => $data->{'template'}      || '',
        'create_obj'        => $data->{'create_obj'}    || 0,
        'create_obj_ok'     => 1,
        'scheduled_downtime_depth' => 0,
        'acknowledged'      => 0,
        'testmode'          => 0,

        'status'            => defined $data->{'status'} ? $data->{'status'} : 4,
        'status_text'       => $data->{'status_text'} || '',
        'short_desc'        => $data->{'short_desc'}  || '',
        'last_check'        => 0,
        'last_state_change' => 0,
    };
    bless $self, $class;

    # first node is always linked
    $self->{'create_obj'} = 1 if($self->{'id'} and $self->{'id'} eq 'node1');

    $self->_set_function($data);

    return $self;
}

##########################################################

=head2 load_runtime_data

update runtime data

=cut
sub load_runtime_data {
    my($self, $data) = @_;
    # return if there is a a newer result already
    if($self->{'last_state_change'} && $data->{'last_state_change'} && $self->{'last_state_change'} >= $data->{'last_state_change'}) {
        return;
    }
    for my $key (@stateful_keys) {
        $self->{$key} = $data->{$key} if defined $data->{$key};
    }
    return;
}

##########################################################

=head2 set_id

set new id for this node

=cut
sub set_id {
    my($self, $id) = @_;
    $self->{'id'} = $id;
    return;
}

##########################################################

=head2 append_child

append new child noew

=cut
sub append_child {
    my($self, $append) = @_;
    push @{$self->{'depends'}}, $append;
    return;
}

##########################################################

=head2 resolve_depends

resolve dependend nodes into objects

=cut
sub resolve_depends {
    my($self, $bp, $depends) = @_;

    # set or update?
    if(!$depends) {
        $depends = $self->{'depends'};
    } else {
        # remove node from the parent list of its children first
        for my $d (@{$self->{'depends'}}) {
            my @new_parents;
            for my $p (@{$d->{'parents'}}) {
                push @new_parents, $p unless $p->{'id'} eq $self->{'id'};
            }
            $d->{'parents'} = \@new_parents;
        }
    }

    my $new_depends = [];
    for my $d (@{$depends}) {
        # not a reference yet?
        if(ref $d eq '') {
            my $dn = $bp->{'nodes_by_id'}->{$d} || $bp->{'nodes_by_name'}->{$d};
            if(!$dn) {
                # fake node required
                $dn = Thruk::BP::Components::Node->new({
                                    'id'       => $bp->make_new_node_id(),
                                    'label'    => $d,
                                    'function' => 'Fixed("Unknown")',
                });
                $bp->add_node($dn);
            }
            $d = $dn;
        }
        push @{$new_depends}, $d;

        # add parent connection
        push @{$d->{'parents'}}, $self;
    }
    $self->{'depends'} = $new_depends;

    # avoid circular refs
    for(my $x = 0; $x < @{$self->{'depends'}}; $x++) {
        weaken($self->{'depends'}->[$x]) unless isweak($self->{'depends'}->[$x]);
    }
    for(my $x = 0; $x < @{$self->{'parents'}}; $x++) {
        weaken($self->{'parents'}->[$x]) unless isweak($self->{'parents'}->[$x]);
    }

    return;
}


##########################################################

=head2 get_stateful_data

return data which needs to be statefully stored

=cut
sub get_stateful_data {
    my($self) = @_;
    my $data = {};
    for my $key (@stateful_keys) {
        $data->{$key} = $self->{$key};
    }
    return $data;
}

##########################################################

=head2 get_save_obj

get object data which needs to be saved

=cut
sub get_save_obj {
    my ( $self ) = @_;

    my $obj = {
        id     => $self->{'id'},
        label  => $self->{'label'},
    };

    # save this keys
    for my $key (qw/template create_obj/) {
        $obj->{$key} = $self->{$key} if $self->{$key};
    }

    # function
    if($self->{'function'}) {
        $obj->{'function'} = sprintf("%s(%s)", $self->{'function'}, Thruk::BP::Utils::join_args($self->{'function_args'}));
    }

    # depends
    $obj->{'depends'} = [] if scalar @{$self->{'depends'}} > 0;
    for my $d (@{$self->{'depends'}}) {
        push @{$obj->{'depends'}}, $d->{'id'};
    }
    return $obj;
}

##########################################################

=head2 get_objects_conf

return objects config

=cut
sub get_objects_conf {
    my ( $self, $bp ) = @_;

    return unless $self->{'create_obj'};

    # first node always creates a host too
    my $obj = {};
    if($self->{'id'} eq 'node1') {
        $obj->{'hosts'}->{$bp->{'name'}} = {
            'host_name'      => $bp->{'name'},
            'alias'          => 'Business Process: '.$self->{'label'},
            'use'            => $self->{'template'} || 'thruk-bp-template',
            '_THRUK_BP_ID'   => $bp->{'id'},
            '_THRUK_NODE_ID' => $self->{'id'},
        };
    }

    $obj->{'services'}->{$bp->{'name'}}->{$self->{'label'}} = {
        'host_name'           => $bp->{'name'},
        'service_description' => $self->{'label'},
        'display_name'        => $self->{'label'},
        'use'                 => $self->{'template'} || 'thruk-bp-node-template',
        '_THRUK_BP_ID'        => $bp->{'id'},
        '_THRUK_NODE_ID'      => $self->{'id'},
    };

    return($obj);
}

##########################################################

=head2 update_status

    update_status($c, $bp, [$livedata], [$type])

type:
    0 / undef:      update always
    1:              only recalculate

update status of node

=cut
sub update_status {
    my($self, $c, $bp, $livedata, $type) = @_;
    $type = 0 unless defined $type;
    delete $bp->{'need_update'}->{$self->{'id'}};

    return if $type == 1 and $self->{'function'} eq 'status';

    return unless $self->{'function_ref'};
    my $function = $self->{'function_ref'};
    eval {
        my($status, $short_desc, $status_text, $extra) = &$function($c,
                                                                    $bp,
                                                                    $self,
                                                                    $self->{'function_args'},
                                                                    $livedata,
                                                                    );
        $self->set_status($status, ($status_text || $short_desc), $bp, $extra);
        $self->{'short_desc'} = $short_desc;
    };
    if($@) {
        $self->set_status(3, 'Internal Error: '.$@, $bp);
    }

    # create result if we are linked to an object
    my $result;
    if($self->{'create_obj'}) {
        $result = $self->_result_to_string($bp);
    }

    return $result;
}

##########################################################

=head2 set_status

    set_status($state, $text, $bp, $extra)

extra: contains extra attributes

set status of node

=cut
sub set_status {
    my($self, $state, $text, $bp, $extra) = @_;

    my $last_state = $self->{'status'};

    # update last check time
    my $now = time();
    $self->{'last_check'} = $now;

    $self->{'status'}      = $state;
    $self->{'status_text'} = $text;

    if($last_state != $state) {
        $self->{'last_state_change'} = $now;
        # put parents on update list
        if($bp) {
            for my $p (@{$self->{'parents'}}) {
                $bp->{'need_update'}->{$p->{'id'}} = $p;
            }
        }
    }

    # update some extra attributes
    for my $key (qw/last_check last_state_change scheduled_downtime_depth acknowledged testmode/) {
        $self->{$key} = $extra->{$key} if defined $extra->{$key};
    }

    # if this node has no parents, use this state for the complete bp
    if($bp and scalar @{$self->{'parents'}} == 0) {
        my $text = $self->{'status_text'};
        if(scalar @{$self->{'depends'}} > 0) {
            my $sum = Thruk::BP::Functions::_get_nodes_grouped_by_state($self, $bp);
            if($sum->{'3'}) {
                $text = Thruk::BP::Utils::join_labels($sum->{'3'}).' unknown';
            }
            elsif($sum->{'2'}) {
                $text = Thruk::BP::Utils::join_labels($sum->{'2'}).' failed';
            }
            elsif($sum->{'1'}) {
                $text = Thruk::BP::Utils::join_labels($sum->{'1'}).' warning';
            }
            else {
                $text = 'everything is fine';
            }
            $text = Thruk::BP::Utils::state2text($self->{'status'}).' - '.$text;
        }
        $bp->set_status($self->{'status'}, $text);
    }
    return;
}

##########################################################
sub _set_function {
    my($self, $data) = @_;
    if($data->{'function'}) {
        my($fname, $fargs) = $data->{'function'} =~ m|^(\w+)\((.*)\)|mx;
        $fname = lc $fname;
        my $function = \&{'Thruk::BP::Functions::'.$fname};
        if(!defined &$function) {
            $self->set_status(3, 'Unknown function: '.($fname || $data->{'function'}));
        } else {
            $self->{'function_args'} = Thruk::BP::Utils::clean_function_args($fargs);
            $self->{'function_ref'}  = $function;
            $self->{'function'}      = $fname;
        }
    }
    if($self->{'function'} eq 'status') {
        $self->{'host'}       = $self->{'function_args'}->[0] || '';
        $self->{'service'}    = $self->{'function_args'}->[1] || '';
        $self->{'template'}   = '';
        $self->{'create_obj'} = 0 unless(defined $self->{'id'} and $self->{'id'} eq 'node1');
    }
    if($self->{'function'} eq 'groupstatus') {
        if($self->{'function_args'}->[0] eq 'hostgroup') {
            $self->{'hostgroup'}    = $self->{'function_args'}->[1] || '';
        } else {
            $self->{'servicegroup'} = $self->{'function_args'}->[1] || '';
        }
        $self->{'template'}    = '';
        $self->{'create_obj'}  = 0 unless(defined $self->{'id'} and $self->{'id'} eq 'node1');
    }
    return;
}

##########################################################
sub _result_to_string {
    my($self, $bp, $force_service) = @_;
    my $string = "";
    my $firstnode = ($self->{'id'} eq 'node1' && !$force_service) ? 1 : 0;
    my $status    = $self->{'status'};
    my $output    = '';
    if($firstnode) {
        $string .= "### Nagios Host Check Result ###\n";
        # host status is ok unless there were errors with the bp itself
        $status = 0;
        $output = sprintf('OK - business process calculation of %d nodes complete in %.3fs|runtime=%.3fs', scalar @{$bp->{'nodes'}}, $bp->{'time'}, $bp->{'time'});
    } else {
        if($status == 4) { $status = 0 };
        $string .= "### Nagios Service Check Result ###\n";
        $output = $self->{'status_text'} || $self->{'short_desc'};
    }
    $string .= sprintf "# Time: %s\n",scalar localtime time();
    $string .= sprintf "host_name=%s\n", $bp->{'name'};
    if(!$firstnode) {
        $string .= sprintf "service_description=%s\n", $self->{'label'};
    }
    # remove trailing newlines and quote the remaining ones
    $output =~ s/[\r\n]*$//mxo;
    $output =~ s/\n/\\n/gmxo;

    $string .= sprintf "check_type=%d\n",       1; # passive
    $string .= sprintf "check_options=%d\n",    0; # no options
    $string .= sprintf "scheduled_check=%d\n",  0; # not scheduled
    $string .= sprintf "latency=%f\n",          0;
    $string .= sprintf "start_time=%f\n",       $self->{'last_check'};
    $string .= sprintf "finish_time=%f\n",      $self->{'last_check'};
    $string .= sprintf "early_timeout=%d\n",    0;
    $string .= sprintf "exited_ok=%d\n",        1;
    $string .= sprintf "return_code=%d\n",      $status;
    $string .= sprintf "output=%s\n",           $output;

    if($firstnode) {
        # submit result for host & service
        $string .= "\n\n".$self->_result_to_string($bp, 1);
    }
    return $string;
}

##########################################################

=head2 TO_JSON

    TO_JSON()

returns data needed to represent this module in json

=cut
sub TO_JSON {
    my($self) = @_;
    my $data = $self->get_save_obj();
    for my $key (@stateful_keys) {
        $data->{$key} = $self->{$key};
    }
    return $data;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2013, <sven.nierlein@consol.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
