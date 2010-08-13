package Thruk::Controller::statusmap;

use strict;
use warnings;
use Carp;
use JSON::XS;
use Data::Dumper;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::statusmap - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

# enable statusmap if this plugin is loaded
Thruk->config->{'use_feature_statusmap'} = 1;

######################################

=head2 statusmap_cgi

page: /thruk/cgi-bin/statusmap.cgi

=cut
sub statusmap_cgi : Path('/thruk/cgi-bin/statusmap.cgi') {
    my ( $self, $c ) = @_;
    return $c->detach('/statusmap/index');
}


##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    $c->stash->{type}    = $c->request->parameters->{'type'}    || 'table';
    $c->stash->{groupby} = $c->request->parameters->{'groupby'} || 'address';
    $c->stash->{host}    = $c->request->parameters->{'host'}    || 'rootid';
    $c->stash->{detail}  = $c->request->parameters->{'detail'}  || '0';
    if($c->stash->{host} eq 'all') {
        $c->stash->{host} = 'rootid';
    }

    $self->{'all_nodes'} = {};

    my $hosts = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts') ]);

    # do we need servicegroups?
    if($c->stash->{groupby} eq 'servicegroup') {
        my $new_hosts;
        my $servicegroups = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), groups => { '!=' => undef }], columns => [qw/host_name groups/]);
        my $servicegroupsbyhost = {};
        if(defined $servicegroups) {
            for my $data (@{$servicegroups}) {
                for my $group ( @{$data->{groups}}) {
                    $servicegroupsbyhost->{$data->{'host_name'}}->{$group} = 1;
                }
            }
            for my $data (@{$hosts}) {
                $data->{'servicegroups'} = join(',', keys %{$servicegroupsbyhost->{$data->{'name'}}});
                push @{$new_hosts}, $data;
            }
        }
        $hosts = $new_hosts;
    }

    my $json;
    # oder by parents
    if($c->stash->{groupby} eq 'parent') {
        $json = $self->_get_hosts_by_parents($c, $hosts);
        $c->stash->{nodename} = 'Host';
    }
    # order by address
    elsif($c->stash->{groupby} eq 'address') {
        $json = $self->_get_hosts_by_split_attribute($c, $hosts, 'address', '.', 0);
        $c->stash->{nodename} = 'Network';
    }
    # order by domain
    elsif($c->stash->{groupby} eq 'domain') {
        $json = $self->_get_hosts_by_split_attribute($c, $hosts, 'name', '.', 1);
        $c->stash->{nodename} = 'Domain';
    }
    # order by hostgroups
    elsif($c->stash->{groupby} eq 'hostgroup') {
        $json = $self->_get_hosts_by_attribute($c, $hosts, 'groups');
        $c->stash->{nodename} = 'Hostgroup';
    }
    # order by servicegroups
    elsif($c->stash->{groupby} eq 'servicegroup') {
        $json = $self->_get_hosts_by_attribute($c, $hosts, 'servicegroups');
        $c->stash->{nodename} = 'Servicegroup';
    }
    else {
        confess("unknown groupby option: ".$c->stash->{groupby});
    }

    # does our root id exist?
    if(!defined $self->{'all_nodes'}->{$c->stash->{host}}) {
        $c->stash->{host} = 'rootid';
    }

    #my $coder = JSON::XS->new->utf8->pretty;  # with indention (bigger and not valid js code)
    my $coder = JSON::XS->new->utf8->shrink;   # shortest possible
    $c->stash->{json}         = $coder->encode($json);

    $c->stash->{title}        = 'Network Map';
    $c->stash->{page}         = 'statusmap';
    $c->stash->{template}     = 'statusmap.tt';
    $c->stash->{infoBoxTitle} = 'Network Map For All Hosts';

    return 1;
}


##########################################################

=head2 _get_json_for_hosts

