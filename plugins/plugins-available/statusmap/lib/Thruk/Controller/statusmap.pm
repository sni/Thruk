package Thruk::Controller::statusmap;

use strict;
use warnings;
use Module::Load qw/load/;

=head1 NAME

Thruk::Controller::statusmap - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

##########################################################

=head2 index

=cut
sub index {
    my ( $c ) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_DEFAULTS);

    if(!$c->config->{'statusmap_modules_loaded'}) {
        load Carp, qw/confess carp/;
        load JSON::XS;
        load Data::Dumper, qw/Dumper/;
        load Encode, qw/decode_utf8/;
        $c->config->{'statusmap_modules_loaded'} = 1;
    }

    my $style = $c->req->parameters->{'style'} || 'statusmap';
    if($style ne 'statusmap') {
        return if Thruk::Utils::Status::redirect_view($c, $style);
    }
    $c->stash->{substyle} = 'host';

    $c->stash->{type}    = $c->req->parameters->{'type'}    || $c->config->{'Thruk::Plugin::Statusmap'}->{'default_type'}    || $c->config->{'statusmap_default_type'}    || 'table';
    $c->stash->{groupby} = $c->req->parameters->{'groupby'} || $c->config->{'Thruk::Plugin::Statusmap'}->{'default_groupby'} || $c->config->{'statusmap_default_groupby'} || 'address';
    $c->stash->{detail}  = $c->req->parameters->{'detail'}  || '0';
    my $host             = $c->req->parameters->{'host'}    || 'rootid';
    if($host eq 'all') {
        $host = 'rootid';
    }

    # delete host param, otherwise we get false host=rootid filter
    delete $c->req->parameters->{'host'};

    # set some defaults
    Thruk::Utils::Status::set_default_stash($c);

    # do the filter
    $c->stash->{hidesearch} = 1;
    my( $hostfilter, $servicefilter, $groupfilter ) = Thruk::Utils::Status::do_filter($c);

    $c->stash->{host} = $host;

    # table layout does not support zoom
    # yits table breaks if one element is in multiple groups
    if($c->stash->{type} eq 'table' and ($c->stash->{groupby} eq 'hostgroup' or $c->stash->{groupby} eq 'servicegroup')) {
        $c->stash->{detail} = 0;
    }

    $c->{'all_nodes'} = {};

    my $hosts = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ]);

    # do we need servicegroups?
    if($c->stash->{groupby} eq 'servicegroup') {
        my $new_hosts;
        my $servicegroups = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter, groups => { '!=' => undef }], columns => [qw/host_name groups/]);
        my $servicegroupsbyhost = {};
        if(defined $servicegroups) {
            for my $data (@{$servicegroups}) {
                for my $group ( @{$data->{groups}}) {
                    $servicegroupsbyhost->{$data->{'host_name'}}->{$group} = 1;
                }
            }
            for my $data (@{$hosts}) {
                $data->{'servicegroups'} = [ keys %{$servicegroupsbyhost->{$data->{'name'}}} ];
                push @{$new_hosts}, $data;
            }
        }
        $hosts = $new_hosts;
    }

    my $json;
    # oder by parents
    if($c->stash->{groupby} eq 'parent') {
        $json = _get_hosts_by_parents($c, $hosts);
        $c->stash->{nodename} = 'Host';
    }
    # order by address
    elsif($c->stash->{groupby} eq 'address') {
        $json = _get_hosts_by_split_attribute($c, $hosts, 'address', '.', 0);
        $c->stash->{nodename} = 'Network';
    }
    # order by domain
    elsif($c->stash->{groupby} eq 'domain') {
        $json = _get_hosts_by_split_attribute($c, $hosts, 'name', '.', 1);
        $c->stash->{nodename} = 'Domain';
    }
    # order by hostgroups
    elsif($c->stash->{groupby} eq 'hostgroup') {
        $json = _get_hosts_by_attribute($c, $hosts, 'groups');
        $c->stash->{nodename} = 'Hostgroup';
    }
    # order by servicegroups
    elsif($c->stash->{groupby} eq 'servicegroup') {
        $json = _get_hosts_by_attribute($c, $hosts, 'servicegroups');
        $c->stash->{nodename} = 'Servicegroup';
    }
    # order by custom variable
    elsif($c->stash->{groupby} =~ /^cust:(.*)$/mx) {
        $json = _get_hosts_by_attribute($c, $hosts, 'custom_variable', $1);
        $c->stash->{nodename} = $1;
    }
    else {
        confess("unknown groupby option: ".$c->stash->{groupby});
    }

    # does our root id exist?
    if(!defined $c->{'all_nodes'}->{$c->stash->{host}}) {
        $c->stash->{host} = 'rootid';
    }

    #my $coder = JSON::XS->new->utf8->pretty;  # with indention (bigger and not valid js code)
    my $coder = JSON::XS->new->utf8->shrink;   # shortest possible
    $c->stash->{json}          = decode_utf8($coder->encode($json));

    $c->stash->{title}         = 'Network Map';
    $c->stash->{page}          = 'statusmap';
    $c->stash->{style}         = 'statusmap';
    $c->stash->{show_top_pane} = 1;
    $c->stash->{template}      = 'statusmap.tt';
    $c->stash->{infoBoxTitle}  = 'Network Map';

    Thruk::Utils::Status::set_custom_title($c);

    return 1;
}


