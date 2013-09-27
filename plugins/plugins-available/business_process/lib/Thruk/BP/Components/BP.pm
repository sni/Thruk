package Thruk::BP::Components::BP;

use strict;
use warnings;
use Data::Dumper;
use Config::General;
use Storable qw/lock_nstore lock_retrieve/;
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
    my ( $class, $id, $file ) = @_;

    my $conf = Config::General->new(-ConfigFile => $file, -ForceArray => 1);
    my %config = $conf->getall;
    next unless $config{'bp'};
    my $bplist = Thruk::Utils::list($config{'bp'});
    return unless scalar @{$bplist} > 0;
    my $bpdata = $bplist->[0];

    my $self = {
        'id'                => $id,
        'name'              => $bpdata->{'name'},
        'nodes'             => [],
        'need_update'       => {},
        'datafile'          => $file.'.runtime',

        'status'            => 4,
        'status_text'       => 'not yet checked',
        'last_check'        => 0,
        'last_state_change' => 0,
    };
    bless $self, $class;

    # read in nodes
    my $num = 0;
    for my $n (@{Thruk::Utils::list($bpdata->{'node'} || [])}) {
        my $node = Thruk::BP::Components::Node->new('node'.$num++, $n);
        $self->add_node($node);
    }

    $self->_resolve_nodes();

    $self->load_runtime_data();

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

    my $last_state = $self->{'status'};

    for my $n (@{$self->{'nodes'}}) {
        $n->update_status($c, $self);
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

=head2 add_node

add new node to business process

=cut
sub add_node {
    my ( $self, $node ) = @_;
    push @{$self->{'nodes'}}, $node;
    $self->{'nodes_by_id'}->{$node->{'id'}}      = $node;
    $self->{'nodes_by_name'}->{$node->{'label'}} = $node;
    return;
}

##########################################################
# replace list of node names/ids with references
sub _resolve_nodes {
    my($self) = @_;

    for my $node (@{$self->{'nodes'}}) {
        my $new_depends = [];
        for my $d (@{$node->{'depends'}}) {
            # not a reference yet?
            if(ref $d eq '') {
                my $dn = $self->{'nodes_by_id'}->{$d} || $self->{'nodes_by_name'}->{$d};
                if(!$dn) {
                    # fake node required
                    my $id = scalar @{$self->{'nodes'}}; # next free id
                    $dn = Thruk::BP::Components::Node->new('node'.$id, {
                                        'label'    => $d,
                                        'function' => 'Fixed("Unknown")',
                    });
                    $self->add_node($dn);
                }
                $d = $dn;
            }
            push @{$new_depends}, $d;

            # add parent connection
            push @{$d->{'parents'}}, $node;
        }
        $node->{'depends'} = $new_depends;
    }

    return;
}

##########################################################

=head2 save

save business process data to file

=cut
sub save {
    my ( $self, $file ) = @_;
    return;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2013, <sven.nierlein@consol.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