=cut
sub _get_json_for_hosts {
    my $self  = shift;
    my $data  = shift;
    my $level = shift;

    my $children = [];

    unless(defined $data) {
        return($children,0,0,0,0,0);
    }

    if(ref $data ne 'HASH') {
        my @caller = caller;
        confess('not a hash ref: '.Dumper($data)."\n".Dumper(\@caller));
    }

    my($sum_hosts,$state_up,$state_down,$state_unreachable,$state_pending) = (0,0,0,0,0);
    for my $key (sort keys %{$data}) {
        my $dat = $data->{$key};
        if(ref $dat ne 'HASH') {
            my @caller = caller;
            confess('not a hash ref: '.Dumper($dat)."\n".Dumper(\@caller));
        }
        if(exists $dat->{'id'}) {
            $self->{'all_nodes'}->{$dat->{'id'}} = 1;
            push @{$children}, $dat;
            $sum_hosts         += $dat->{'data'}->{'$area'};
            $state_up          += $dat->{'data'}->{'state_up'};
            $state_down        += $dat->{'data'}->{'state_down'};
            $state_unreachable += $dat->{'data'}->{'state_unreachable'};
            $state_pending     += $dat->{'data'}->{'state_pending'};
        }
        else {
            my($childs,
               $child_sum_hosts,
               $child_sum_up,
               $child_sum_down,
               $child_sum_unreachable,
               $child_sum_pending
            ) = $self->_get_json_for_hosts($dat, ($level+1));
            $sum_hosts          += $child_sum_hosts;
            $state_up           += $child_sum_up;
            $state_down         += $child_sum_down;
            $state_unreachable  += $child_sum_unreachable;
            $state_pending      += $child_sum_pending;
            push @{$children}, {
                'id'       => 'sub_node_'.$level.'_'.$key,
                'name'     => $key,
                'data'     => {
                                '$area'            => $child_sum_hosts,
                                'state_up'         => $child_sum_up,
                                'state_down'       => $child_sum_down,
                                'state_unreachable'=> $child_sum_unreachable,
                                'state_pending'    => $child_sum_pending,
                              },
                'children' => $childs,
            };
            $self->{'all_nodes'}->{'sub_node_'.$level.'_'.$key} = 1;
        }
    }

    return($children,$sum_hosts,$state_up,$state_down,$state_unreachable,$state_pending);
}


##########################################################

=head2 _get_hosts_by_split_attribute

=cut
sub _get_hosts_by_split_attribute {
    my $self     = shift;
    my $c        = shift;
    my $hosts    = shift;
    my $attr     = shift;
    my $char     = shift;
    my $reverse  = shift;
    my $metachar = quotemeta($char);

    my $host_tree = {};
    for my $host (@{$hosts}) {

        my $json_host = $self->_get_json_host($c, $host);
        $json_host->{'children'} = [];
        my $id = $json_host->{'id'};

        my @chunks;
        if($reverse) {
            @chunks  = reverse split/$metachar/mx, $host->{$attr};
        } else {
            @chunks  = split/$metachar/mx, $host->{$attr};
        }
        my $num     = scalar @chunks;
        my $key     = "";
        my $subtree = $host_tree;
        for(my $x = 0; $x < $num; $x++) {
            if($reverse) {
                $key  = $char.$key unless $key eq '';
                $key  = $chunks[$x].$key;
            } else {
                $key .= $char unless $key eq '';
                $key .= $chunks[$x];
            }
            if($x == $num-1) {
                $subtree->{$key} = $json_host;
            }
            else {
                if(!exists $subtree->{$key}) { $subtree->{$key} = {}; }
                $subtree = \%{$subtree->{$key}};
            }
        }
    }

    my($rootchilds,
       $child_sum_hosts,
       $child_sum_up,
       $child_sum_down,
       $child_sum_unreachable,
       $child_sum_pending
    ) = $self->_get_json_for_hosts($host_tree, 0);
    my $rootnode = {
        'id'       => 'rootid',
        'name'     => 'monitoring host',
        'data'     => {
                       '$area'             => $child_sum_hosts,
                        'state_up'         => $child_sum_up,
                        'state_down'       => $child_sum_down,
                        'state_unreachable'=> $child_sum_unreachable,
                        'state_pending'    => $child_sum_pending,
                       },
        'children' => $rootchilds,
    };

    return $rootnode;
}


