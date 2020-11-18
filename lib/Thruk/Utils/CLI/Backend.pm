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
use Thruk::Utils::Log qw/:all/;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c) = @_;
    $c->{'db'}->enable_backends();
    eval {
        $c->{'db'}->get_processinfo();
    };
    _debug($@) if $@;
    Thruk::Action::AddDefaults::set_possible_backends($c, {});
    my $output = '';
    $output .= sprintf("%-4s  %-7s  %-9s   %s\n", 'Def', 'Key', 'Name', 'Address');
    $output .= sprintf("-------------------------------------------------\n");
    for my $key (@{$c->stash->{'backends'}}) {
        my $peer = $c->{'db'}->get_peer_by_key($key);
        my $addr = $c->stash->{'backend_detail'}->{$key}->{'addr'};
        $addr    =~ s|/cgi-bin/remote.cgi$||mx;
        $output .= sprintf("%-4s %-8s %-10s %s",
                (!defined $peer->{'hidden'} || $peer->{'hidden'} == 0) ? ' * ' : '',
                $key,
                $c->stash->{'backend_detail'}->{$key}->{'name'},
                $addr,
        );
        my $error = defined $c->stash->{'backend_detail'}->{$key}->{'last_error'} ? $c->stash->{'backend_detail'}->{$key}->{'last_error'} : '';
        chomp($error);
        $output .= " (".($error || 'OK').")";
        $output .= "\n";
    }
    $output .= sprintf("-------------------------------------------------\n");
    return($output, 0);
}

##############################################

=head1 EXAMPLES

Display all available backends

  %> thruk backend list

=cut

##############################################

1;
