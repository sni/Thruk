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

    $c->stash->{level}        = $c->request->parameters->{'level'}   || 1;
    $c->stash->{type}         = $c->request->parameters->{'type'}    || 1;
    $c->stash->{groupby}      = $c->request->parameters->{'groupby'} || 1;

    my $hosts = $c->{'live'}->selectall_arrayref("GET hosts\n".Thruk::Utils::get_auth_filter($c, 'hosts')."\nColumns: state name alias address address has_been_checked last_state_change plugin_output childs parents", { Slice => {}, AddPeer => 1 });

    my $json;
    if($c->stash->{groupby} == 1) {
        $json = $self->_get_hosts_by_parents($c, $hosts);
    }
    # order by address
    elsif($c->stash->{groupby} == 2) {
        $json = $self->_get_hosts_by_address($c, $hosts);
    }



#print "HTTP/1.0 200 OK\n\n<pre>";
#print Dumper($host_tree);


#print Dumper($json);


    #my $coder = JSON::XS->new->utf8->pretty;  # with indention (bigger)
    my $coder = JSON::XS->new->utf8->shrink;   # shortest possible
    $c->stash->{json}         = $coder->encode($json);
    #$c->stash->{json}         = $coder->encode(\@hosts);

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

    if(ref $data ne 'HASH') {
        my @caller = caller;
        confess('not a hash ref: '.Dumper($data)."\n".Dumper(\@caller));
    }

    my($sum_hosts,$state_up,$state_down,$state_unreachable,$state_pending) = (0,0,0,0,0);
    for my $key (sort keys %{$data}) {
        my $dat = $data->{$key};
        if(exists $dat->{'id'}) {
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
        }
    }

    return($children,$sum_hosts,$state_up,$state_down,$state_unreachable,$state_pending);
}


##########################################################

=head2 _get_hosts_by_address

=cut
sub _get_hosts_by_address {
    my $self  = shift;
    my $c     = shift;
    my $hosts = shift;

    my $host_tree;
    for my $host (@{$hosts}) {

        my $json_host = $self->_get_json_host($c, $host);
        $json_host->{'children'} = [];
        my $id = $json_host->{'id'};

        # where should we put the host onto?
        if($c->stash->{groupby} == 2) { # order by address
            if($host->{'address'} =~ m/(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/) {
                # table layout
                if($c->stash->{'type'} == 1) {
                    $host_tree->{$1}->{$1.'.'.$2}->{$1.'.'.$2.'.'.$3}->{$id} = $json_host;
                    #if($c->stash->{level} == 4) {
                    #    $host_tree->{$1.'.'.$2.'.'.$3}->{$id} = $json_host;
                    #}
                    #if($c->stash->{level} == 3) {
                    #    $host_tree->{$1.'.'.$2}->{$id} = $json_host;
                    #}
                    #if($c->stash->{level} == 2) {
                    #    $host_tree->{$1}->{$id} = $json_host;
                    #}
                    #if($c->stash->{level} == 1) {
                    #    $host_tree->{$id} = $json_host;
                    #}
                }
                # circle layout
                elsif($c->stash->{'type'} == 2) {
                    if($c->stash->{level} == 1) {
                        $host_tree->{$1}->{$1.'.'.$2}->{$1.'.'.$2.'.'.$3}->{$id} = $json_host;
                    }
                    if($c->stash->{level} == 2) {
                        $host_tree->{$1.'.'.$2}->{$1.'.'.$2.'.'.$3}->{$id} = $json_host;
                    }
                } else {
                    confess("unknown type: ".$c->stash->{'type'});
                }
            }
        } else {
            $host_tree->{$id} = $json_host;
        }
    }

    my($childs,
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
                       '$area' => $child_sum_hosts,
                        'state_up'         => $child_sum_up,
                        'state_down'       => $child_sum_down,
                        'state_unreachable'=> $child_sum_unreachable,
                        'state_pending'    => $child_sum_pending,
                       },
        'children' => $childs,
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

    my @hosts;
    my @rootchilds;
    for my $host (@{$hosts}) {
        my $json_host = $self->_get_json_host($c, $host);
        my @adjacencies;
        push @adjacencies, split(/,/mx, $host->{'childs'})  if defined $host->{'childs'};
        #push @adjacencies, split(/,/mx, $host->{'parents'}) if defined $host->{'parents'};
        #if(scalar @adjacencies == 0) {
        unless(defined $host->{'parents'}) {
            push @rootchilds, $host->{'name'};
        #    push @adjacencies, 'monitoring host';
        }
        $json_host->{'adjacencies'} = \@adjacencies;
        push @hosts, $json_host;
    }

    my $rootnode = {
        'id'          => 'rootid',
        'name'        => 'monitoring host',
        'data'        => { '$area' => 100 },
        'adjacencies'    => \@rootchilds,
    };
    unshift @hosts, $rootnode;
    return \@hosts;
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
        if($host->{'state'} == 1) {
            $class    = 'hostDOWN';
            $status   = 'DOWN';
            $color    = '#FF0000';
            $state_down++;
        }
        if($host->{'state'} == 2) {
            $class    = 'hostUNREACHABLE';
            $status   = 'UNREACHABLE';
            $color    = '#FF0000';
            $state_unreachable++;
        }
    } else {
        $class    = 'hostPENDING';
        $status   = 'PENDING';
        $state_pending++;
    }
    if($host->{'last_state_change'}) {
        $duration = '( for '.Thruk::Utils::filter_duration(time() - $host->{'last_state_change'}).' )';
    } else {
        $duration = '( for '.Thruk::Utils::filter_duration(time() - $program_start).'+ )';
    }
    my $json_host = {
        'id'   => $host->{'name'},
        'name' => $host->{'name'},
        'data' => {
            '$area'             => 1,
            '$color'            => $color,
            'class'             => $class,
            'status'            => $status,
            'duration'          => $duration,
            'plugin_output'     => $host->{'plugin_output'} || '',
            'alias'             => $host->{'alias'},
            'address'           => $host->{'address'},
            'state_up'          => $state_up,
            'state_down'        => $state_down,
            'state_unreachable' => $state_unreachable,
            'state_pending'     => $state_pending,
        },
    };

    return $json_host;
}

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