##########################################################

=head2 _get_hosts_by_attribute

=cut
sub _get_hosts_by_attribute {
    my $self  = shift;
    my $c     = shift;
    my $hosts = shift;
    my $attr  = shift;

    my $host_tree;
    for my $host (@{$hosts}) {

        my $json_host = $self->_get_json_host($c, $host);
        $json_host->{'children'} = [];
        my $id = $json_host->{'id'};

        $host->{$attr} = 'unknown' unless defined $host->{$attr};

        # where should we put the host onto?
        for my $val (split/,/mx, $host->{$attr}) {
            $host_tree->{$val}->{$id} = $json_host;
        }
    }

    my($rootchilds,
       $child_sum_hosts,
       $child_sum_up,
       $child_sum_down,
       $child_sum_unreachable,
       $child_sum_pending
    ) = $self->_get_json_for_hosts($host_tree, 0);
    my $rootnode = {
        'id'       => 'rootid',
        'name'     => 'monitoring host',
        'data'     => {
                       '$area'             => $child_sum_hosts,
                        'state_up'         => $child_sum_up,
                        'state_down'       => $child_sum_down,
                        'state_unreachable'=> $child_sum_unreachable,
                        'state_pending'    => $child_sum_pending,
                       },
        'children' => $rootchilds,
    };

    return $rootnode;
}


##########################################################

=head2 _get_hosts_by_parents

=cut
sub _get_hosts_by_parents {
    my $self  = shift;
    my $c     = shift;
    my $hosts = shift;

    my $all_hosts;
    for my $host (@{$hosts}) {
        $all_hosts->{$host->{name}} = $host;
    }

    my($subtree, $remaining, $state_up, $state_down, $state_unreachable, $state_pending)
        = $self->_fill_subtree($c, 'rootid', $hosts, $all_hosts);
    my $host_tree = {};
    $host_tree->{'rootid'} = {
        'id'   => 'rootid',
        'name' => 'monitoring host',
        'data' => {
            '$area'             => $state_up + $state_down + $state_unreachable + $state_pending,
            'state_up'          => $state_up,
            'state_down'        => $state_down,
            'state_unreachable' => $state_unreachable,
            'state_pending'     => $state_pending,
        },
        'children' => $subtree,
    };

    my $array = $self->_hash_tree_to_array($host_tree);
    return($array->[0]);
}

##########################################################

=head2 _fill_subtree

=cut
sub _fill_subtree {
    my $self      = shift;
    my $c         = shift;
    my $parent    = shift;
    my $hosts     = shift;
    my $all_hosts = shift;

    my $tree;
    my $remaining_hosts;

    # find direct childs
    for my $host (@{$hosts}) {
        if(!defined $host->{'parents'}) {
            $host->{'parents'} = 'rootid';
        }
        my $found_parent = 0;
        if(grep {/$parent/mx} @{$host->{'parents'}}) {
            $tree->{$host->{'name'}} = {};
        }
        else {
            push @{$remaining_hosts}, $host;
        }
    }

    my($sum_state_up, $sum_state_down, $sum_state_unreachable, $sum_state_pending) = (0,0,0,0);

    # insert the child childs
    for my $parent (keys %{$tree}) {
        my($subtree, $state_up, $state_down, $state_unreachable, $state_pending);
        ($subtree, $remaining_hosts, $state_up, $state_down, $state_unreachable, $state_pending)
            = $self->_fill_subtree($c, $parent, $remaining_hosts, $all_hosts);
        my $json_host = $self->_get_json_host($c, $all_hosts->{$parent});
        $json_host->{'data'}->{'state_up'}          += $state_up;
        $json_host->{'data'}->{'state_down'}        += $state_down;
        $json_host->{'data'}->{'state_unreachable'} += $state_unreachable;
        $json_host->{'data'}->{'state_pending'}     += $state_pending;
        $json_host->{'data'}->{'$area'}             =    $json_host->{'data'}->{'state_up'}
                                                       + $json_host->{'data'}->{'state_down'}
                                                       + $json_host->{'data'}->{'state_unreachable'}
                                                       + $json_host->{'data'}->{'state_pending'};
        $json_host->{'children'}                     = $subtree;
        $tree->{$parent}                             = $json_host;
        $sum_state_up                               += $json_host->{'data'}->{'state_up'};
        $sum_state_down                             += $json_host->{'data'}->{'state_down'};
        $sum_state_unreachable                      += $json_host->{'data'}->{'state_unreachable'};
        $sum_state_pending                          += $json_host->{'data'}->{'state_pending'};
    }

    return($tree, $remaining_hosts, $sum_state_up, $sum_state_down, $sum_state_unreachable, $sum_state_pending)
}


