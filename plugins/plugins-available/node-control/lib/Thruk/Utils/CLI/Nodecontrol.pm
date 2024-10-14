package Thruk::Utils::CLI::Nodecontrol;

=head1 NAME

Thruk::Utils::CLI::Nodecontrol - NodeControl CLI module

=head1 DESCRIPTION

The nodecontrol command can start node control commands.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] nc <cmd> [-w|--worker=<nr>]

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<cmd>

    available commands are:

    - facts   <backendid|all>             update facts for given backend.
    - runtime <backendid|all>             update runtime data for given backend.

=back

=cut

use warnings;
use strict;
use Getopt::Long ();

use Thruk::Utils ();
use Thruk::Utils::CLI ();
use Thruk::Utils::Log qw/:all/;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions, $data, $src, $global_options) = @_;
    $c->stats->profile(begin => "_cmd_nc()");

    if(!$c->check_user_roles('authorized_for_admin')) {
        return("ERROR - authorized_for_admin role required", 1);
    }

    if(scalar @{$commandoptions} == 0) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    eval {
        require Thruk::NodeControl::Utils;
    };
    if($@) {
        _debug($@);
        return("node control plugin is not enabled.\n", 1);
    }

    my $config = Thruk::NodeControl::Utils::config($c);
    # parse options
    my $opt = {
      'worker' => $config->{'parallel_tasks'} // 3,
    };
    Getopt::Long::Configure('no_ignore_case');
    Getopt::Long::Configure('bundling');
    Getopt::Long::Configure('pass_through');
    Getopt::Long::GetOptionsFromArray($commandoptions,
       "w|worker=i"     => \$opt->{'worker'},
    ) or do {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    };

    my $mode = shift @{$commandoptions};
    my($output, $rc) = ("", 0);

    if($mode eq 'facts' || $mode eq 'runtime') {
        my $peers = [];
        my $backend = shift @{$commandoptions};
        if($backend && $backend ne 'all') {
            my $peer = $c->db->get_peer_by_key($backend);
            if(!$peer) {
                _fatal("no such peer: ".$backend);
            }
            push @{$peers}, $backend;
        } else {
            for my $peer (@{Thruk::NodeControl::Utils::get_peers($c)}) {
                push @{$peers}, $peer->{'key'};
            }
        }

        _scale_peers($c, $opt->{'worker'}, $peers, sub {
            my($peer_key) = @_;
            my $peer = $c->db->get_peer_by_key($peer_key);
            my $facts;
            if($mode eq 'facts') {
                $facts = Thruk::NodeControl::Utils::ansible_get_facts($c, $peer, 1);
            }
            if($mode eq 'runtime') {
                $facts = Thruk::NodeControl::Utils::update_runtime_data($c, $peer, 1);
                if(!$facts->{'ansible_facts'}) {
                    $facts = Thruk::NodeControl::Utils::ansible_get_facts($c, $peer, 1);
                }
            }
            if(!$facts || $facts->{'last_error'} || $facts->{'last_facts_error'}) {
                my $err = sprintf("%s updating %s failed: %s\n", $peer->{'name'}, $mode, ($facts->{'last_facts_error'}||$facts->{'last_error'}//'unknown error'));
                if($ENV{'THRUK_CRON'}) {
                    _warn($err); # don't fill the log with errors from cronjobs
                } else {
                    _error($err);
                }
            } else {
                _info("%s updated %s sucessfully: OK\n", $peer->{'name'}, $mode);
            }
        });
        return("", 0);
    } else {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    $c->stats->profile(end => "_cmd_nc()");
    return($output, $rc);
}

##############################################
sub _scale_peers {
    my($c, $workernum, $peers, $sub) = @_;
    Thruk::Utils::scale_out(
        scale  => $workernum,
        jobs   => $peers,
        worker => $sub,
        collect => sub {},
    );
    return;
}

##############################################

=head1 EXAMPLES

Update facts for specific backend.

  %> thruk nc facts backendid

=cut

##############################################

1;
