package Thruk::BP::Components::Node;

use strict;
use warnings;
use Thruk::Utils;
use Thruk::BP::Functions;
use Thruk::BP::Utils;
use Thruk::Utils::Filter;
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::BP::Components::Node - Node Class

=head1 DESCRIPTION

Business Process Node

=head1 METHODS

=cut

my @stateful_keys   = qw/status status_text last_check last_state_change short_desc
                       scheduled_downtime_depth acknowledged bp_ref bp_ref_peer/;

##########################################################

=head2 new

return new node

=cut

sub new {
    my ( $class, $data ) = @_;
    my $self = {
        'id'                        => $data->{'id'},
        'label'                     => $data->{'label'},
        'function'                  => '',
        'function_args'             => [],
        'depends'                   => Thruk::Utils::list($data->{'depends'} || []),
        'parents'                   => $data->{'parents'}       || [],
        'host'                      => $data->{'host'}          || '',
        'service'                   => $data->{'service'}       || '',
        'hostgroup'                 => $data->{'hostgroup'}     || '',
        'servicegroup'              => $data->{'servicegroup'}  || '',
        'template'                  => $data->{'template'}      || '',
        'contacts'                  => $data->{'contacts'}      || [],
        'contactgroups'             => $data->{'contactgroups'} || [],
        'notification_period'       => $data->{'notification_period'} || '',
        'max_check_attempts'        => $data->{'max_check_attempts'} || '',
        'event_handler'             => $data->{'event_handler'} || '',
        'host_object_attributes'    => $data->{'host_object_attributes'}    || {},
        'host_name'                 => $data->{'host_name'},
        'service_object_attributes' => $data->{'service_object_attributes'} || {},
        'create_obj'                => $data->{'create_obj'}    || 0,
        'create_obj_ok'             => 1,
        'scheduled_downtime_depth'  => 0,
        'acknowledged'              => 0,
        'testmode'                  => 0,
        'bp_ref'                    => undef,
        'bp_ref_peer'               => undef,
        'filter'                    => $data->{'filter'}      || [],

        'status'                    => $data->{'status'} // 4,
        'status_text'               => $data->{'status_text'} || '',
        'short_desc'                => $data->{'short_desc'}  || '',
        'last_check'                => 0,
        'last_state_change'         => 0,
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
    push @{$self->{'depends'}}, $append->{'id'};
    return;
}

##########################################################

=head2 update_parents

update parents list for all childs

=cut
sub update_parents {
    my($self, $bp) = @_;
    my $id = $self->{'id'};
    for my $d (@{$self->depends($bp)}) {
        if(! grep($id, @{$d->{'parents'}}) ) {
            push @{$d->{'parents'}}, $id;
        }
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
    for my $key (qw/template create_obj notification_period max_check_attempts event_handler contactgroups contacts filter depends function function_args/) {
        $obj->{$key} = $self->{$key} if $self->{$key};
    }

    return $obj;
}

##########################################################

=head2 get_objects_conf

    get_objects_conf($bp)

return objects config

=cut
sub get_objects_conf {
    my($self, $bp) = @_;

    return unless $self->{'create_obj'};

    # first node always creates a host too
    my $obj = {};
    if($self->{'id'} eq 'node1' && $bp->{'create_host_object'}) {
        $obj->{'hosts'}->{$bp->{'name'}} = {
            'host_name'      => $bp->{'name'},
            'alias'          => 'Business Process: '.$self->{'label'},
            'use'            => $bp->{'template'} || 'thruk-bp-template',
            '_THRUK_BP_ID'   => $bp->{'id'},
            '_THRUK_NODE_ID' => $self->{'id'},
        };
        for my $key (qw/notification_period max_check_attempts event_handler/) {
            next unless $bp->{$key};
            $obj->{'hosts'}->{$bp->{'name'}}->{$key} = $bp->{$key};
        }
        for my $key (qw/contacts/) {
            next unless $bp->{$key};
            $obj->{'hosts'}->{$bp->{'name'}}->{$key} = join(',', @{$bp->{$key}});
        }
        for my $key (qw/contactgroups/) {
            next unless $bp->{$key};
            $obj->{'hosts'}->{$bp->{'name'}}->{'contact_groups'} = join(',', @{$bp->{$key}});
        }
        for my $key (sort keys %{$self->{'host_object_attributes'}}) {
            $obj->{'hosts'}->{$bp->{'name'}}->{$key} = $self->{'host_object_attributes'}->{$key};
        }
    }

    $obj->{'services'}->{$bp->{'name'}}->{$self->{'label'}} = {
        'host_name'           => $self->{'host_name'} // $bp->{'name'},
        'service_description' => $self->{'label'},
        'display_name'        => $self->{'label'},
        'use'                 => $self->{'template'} || 'thruk-bp-node-template',
        '_THRUK_BP_ID'        => $bp->{'id'},
        '_THRUK_NODE_ID'      => $self->{'id'},
    };
    for my $key (qw/notification_period max_check_attempts event_handler/) {
        next unless $self->{$key};
        $obj->{'services'}->{$bp->{'name'}}->{$self->{'label'}}->{$key} = $self->{$key};
    }
    for my $key (qw/contacts/) {
        next unless $self->{$key};
        next unless scalar @{$self->{$key}} > 0;
        $obj->{'services'}->{$bp->{'name'}}->{$self->{'label'}}->{$key} = join(',', @{$self->{$key}});
    }
    for my $key (qw/contactgroups/) {
        next unless $self->{$key};
        next unless scalar @{$self->{$key}} > 0;
        $obj->{'services'}->{$bp->{'name'}}->{$self->{'label'}}->{'contact_groups'} = join(',', @{$self->{$key}});
    }
    for my $key (sort keys %{$self->{'service_object_attributes'}}) {
        $obj->{'services'}->{$bp->{'name'}}->{$self->{'label'}}->{$key} = $self->{'service_object_attributes'}->{$key};
    }

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
    $c->stats->profile(begin => "update_status bp-".$bp->{id}."-".$self->{'id'});

    return unless $self->{'function'};
    my $function = \&{'Thruk::BP::Functions::'.$self->{'function'}};

    eval {
        # input filter
        my $filter_args = {
            type     => 'input',
            bp       => $bp,
            node     => $self,
            livedata => $livedata,
        };
        if(scalar @{$bp->filter()} > 0 || scalar @{$self->{'filter'}} > 0) {
            my $need_update = delete $bp->{'need_update'};
            $filter_args = Thruk::Utils::dclone($filter_args);
            $bp->{'need_update'} = $need_update;
            $filter_args->{'bp'}->{'need_update'} = $need_update;
            for my $f (sort @{$bp->filter()}) {
                $filter_args->{'scope'} = 'global';
                _filter($c, $f, $filter_args);
            }
            for my $f (sort @{$self->{'filter'}}) {
                $filter_args->{'scope'} = 'node';
                _filter($c, $f, $filter_args);
            }
            $filter_args->{'bp'}->recalculate_group_statistics($filter_args->{'livedata'}, 1);
        }

        my($status, $short_desc, $status_text, $extra) = &{$function}($c,
                                                                      $filter_args->{'bp'},
                                                                      $filter_args->{'node'},
                                                                      $filter_args->{'node'}->{'function_args'},
                                                                      $filter_args->{'livedata'},
                                                                    );
        # output filter
        $filter_args->{'type'}          = 'output';
        $filter_args->{'status'}        = $status;
        $filter_args->{'status_text'}   = $status_text;
        $filter_args->{'short_desc'}    = $short_desc;
        $filter_args->{'extra'}         = $extra;
        for my $f (sort @{$bp->filter()}) {
            $filter_args->{'scope'} = 'global';
            _filter($c, $f, $filter_args);
        }
        for my $f (sort @{$self->{'filter'}}) {
            $filter_args->{'scope'} = 'node';
            _filter($c, $f, $filter_args);
        }
        $self->set_status($filter_args->{'status'}, ($filter_args->{'status_text'} || $filter_args->{'short_desc'}), $bp, $filter_args->{'extra'});
        $self->{'short_desc'} = $filter_args->{'short_desc'};
    };
    if($@) {
        $self->set_status(3, 'Internal Error: '.$@, $bp);
        $bp->{'failed'} = $@;
    }

    $c->stats->profile(end => "update_status bp-".$bp->{id}."-".$self->{'id'});

    # indicate a new result if we are linked to an object
    return 1 if $self->{'create_obj'};

    return;
}

##########################################################

=head2 set_status

    set_status($state, $text, $bp, $extra)

extra: contains extra attributes

set status of node

=cut
sub set_status {
    my($self, $state, $text, $bp, $extra) = @_;

    my $last_state    = $self->{'status'}                   // 4;
    my $last_ack      = $self->{'acknowledged'}             // 0;
    my $last_downtime = $self->{'scheduled_downtime_depth'} ? 1 : 0;

    # update last check time
    my $now = time();
    $self->{'last_check'} = $now;

    $self->{'status'}      = $state;
    $self->{'status_text'} = $text;

    # update some extra attributes
    my %custom_vars;
    $self->{'bp_ref'}      = undef;
    $self->{'bp_ref_peer'} = undef;
    if($extra && $extra->{'host_custom_variable_names'} && $extra->{'host_custom_variable_values'}) {
        @custom_vars{@{$extra->{'host_custom_variable_names'}}} = @{$extra->{'host_custom_variable_values'}};
        $self->{'bp_ref'}      = $custom_vars{'THRUK_BP_ID'};
        $self->{'bp_ref_peer'} = $extra->{'peer_key'};
    }
    for my $key (qw/last_check last_state_change scheduled_downtime_depth acknowledged testmode/) {
        $self->{$key} = $extra->{$key} if defined $extra->{$key};
    }
    $self->{'scheduled_downtime_depth'} = $self->{'scheduled_downtime_depth'} ? 1 : 0; # should be 0/1 only

    if($last_state != $state || $last_ack != $self->{'acknowledged'} || $last_downtime != $self->{'scheduled_downtime_depth'}) {
        $self->{'last_state_change'} = $now;
        # put parents on update list
        if($bp) {
            for my $p (@{$self->parents($bp)}) {
                $bp->{'need_update'}->{$p->{'id'}} = 1;
            }
        }
    }

    # if this node has no parents, use this state for the complete bp
    if($bp and scalar @{$self->{'parents'}} == 0) {
        my $text = $self->{'status_text'};
        if(scalar @{$self->{'depends'}} > 0 and $self->{'function'} ne 'custom') {
            # try a lucky guess on our child nodes and search for those which have our status
            my $nodes = [];
            for my $n (@{$self->depends($bp)}) {
                if($n->{'status'} == $self->{'status'} && $n->{'acknowledged'} == $self->{'acknowledged'} && $n->{'scheduled_downtime_depth'} == $self->{'scheduled_downtime_depth'}) {
                    push @{$nodes}, $n;
                }
            }
            # found some
            if($self->{'status'} == 0) {
                $text = 'everything is fine';
            }
            elsif(scalar @{$nodes} > 0) {
                my $first = $nodes->[0];
                $text = Thruk::BP::Utils::join_labels($nodes).' '.lc(Thruk::Utils::Filter::state2text($first->{'status'}));
            }
            $text = Thruk::Utils::Filter::state2text($self->{'status'}).' - '.$text;
        }
        $text  = $extra->{'output'} if $extra->{'output'};
        $text .= "\n".$extra->{'long_output'} if $extra->{'long_output'};
        $bp->set_status($self->{'status'}, $text);
    }
    return;
}

##########################################################
sub _set_function {
    my($self, $data) = @_;
    if($data->{'function'}) {
        if(ref $data->{'function'} eq 'ARRAY') {
            $self->{'function'}      = shift(@{$data->{'function'}});
            $self->{'function_args'} = $data->{'function'};
        } else {
            my($fname, $fargs) = $data->{'function'} =~ m|^(\w+)\((.*)\)|mx;
            $self->{'function'}      = lc($fname || $data->{'function'} || '');
            $self->{'function_args'} = Thruk::BP::Utils::clean_function_args($fargs);
        }
    }
    $self->{'function_args'} = $data->{'function_args'} || $self->{'function_args'} || [];
    my $fname    = $self->{'function'} || 'none';
    my $function = \&{'Thruk::BP::Functions::'.$fname};
    if(!defined &{$function}) {
        $self->set_status(3, 'Unknown function: '.$fname);
    }
    if($fname eq 'status') {
        $self->{'host'}                 = $self->{'function_args'}->[0] || '';
        $self->{'service'}              = $self->{'function_args'}->[1] || '';
        $self->{'template'}             = '';
        $self->{'contacts'}             = [];
        $self->{'contactgroups'}        = [];
        $self->{'notification_period'}  = '';
        $self->{'max_check_attempts'}   = '';
        $self->{'event_handler'}        = '';
        # fix operator
        if($self->{'service'}) {
            my $op = $self->{'function_args'}->[2] // '=';
            if($op eq '=' && Thruk::Utils::looks_like_regex($self->{'service'})) {
                $op = "~";
            }
            elsif($op eq '!=' && Thruk::Utils::looks_like_regex($self->{'service'})) {
                $op = "!~";
            }
            if($op eq "~" || $op eq '!~') {
                $self->{'function_args'}->[1] = Thruk::Utils::convert_wildcards_to_regex($self->{'function_args'}->[1]);
                $self->{'service'} = $self->{'function_args'}->[1];
            }
            $self->{'function_args'}->[2] = $op;
        }
    }
    if($fname eq 'groupstatus') {
        if($self->{'function_args'}->[0] eq 'hostgroup') {
            $self->{'hostgroup'}    = $self->{'function_args'}->[1] || '';
        } else {
            $self->{'servicegroup'} = $self->{'function_args'}->[1] || '';
        }
        $self->{'template'} = '';
    }
    return;
}

##########################################################

=head2 result_to_cmd

    result_to_cmd($bp, [$force_service])

returns command represention of result. Useful for transmitting result by
livestatus command.

=cut
sub result_to_cmd {
    my($self, $bp, $force_service) = @_;
    my $firstnode = ($self->{'id'} eq 'node1' && !$force_service) ? 1 : 0;

    my $cmds = [];
    my($output, $status, $string) = $self->_get_status($bp, $firstnode);

    if($firstnode) {
        my $cmd = sprintf("[%d] PROCESS_HOST_CHECK_RESULT;%s;%d;%s",
                                    time(),
                                    $bp->{'name'},
                                    $status,
                                    $output,
                        );
        push @{$cmds}, $cmd;

        # submit result for host & service
        push @{$cmds}, @{$self->result_to_cmd($bp, 1)};
    }
    else {
        my $cmd = sprintf("[%d] PROCESS_SERVICE_CHECK_RESULT;%s;%s;%d;%s",
                                    time(),
                                    ($self->{'host_name'} // $bp->{'name'}),
                                    $self->{'label'},
                                    $status,
                                    $output,
                        );
        return([$cmd]);
    }
    return($cmds);
}

##########################################################

=head2 result_to_string

    result_to_string($bp, [$force_service])

returns string represention of result. Useful for transmitting into a checkresults
spool folder.

=cut
sub result_to_string {
    my($self, $bp, $force_service) = @_;
    my $firstnode = ($self->{'id'} eq 'node1' && !$force_service) ? 1 : 0;

    my($output, $status, $string) = $self->_get_status($bp, $firstnode);

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
        $string .= "\n\n".$self->result_to_string($bp, 1);
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
sub _get_status {
    my($self, $bp, $firstnode) = @_;
    my $string = "";
    my $status    = $self->{'status'};
    my $output    = '';
    if($firstnode) {
        $string .= "### Nagios Host Check Result ###\n";
        # host status is ok unless there were errors with the bp itself
        $status = 0;
        $output = sprintf('OK - business process calculation of %d nodes complete in %.3fs|runtime=%.3fs', scalar @{$bp->{'nodes'}}, $bp->{'time'}, $bp->{'time'});
    } else {
        if($status == 4) { $status = 0 }
        $string .= "### Nagios Service Check Result ###\n";
        $output = $self->{'status_text'} || $self->{'short_desc'};
        # override status text of first node to be the bps status itself
        $output = $bp->{'status_text'} if $self->{'id'} eq 'node1';
    }
    $string .= sprintf "# Time: %s\n",scalar localtime time();
    $string .= sprintf "host_name=%s\n", ($self->{'host_name'} // $bp->{'name'});
    if(!$firstnode) {
        $string .= sprintf "service_description=%s\n", $self->{'label'};
    }
    # remove trailing newlines and quote the remaining ones
    $output =~ s/[\r\n]*$//mxo;
    $output =~ s/\n/\\n/gmxo;

    return($output, $status, $string);
}

##########################################################

=head2 depends

    depends()

returns list of depending nodes

=cut
sub depends {
    my($self, $bp) = @_;
    my $depends = [];
    for my $d (@{$self->{'depends'}}) {
        push @{$depends}, $bp->{'nodes_by_id'}->{$d} if $bp->{'nodes_by_id'}->{$d};
    }
    return($depends);
}

##########################################################

=head2 parents

    parents()

returns list of parent nodes

=cut

sub parents {
    my($self, $bp) = @_;
    my $parents = [];
    for my $p (@{$self->{'parents'}}) {
        push @{$parents}, $bp->{'nodes_by_id'}->{$p} if $bp->{'nodes_by_id'}->{$p};
    }
    return($parents);
}

##########################################################
# runs filter function
sub _filter {
    my($c, $fname, $args) = @_;

    $c->stash->{'bp_custom_filter'} = Thruk::BP::Utils::get_custom_filter($c) unless defined $c->stash->{'bp_custom_filter'};
    my $f;
    for my $tmp (@{$c->stash->{'bp_custom_filter'}}) {
        if($tmp->{'function'} eq $fname) {
            $f = $tmp;
            last;
        }
    }
    if(!$f) {
        _info("custom filter $fname not found");
        return;
    }
    eval {
        do($f->{'file'});
        if($@) {
            _info("internal error while loading filter file ".$f->{'file'}.": ".$@);
        }
        ## no critic
        eval($fname.'($c, $args);');
        ## use critic
        if($@) {
            _info("internal error in custom filter $fname: $@");
        }
    };
    if($@) {
        _info("internal error in custom filter $fname: $@");
    }

    return;
}

##########################################################

1;