##########################################################

=head2 _get_json_host

=cut
sub _get_json_host {
    my $self = shift;
    my $c    = shift;
    my $host = shift;

    my $program_start = $c->stash->{'pi_detail'}->{$host->{'peer_key'}}->{'program_start'};
    my($class, $status, $duration,$color);
    my($state_up,$state_down,$state_unreachable,$state_pending) = (0,0,0,0);
    if($host->{'has_been_checked'}) {
        if($host->{'state'} == 0) {
            $class    = 'hostUP';
            $status   = 'UP';
            $color    = '#00FF00';
            $state_up++;
        }
        elsif($host->{'state'} == 1) {
            $class    = 'hostDOWN';
            $status   = 'DOWN';
            $color    = '#FF0000';
            $state_down++;
        }
        elsif($host->{'state'} == 2) {
            $class    = 'hostUNREACHABLE';
            $status   = 'UNREACHABLE';
            $color    = '#FF0000';
            $state_unreachable++;
        }
        else {
            carp("unknown state: ".Dumper($host));
        }
    } else {
        $class    = 'hostPENDING';
        $status   = 'PENDING';
        $state_pending++;
    }
    if($host->{'last_state_change'}) {
        $duration = '( for '.Thruk::Utils::Filter::duration(time() - $host->{'last_state_change'}).' )';
    } else {
        $duration = '( for '.Thruk::Utils::Filter::duration(time() - $program_start).'+ )';
    }

    # filter quotes as they break the json output
    my $plugin_output = $host->{'plugin_output'} || '';
    $plugin_output =~ s/"//gmx;

    my $alias = $host->{'alias'};
    $alias =~ s/"//gmx;

    my $address = $host->{'address'};
    $address =~ s/"//gmx;

    my $json_host = {
        'id'   => $host->{'name'},
        'name' => $host->{'name'},
        'data' => {
            '$area'             => 1,
            '$color'            => $color,
            'class'             => $class,
            'cssClass'          => $class,
            'status'            => $status,
            'duration'          => $duration,
            'plugin_output'     => $plugin_output,
            'alias'             => $alias,
            'address'           => $address,
            'state_up'          => $state_up,
            'state_down'        => $state_down,
            'state_unreachable' => $state_unreachable,
            'state_pending'     => $state_pending,
        },
    };
    $self->{'all_nodes'}->{$host->{'name'}} = 1;

    return $json_host;
}

##########################################################

=head2 _hash_tree_to_array

=cut
sub _hash_tree_to_array {
    my $self = shift;
    my $hash = shift;

    my $array = [];
    for my $key (sort keys %{$hash}) {
        my $val = $hash->{$key};
        if(defined $val->{'children'}) {
            my $childs = $self->_hash_tree_to_array($val->{'children'});
            $val->{'children'} = $childs;
            push @{$array}, $val;
        }
    }

    return $array;
}

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
