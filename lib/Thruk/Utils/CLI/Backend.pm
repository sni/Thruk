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
use Thruk::Utils ();
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
        $c->{'db'}->enable_backends();
    } else {
        ($backends) = $c->{'db'}->select_backends();
        $backends = Thruk::Base::array2hash($backends);
    }
    eval {
        $c->{'db'}->get_processinfo();
    };
    _debug($@) if $@;
    Thruk::Action::AddDefaults::set_possible_backends($c, {});
    my @data;
    for my $key (@{$c->stash->{'backends'}}) {
        next if($backends && !$backends->{$key});
        my $peer = $c->{'db'}->get_peer_by_key($key);
        my $addr = $c->stash->{'backend_detail'}->{$key}->{'addr'};
        $addr    =~ s|/cgi-bin/remote.cgi$||mx;
        my $error = defined $c->stash->{'backend_detail'}->{$key}->{'last_error'} ? $c->stash->{'backend_detail'}->{$key}->{'last_error'} : '';
        chomp($error);
        push @data, {
            Key     => $key,
            Section => $peer->{'section'},
            Name    => $c->stash->{'backend_detail'}->{$key}->{'name'},
            Enabled => (!defined $peer->{'hidden'} || $peer->{'hidden'} == 0) ? 'Yes' : 'No',
            Address => $addr,
            Status  => $error || 'OK',
        };
    }
    my $output = Thruk::Utils::text_table(
        keys => ['Name', 'Section', 'Key', 'Enabled', 'Address', 'Status'],
        data => \@data,
    );
    return($output, 0);
}

##############################################

=head1 EXAMPLES

Display all available backends

  %> thruk backend list

=cut

##############################################

1;