##########################################################

=head2 _get_json_for_hosts

=cut
sub _get_json_for_hosts {
    my($c, $data, $level) = @_;

    my $children = [];

    if(!defined $data) {
        return($children,0,0,0,0,0);
    }

    if(ref $data ne 'HASH') {
        my @caller = caller;
        confess('not a hash ref: '.Dumper($data)."\n".Dumper(\@caller));
    }

    my($sum_hosts,$state_up,$state_down,$state_unreachable,$state_pending) = (0,0,0,0,0);
    for my $key (sort keys %{$data}) {
        my $dat = $data->{$key};
        my $dats = [$dat];
        $dats = $dat if ref $dat eq 'ARRAY';
        for my $dat (@{$dats}) {
            if(ref $dat ne 'HASH') {
                my @caller = caller;
                confess('not a hash ref: '.Dumper($dat)."\n".Dumper(\@caller));
            }
            if(exists $dat->{'id'}) {
                $c->{'all_nodes'}->{$dat->{'id'}} = 1;
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
                   $child_sum_pending,
                ) = _get_json_for_hosts($c, $dat, ($level+1));
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
                $c->{'all_nodes'}->{'sub_node_'.$level.'_'.$key} = 1;
            }
        }
    }

    return($children,$sum_hosts,$state_up,$state_down,$state_unreachable,$state_pending);
}


##########################################################

=head2 _get_hosts_by_split_attribute

=cut
sub _get_hosts_by_split_attribute {
    my $c        = shift;
    my $hosts    = shift;
    my $attr     = shift;
    my $char     = shift;
    my $reverse  = shift;
    my $metachar = quotemeta($char);

    my $host_tree = {};
    for my $host (@{$hosts}) {

        my $json_host = _get_json_host($c, $host);
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
                if(defined $subtree->{$key}) {
                    if(ref $subtree->{$key} eq 'ARRAY') {
                        push @{$subtree->{$key}}, $json_host;
                    } else {
                        my $old = $subtree->{$key};
                        $subtree->{$key} = [
                            $json_host,
                            $old,
                        ];
                    }
                } else {
                    $subtree->{$key} = $json_host;
                }
            }
            else {
                if(!exists $subtree->{$key} || ref $subtree->{$key} ne 'HASH') { $subtree->{$key} = {}; }
                $subtree = \%{$subtree->{$key}};
            }
        }
    }

    my($rootchilds,
       $child_sum_hosts,
       $child_sum_up,
       $child_sum_down,
       $child_sum_unreachable,
       $child_sum_pending,
    ) = _get_json_for_hosts($c, $host_tree, 0);
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
    my($c, $hosts, $attr, $val) = @_;

    my $host_tree;
    for my $host (@{$hosts}) {

        my $json_host = _get_json_host($c, $host);
        $json_host->{'children'} = [];
        my $id = $json_host->{'id'};

        $host->{$attr} = ['unknown'] unless defined $host->{$attr};
        if($attr eq 'custom_variable') {
            $host->{$attr} = [$json_host->{'data'}->{$val} // 'none'];
        }

        # where should we put the host onto?
        for my $val (@{$host->{$attr}}) {
            $host_tree->{$val}->{$id} = $json_host;
        }
    }

    my($rootchilds,
       $child_sum_hosts,
       $child_sum_up,
       $child_sum_down,
       $child_sum_unreachable,
       $child_sum_pending,
    ) = _get_json_for_hosts($c, $host_tree, 0);
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
    my $c     = shift;
    my $hosts = shift;

    my $all_hosts;
    for my $host (@{$hosts}) {
        $all_hosts->{$host->{name}} = $host;
    }

    my($subtree, $remaining, $state_up, $state_down, $state_unreachable, $state_pending)
        = _fill_subtree($c, 'rootid', $hosts, $all_hosts);
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
    # if one parentless child, no root is required
    if (scalar(keys %{$subtree}) == 1) {
        $host_tree = $subtree;
    }

    my $array = _hash_tree_to_array($host_tree);
    return($array->[0]);
}

