package Thruk::Utils::CLI::Lmd;

=head1 NAME

Thruk::Utils::CLI::Lmd - LMD CLI module

=head1 DESCRIPTION

The lmd command controls the LMD process.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] lmd <cmd>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<cmd>

    available commands are:

    - start        starts the lmd process
    - stop         stops the lmd process
    - restart      restart the lmd process
    - reload       send sighup to lmd process
    - status       displays status of lmd process
    - config       write lmd config file

=back

=cut

use warnings;
use strict;
use Time::HiRes ();

use Thruk::Utils::CLI ();
use Thruk::Utils::LMD ();

our $skip_backends = 1;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions) = @_;
    $c->stats->profile(begin => "_cmd_lmd($action)");

    if(!$c->check_user_roles('authorized_for_admin')) {
        return("ERROR - authorized_for_admin role required", 1);
    }

    if(scalar @{$commandoptions} == 0) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }
    my $mode = shift @{$commandoptions};

    if($mode eq 'start') {
        my($status, $started) = Thruk::Utils::LMD::status($c->config);
        if($started && $status->[0] && $status->[0]->{'pid'}) {
            return("FAILED - lmd already running with pid ".$status->[0]->{'pid'}."\n", 1);
        }
        my $pid = Thruk::Utils::LMD::check_proc($c->config, $c, 0);
        # wait for the startup
        if($pid) {
            for(my $x = 0; $x <= 200; $x++) {
                eval {
                    ($status, $started) = Thruk::Utils::LMD::status($c->config);
                };
                last if($status && scalar @{$status} == $started);
                Time::HiRes::sleep(0.1);
            }
            return("OK - lmd started\n", 0) if(defined $started and $started > 0);
        }
        return("FAILED - starting lmd failed\n", 1);
    }
    elsif($mode eq 'stop') {
        Thruk::Utils::LMD::shutdown_procs($c->config);
        # wait for the fully stopped
        my($status, $started, $total, $failed);
        for(my $x = 0; $x <= 200; $x++) {
            eval {
                ($status, $started) = Thruk::Utils::LMD::status($c->config);
                if($c->config->{'use_lmd_core'}) {
                    if(scalar @{$status} == 1 && $status->[0]->{'status'} == 0) {
                        $total = 1;
                        $failed = 1;
                    }
                }
            };
            last if(defined $started && $started == 0 && defined $total && $total == $failed);
            Time::HiRes::sleep(0.1);
        }
    }
    elsif($mode eq 'reload') {
        if(Thruk::Utils::LMD::reload($c->config)) {
            return("OK - lmd reload successful.\n", 0);
        }
        return("CRITICAL - unable to reload lmd. Is lmd running?\n", 2);
    }
    elsif($mode eq 'restart') {
        Thruk::Utils::LMD::restart($c, $c->config);
        # wait for the startup
        my($status, $started);
        for(my $x = 0; $x <= 200; $x++) {
            eval {
                ($status, $started) = Thruk::Utils::LMD::status($c->config);
            };
            last if($status && scalar @{$status} == $started);
            Time::HiRes::sleep(0.1);
        }
    }
    elsif($mode eq 'config') {
        if(Thruk::Utils::LMD::write_lmd_config($c, $c->config)) {
            return("OK - new lmd config written (but not yet activated, run 'thruk lmd reload')\n", 0);
        }
        return("OK - lmd config did not change\n", 0);
    }

    my($status, $started) = Thruk::Utils::LMD::status($c->config);
    $c->stats->profile(end => "_cmd_lmd($action)");
    if(scalar @{$status} == 0) {
        return("UNKNOWN - lmd is disabled\n", 3);
    }
    if(scalar @{$status} == $started) {
        if($c->config->{'use_lmd_core'}) {
            return("OK - lmd running with pid ".$status->[0]->{'pid'}."\n", 0);
        }
    }
    if($started == 0) {
        return("STOPPED - $started lmd running\n", $mode eq 'stop' ? 0 : 2);
    }
    return("WARNING - $started/".(scalar @{$status})." lmd running\n", 1);
}

##############################################

=head1 EXAMPLES

Start lmd process if it isnt running

  %> thruk lmd start

=cut

##############################################

1;
