package Thruk::Utils::CLI::Backend;

=head1 NAME

Thruk::Utils::CLI::Backend - Backend CLI module

=head1 DESCRIPTION

The backend command lists livestatus backends

=head1 SYNOPSIS

  Usage: thruk [globaloptions] backend <cmd>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<cmd>

    available commands are:

    - list          lists all backends

=back

=cut

use warnings;
use strict;

use Thruk::Action::AddDefaults ();
use Thruk::Constants qw/:add_defaults :peer_states/;
use Thruk::Utils::Log qw/:all/;

our $skip_backends = 1;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions, $data, $src, $opt) = @_;

    Thruk::Action::AddDefaults::add_defaults($c, ADD_SAFE_DEFAULTS);

    my $backends;
    if(!defined $opt->{'backends'} || scalar @{$opt->{'backends'}} == 0) {
        my @args;
        if(Thruk::Base::array_contains(['-a', '--all'], $commandoptions)) {
            @args = (1, 1);
        }
        my $peers = $c->db->get_peers(@args);
        my @keys;
        for my $peer (@{$peers}) {
            push @keys, $peer->{'key'};
        }
        $c->stash->{'backends'} = \@keys;
    } else {
        ($backends) = $c->db->select_backends();
        $backends = Thruk::Base::array2hash($backends);
        Thruk::Action::AddDefaults::set_possible_backends($c, {});
    }
    my @data;
    for my $key (@{$c->stash->{'backends'}}) {
        next if($backends && !$backends->{$key});
        my $peer = $c->db->get_peer_by_key($key);
        my $addr = $c->stash->{'backend_detail'}->{$key}->{'addr'};
        $addr    =~ s|/cgi-bin/remote.cgi$||mx if $addr;
        my $error = defined $c->stash->{'backend_detail'}->{$key}->{'last_error'} ? $c->stash->{'backend_detail'}->{$key}->{'last_error'} : '';
        $peer->{'hidden'} = 1 if $peer->{'type'} eq 'configonly';
        chomp($error);
        push @data, {
            Key     => $key,
            Section => $peer->{'section'},
            Name    => $c->stash->{'backend_detail'}->{$key}->{'name'} // $peer->{'name'},
            Enabled => (!defined $peer->{'hidden'} || $peer->{'hidden'} == 0) ? 'Yes' : 'No',
            Address => $addr || $peer->{'peer_config'}->{'options'}->{'host_name'},
            Version => _get_peer_version($c, $key),
            Status  => $error || 'OK',
        };
    }
    my $output = Thruk::Utils::text_table(
        keys => ['Name', 'Section', 'Key', 'Enabled', 'Address', 'Version', 'Status'],
        data => \@data,
    );
    return($output, 0);
}

##############################################
sub _get_peer_version {
    my($c, $key) = @_;
    if($c->stash->{'pi_detail'}->{$key}
       && $c->stash->{'pi_detail'}->{$key}->{'thruk'}
       && $c->stash->{'pi_detail'}->{$key}->{'thruk'}->{'thruk_version'}) {
       return($c->stash->{'pi_detail'}->{$key}->{'thruk'}->{'thruk_version'});
    }
    if($c->stash->{'pi_detail'}->{$key} && $c->stash->{'pi_detail'}->{$key}->{'data_source_version'}) {
        return($c->stash->{'pi_detail'}->{$key}->{'data_source_version'});
    }
    return("");
}

##############################################

=head1 EXAMPLES

Display all available backends

  %> thruk backend list

=cut

##############################################

1;