##########################################################

=head2 _fill_subtree

=cut
sub _fill_subtree {
    my $c         = shift;
    my $parent    = shift;
    my $hosts     = shift;
    my $all_hosts = shift;

    my $tree;
    my $remaining_hosts;

    # find direct childs
    for my $host (@{$hosts}) {
        if(scalar @{$host->{'parents'}} == 0) {
            # check if parentless host has a backend peer configured
            if (defined $host->{'peer_key'}
                and defined $c->{'db'}->{'state_hosts'}->{$host->{'peer_key'}}
                and defined $c->{'db'}->{'state_hosts'}->{$host->{'peer_key'}}->{'name'}
                ) {
                $host->{'parents'} = [ $c->{'db'}->{'state_hosts'}->{$host->{'peer_key'}}->{'name'} ];
            } else {
                $host->{'parents'} = [qw/rootid/];
            }
        }
        my $found_parent = 0;
        for my $par (@{$host->{'parents'}}) {
            if($par eq $parent) { $found_parent = 1; last; }
        }
        if($found_parent) {
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
            = _fill_subtree($c, $parent, $remaining_hosts, $all_hosts);
        my $json_host = _get_json_host($c, $all_hosts->{$parent});
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

    return($tree, $remaining_hosts, $sum_state_up, $sum_state_down, $sum_state_unreachable, $sum_state_pending);
}


##########################################################

=head2 _get_json_host

=cut
sub _get_json_host {
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
    $plugin_output =~ s/("|')//gmx;

    my $alias = $host->{'alias'};
    $alias =~ s/("|')//gmx;

    my $address = $host->{'address'};
    $address =~ s/("|')//gmx;

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
    if (defined $host->{'icon_image'}) {
           my $icon_image = $host->{'icon_image'};
           $icon_image =~ s/"//gmx;
           $icon_image =~ s/'//gmx;
           $json_host->{'data'}->{'icon_image'} = $icon_image;
    }
    my $vars = Thruk::Utils::get_custom_vars($c, $host);
    for my $custvar (@{$c->config->{'show_custom_vars'}}) {
        my $name = $custvar;
        $name =~ s/^_//gmx;
        $json_host->{'data'}->{$custvar} = $vars->{$name} // 'none';
    }
    $c->{'all_nodes'}->{$host->{'name'}} = 1;

    return $json_host;
}

##########################################################

=head2 _hash_tree_to_array

=cut
sub _hash_tree_to_array {
    my $hash = shift;

    my $array = [];
    for my $key (sort keys %{$hash}) {
        my $val = $hash->{$key};
        if(defined $val->{'children'}) {
            my $childs = _hash_tree_to_array($val->{'children'});
            $val->{'children'} = $childs;
            push @{$array}, $val;
        }
    }

    return $array;
}

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
