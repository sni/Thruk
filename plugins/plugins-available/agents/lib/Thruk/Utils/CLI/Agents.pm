package Thruk::Utils::CLI::Agents;

=head1 NAME

Thruk::Utils::CLI::Agents - Agents CLI module

=head1 DESCRIPTION

The agents command handles agent configs.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] agents [cmd]

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<check>

    run checks, ex. inventory

=back

=cut

use warnings;
use strict;
use Time::HiRes qw/gettimeofday tv_interval/;

use Thruk::Utils::Agents ();
use Thruk::Utils::Auth ();
use Thruk::Utils::CLI ();
use Thruk::Utils::Log qw/:all/;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions, $data, $src, $global_options) = @_;
    $c->stats->profile(begin => "_cmd_agents()");

    if(!$c->check_user_roles('authorized_for_admin')) {
        return("ERROR - authorized_for_admin role required", 1);
    }

    if(scalar @{$commandoptions} == 0) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    my $output = "unknown command, see help for available commands";
    my $rc     = 3;

    if(scalar @{$commandoptions} >= 2) {
        $data->{'all_stdout'} = 1;
        if($commandoptions->[0] eq 'check' && $commandoptions->[1] eq 'inventory') {
            my $host = $commandoptions->[2] // '';
            ($output, $rc) = _check_inventory($c, $host);
        }
    }

    eval {
        require Thruk::Controller::agents;
    };
    if($@) {
        _debug($@);
        return("agents plugin is not enabled.\n", 1);
    }

    $c->stats->profile(end => "_cmd_agents()");
    return($output, $rc);
}

##############################################
sub _check_inventory {
    my($c, $host) = @_;
    if(!$host) {
        return("usage: $0 agents check inventory <host>\n", 3);
    }

    my $t1 = [gettimeofday];
    my $hosts = $c->db->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ),
                                            'custom_variables' => { '~' => 'AGENT .+' },
                                            'name' => $host,
                                            ],
    );
    if(!$hosts || scalar @{$hosts} == 0) {
        return(sprintf("UNKNOWN - no host found with enabled agent and name: \n".$host), 3);
    }

    my $hst    = $hosts->[0];
    Thruk::Utils::Agents::set_object_model($c, $hst->{'peer_key'});
    my $objects = $c->{'obj_db'}->get_objects_by_name('host', $host);
    if(!$objects || scalar @{$objects} == 0) {
        return(sprintf("UNKNOWN - no host found by name: \n".$host), 3);
    }
    my $hostobj = $objects->[0];

    my($inv, $err) = Thruk::Utils::Agents::update_inventory($c, $host, $hostobj);
    if($err) {
        return(sprintf("CRITICAL - updating inventory failed: %s\n", $err), 2);
    }
    my($checks, $num)  = Thruk::Utils::Agents::get_agent_checks_for_host($c, $host, $hostobj);

    my $elapsed  = tv_interval($t1);
    my $perfdata = sprintf("duration=%ss", $elapsed);
    if(scalar @{$checks->{'new'}} > 0) {
        my @details;
        for my $chk (@{$checks->{'new'}}) {
            push @details, " - ".$chk->{'name'};
        }
        return(sprintf("WARNING - %s new checks found|%s\n%s\n",
            scalar @{$checks->{'new'}},
            $perfdata,
            join("\n", @details),
        ), 2);
    }

    my @details;
    for my $chk (@{$checks->{'disabled'}}) {
        push @details, " - ".$chk->{'name'};
    }
    my $detail = "";
    if(scalar @details > 0) {
        $detail = "unwanted checks:\n".join("\n", @details);
    }
    return(sprintf("OK - inventory unchanged|%s\n%s\n", $perfdata, $detail), 0);
}

##############################################

=head1 EXAMPLES

Run inventory check for host localhost

  %> thruk check inventory localhost


See 'thruk agents help' for more help.

=cut

##############################################

1;
