package Thruk::Metrics;

use warnings;
use strict;
use Thruk::Utils::IO ();

my $obj;

##############################################
sub new {
    my($class, %args) = @_;
    return $obj if $obj;
    my $self = {
        'file'      => $args{'file'},
        'help_file' => $args{'file'}.".help",
        'store'     => [],
        'help'      => {},
    };
    bless($self, $class);
    $obj = $self;
    return($self);
}

##############################################
sub register {
    my($self, $key, $help) = @_;
    $self->{'help'}->{$key} = $help;
    $self->{'save_help'} = 1;
    return;
}

##############################################
sub get_all {
    my($self) = @_;
    $self->store();
    if(!-s $self->{'file'}) {
        return({});
    }
    my $data = Thruk::Utils::IO::json_lock_retrieve($self->{'file'});
    return($data);
}

##############################################
sub set {
    my($self, $key, $value, $help) = @_;
    push @{$self->{'store'}}, ["set", $key, $value];
    $self->register($key, $help) if $help;
    return;
}

##############################################
sub add {
    my($self, $key, $value, $help) = @_;
    push @{$self->{'store'}}, ["add", $key, $value];
    $self->register($key, $help) if $help;
    return;
}

##############################################
sub inc {
    my($self, $key, $help) = @_;
    push @{$self->{'store'}}, ["add", $key, 1];
    $self->register($key, $help) if $help;
    return;
}

##############################################
sub store {
    my($self) = @_;
    $self->_save_help() if $self->{'save_help'};
    return if scalar @{$self->{'store'}} == 0;
    my $data = {};
    if(!-s $self->{'file'}) {
        $self->_apply_data($data);
        Thruk::Utils::IO::json_store($self->{'file'}, $data, 1);
        $self->{'store'} = [];
        return;
    }
    my($fh, $lock_fh) = Thruk::Utils::IO::file_lock($self->{'file'}, 'ex');
    $data = Thruk::Utils::IO::json_retrieve($self->{'file'}, $fh);
    $self->_apply_data($data);
    Thruk::Utils::IO::json_store($self->{'file'}, $data, 1);
    Thruk::Utils::IO::file_unlock($self->{'file'}, $fh, $lock_fh);
    $self->{'store'} = [];
    return;
}

##############################################
sub _save_help {
    my($self) = @_;
    if(!-s $self->{'help_file'}) {
        Thruk::Utils::IO::json_store($self->{'help_file'}, {}, 1);
    }
    my $help = Thruk::Utils::IO::json_lock_retrieve($self->{'help_file'});
    for my $key (keys %{$self->{'help'}}) {
        $help->{$key} = $self->{'help'}->{$key};
    }
    Thruk::Utils::IO::json_lock_store($self->{'help_file'}, $help, 1);
    delete $self->{'save_help'};
    return;
}

##############################################
sub _apply_data {
    my($self, $data) = @_;
    for my $cmd (@{$self->{'store'}}) {
        my($op, $key, $value) = @{$cmd};
        if($op eq 'set') {
            $data->{$key} = $value;
        }
        elsif($op eq 'add') {
            $data->{$key} = 0 unless defined $data->{$key};
            $data->{$key} += $value;
        }
    }
    return;
}

##############################################

END {
    if($obj) {
        $obj->store();
    }
}

##############################################

1;
__END__

=head1 NAME

Thruk::Metrics - Gather metrics

=head1 SYNOPSIS

  $c->metrics->set($key, $value);

=head1 DESCRIPTION

C<Thruk::Metrics> provides simple metrics

=head1 METHODS

=head2 new

    new()

return new metrics object

=head2 get_all

    get_all()

return all metrics

=head2 register

    register($metric, $help)

register this metric

=head2 set

    set($key, $value, [$help])

set metric to absolute value. Calls register if help is set.

=head2 add

    add($key, $value, [$help])

add value to metric. Calls register if help is set.

=head2 inc

    inc($key, [$help])

increment metric by 1. Calls register if help is set.

=head2 store

    store()

write metrics to disk. (automatically called on END)

=cut
