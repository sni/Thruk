package Thruk::BP::Components::BP;

use strict;
use warnings;
use Data::Dumper;
use Config::General;
use Storable qw/lock_nstore lock_retrieve/;
use File::Copy qw/move/;
use Encode qw/encode_utf8/;
use Thruk::Utils;
use Thruk::BP::Components::Node;

=head1 NAME

Thruk::BP::Components::Node - BP Class

=head1 DESCRIPTION

Business Process

=head1 METHODS

=cut

my @stateful_keys = qw/status status_text last_check last_state_change/;

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
        'nodes'             => [],
        'nodes_by_id'       => {},
        'nodes_by_name'     => {},
        'need_update'       => {},
        'need_save'         => 0,
        'file'              => undef,
        'datafile'          => undef,
        'editfile'          => undef,

        'status'            => 4,
        'status_text'       => 'not yet checked',
        'last_check'        => 0,
        'last_state_change' => 0,
    };
    bless $self, $class;
    $self->set_file($c, $file);

    if($editmode and -e $self->{'editfile'}) { $file = $self->{'editfile'}; }
    if(-e $file) {
        my $conf = Config::General->new(-ConfigFile => $file, -ForceArray => 1, -UTF8 => 1);
        my %config = $conf->getall;
        return unless $config{'bp'};
        my $bplist = Thruk::Utils::list($config{'bp'});
        return unless scalar @{$bplist} > 0;
        $bpdata = $bplist->[0];
    }
    $self->{'name'} = $bpdata->{'name'};

    # read in nodes
    for my $n (@{Thruk::Utils::list($bpdata->{'node'} || [])}) {
        my $node = Thruk::BP::Components::Node->new($n);
        $self->add_node($node, 1);
    }

    $self->_resolve_nodes();

    if($self->{'editmode'}) {
        die("no context") unless $c;
        $self->update_status($c);
    } else {
        $self->load_runtime_data();
    }

    $self->save() if $self->{'need_save'};

    return $self;
}

##########################################################

=head2 load_runtime_data

update runtime data

=cut
sub load_runtime_data {
    my($self) = @_;

    return unless -e $self->{'datafile'};

    my $data = lock_retrieve($self->{'datafile'});

    for my $key (qw/status status_text last_check last_state_change/) {
        $self->{$key} = $data->{$key} if defined $data->{$key};
    }

    for my $n (@{$self->{'nodes'}}) {
        $n->load_runtime_data($data->{'nodes'}->{$n->{'id'}});
    }
    return;
}

##########################################################

=head2 update_status

update status of business process

=cut
sub update_status {
    my ( $self, $c ) = @_;

    die("no context") unless $c;

    my $last_state = $self->{'status'};

    # bulk fetch live data
    my $hostfilter    = {};
    my $servicefilter = {};
    my $hostdata      = {};
    my $servicedata   = {};
    for my $n (@{$self->{'nodes'}}) {
        if(lc $n->{'function'} eq 'status') {
            if($n->{'host'} and $n->{'service'}) {
                $servicefilter->{$n->{'host'}}->{$n->{'service'}} = 1;
            }
            elsif($n->{'host'}) {
                $hostfilter->{$n->{'host'}} = 1;
            }
        }
    }
    if(scalar keys %{$hostfilter} > 0) {
        my @filter;
        for my $hostname (keys %{$hostfilter}) {
            push @filter, { name => $hostname };
        }
        my $filter = Thruk::Utils::combine_filter( '-or', \@filter );
        my $data   = $c->{'db'}->get_hosts(filter => [$filter]);
        $hostdata  = Thruk::Utils::array2hash($data, 'name');
    }
    if(scalar keys %{$servicefilter} > 0) {
        my @filter;
        for my $hostname (keys %{$servicefilter}) {
            for my $description (keys %{$servicefilter->{$hostname}}) {
                push @filter, { host_name => $hostname, description => $description };
            }
        }
        my $filter = Thruk::Utils::combine_filter( '-or', \@filter );
        my $data   = $c->{'db'}->get_services(filter => [$filter]);
        $servicedata = Thruk::Utils::array2hash($data, 'host_name', 'description');
    }

    for my $n (@{$self->{'nodes'}}) {
        $n->update_status($c, $self, $hostdata, $servicedata);
    }

    my $iterations = 0;
    while(scalar keys %{$self->{'need_update'}} > 0) {
        $iterations++;
        for my $id (keys %{$self->{'need_update'}}) {
            $self->{'nodes_by_id'}->{$id}->update_status($c, $self);
        }
        die("circular dependenies? Still have these on the update list: ".Dumper($self->{'need_update'})) if $iterations > 10;
    }

    # update last check time
    my $now = time();
    $self->{'last_check'} = $now;
    if($last_state != $self->{'status'}) {
        $self->{'last_state_change'} = $now;
    }

    # store runtime data
    $self->save_runtime();

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
    $self->{'file'}     = $c->config->{'home'}.'/bp/'.$basename;
    $self->{'datafile'} = $c->config->{'var_path'}.'/bp/'.$basename.'.runtime';
    $self->{'editfile'} = $c->config->{'var_path'}.'/bp/'.$basename.'.edit';
    $basename =~ m/(\d+).tbp/mx;
    $self->{'id'}       = $1;
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

    return;
}

##########################################################
# replace list of node names/ids with references
sub _resolve_nodes {
    my($self) = @_;

    for my $node (@{$self->{'nodes'}}) {
        # make sure we have an id noew
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

save business process data to edit file

=cut
sub save {
    my ( $self, $c ) = @_;

    my $string = "<bp>\n";
    for my $key (qw/name/) {
        $string .= sprintf("  %-10s = %s\n", $key, $self->{$key});
    }
    for my $n (@{$self->{'nodes'}}) {
        $string .= $n->save_to_string();
    }
    $string .= "</bp>\n";
    open(my $fh, '>', $self->{'editfile'}) or die('cannot open '.$self->{'editfile'}.': '.$!);
    print $fh encode_utf8($string);
    Thruk::Utils::IO::close($fh, $self->{'file'});
    $self->{'need_save'} = 0;

    return 1;
}

##########################################################

=head2 get_objects_string

return object config as string

=cut
sub get_objects_string {
    my ( $self ) = @_;
    my $string = "";
    for my $n (@{$self->{'nodes'}}) {
        $string .= $n->get_objects_string($self);
    }
    if($string ne '') {
        $string = "# ".$self->{'file'}."\n".
                  $string;
    }
    return $string;
}

##########################################################

=head2 save_runtime

save run time data

=cut
sub save_runtime {
    my ( $self ) = @_;
    return if $self->{'editmode'};
    my $data = {};
    for my $key (@stateful_keys) {
        $data->{$key} = $self->{$key};
    }
    for my $n (@{$self->{'nodes'}}) {
        $data->{'nodes'}->{$n->{'id'}} = $n->get_stateful_data();
    }
    lock_nstore($data, $self->{'datafile'});
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


=head1 AUTHOR

Sven Nierlein, 2013, <sven.nierlein@consol.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
