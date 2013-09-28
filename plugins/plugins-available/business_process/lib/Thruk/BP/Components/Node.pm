package Thruk::BP::Components::Node;

use strict;
use warnings;
use Thruk::Utils;
use Thruk::BP::Functions;
use Thruk::BP::Utils;

=head1 NAME

Thruk::BP::Components::Node - Node Class

=head1 DESCRIPTION

Business Process Node

=head1 METHODS

=cut

my @stateful_keys = qw/status status_text last_check last_state_change/;

my $tr_states = {
    '0' => 'OK',
    '1' => 'WARNING',
    '2' => 'CRITICAL',
    '3' => 'UNKNOWN',
};

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
        'parents'           => $data->{'parents'} || [],

        'status'            => defined $data->{'status'} ? $data->{'status'} : 4,
        'status_text'       => $data->{'status_text'} || '',
        'last_check'        => 0,
        'last_state_change' => 0,
    };
    bless $self, $class;

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

=head2 save_to_string

get textual representation of this node

=cut
sub save_to_string {
    my ( $self ) = @_;
    my $string = "  <node>\n";

    # normal keys
    for my $key (qw/id label/) {
        $string .= sprintf("    %-10s = %s\n", $key, $self->{$key});
    }

    # function
    if($self->{'function'}) {
        my @arg;
        for my $a (@{$self->{'function_args'}}) {
            if($a =~ m/^(\d+|\d+\.\d+)$/mx) {
                push @arg, $a;
            } else {
                push @arg, "'".$a."'";
            }
        }
        $string .= sprintf("    %-10s = %s(%s)\n", "function", $self->{'function'}, join(', ', @arg));
    }

    # depends
    for my $d (@{$self->{'depends'}}) {
        $string .= sprintf("    %-10s = %s\n", 'depends', $d->{'label'});
    }
    $string .= "  </node>\n";
    return $string;
}

##########################################################

=head2 update_status

update status of node

=cut
sub update_status {
    my($self, $c, $bp) = @_;
    delete $bp->{'need_update'}->{$self->{'id'}};

    return unless $self->{'function_ref'};
    my $function = $self->{'function_ref'};
    eval {
        my($status, $status_text) = &$function($c, $bp, $self, @{$self->{'function_args'}});
        $self->_set_status($status, $status_text, $bp);
    };
    if($@) {
        $self->_set_status(3, 'Internal Error: '.$@, $bp);
    }

    return;
}

##########################################################
sub _set_status {
    my($self, $state, $text, $bp) = @_;

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

    # if this node has no parents, use this state for the complete bp
    if($bp and scalar @{$self->{'parents'}} == 0) {
        my $text = $self->{'status_text'};
        if(scalar @{$self->{'depends'}} > 0) {
            my $sum = Thruk::BP::Functions::_get_nodes_grouped_by_state($self, $bp);
            if($sum->{'3'}) {
                $text = _join_labels($sum->{'3'}).' unknown';
            }
            elsif($sum->{'2'}) {
                $text = _join_labels($sum->{'2'}).' failed';
            }
            elsif($sum->{'1'}) {
                $text = _join_labels($sum->{'1'}).' warning';
            }
            else {
                $text = 'everyhing is fine';
            }
            $text = $tr_states->{$self->{'status'}}.' - '.$text;
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
        my $function = \&{'Thruk::BP::Functions::'.lc($fname)};
        if(!defined &$function) {
            $self->_set_status(3, 'Unknown function: '.($fname || $data->{'function'}));
        } else {
            $self->{'function_args'} = Thruk::BP::Utils::clean_function_args($fargs);
            $self->{'function_ref'}  = $function;
            $self->{'function'}      = $fname;
        }
    }
    return;
}

##########################################################
sub _join_labels {
    my($nodes) = @_;
    my @labels;
    for my $n (@{$nodes}) {
        push @labels, $n->{'label'};
    }
    my $num = scalar @labels;
    if($num == 1) {
        return($labels[0]);
    }
    if($num == 2) {
        return($labels[0].' and '.$labels[1]);
    }
    my $last = pop @labels;
    return(join(', ', @labels).' and '.$last);
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2013, <sven.nierlein@consol.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
