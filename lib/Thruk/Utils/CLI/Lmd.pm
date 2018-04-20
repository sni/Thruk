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
    - status       displays status of lmd process

=back

=cut

use warnings;
use strict;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions) = @_;
    $c->stats->profile(begin => "_cmd_lmd($action)");

    if(scalar @{$commandoptions} == 0) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }
    my $mode = shift @{$commandoptions};

    Thruk::Backend::Pool::init_backend_thread_pool();

    if($mode eq 'start') {
        Thruk::Utils::LMD::check_procs($c->config, $c, 0, 1);
        # wait for the startup
        my($status, $started);
        for(my $x = 0; $x <= 20; $x++) {
            eval {
                ($status, $started) = Thruk::Utils::LMD::status($c->config);
            };
            last if($status && scalar @{$status} == $started);
            sleep(1);
        }
        return("OK - lmd started\n", 0) if(defined $started and $started > 0);
        return("FAILED - starting lmd failed\n", 1);
    }
    elsif($mode eq 'stop') {
        Thruk::Utils::LMD::shutdown($c->config);
        # wait for the fully stopped
        my($status, $started, $total, $failed);
        for(my $x = 0; $x <= 20; $x++) {
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
            sleep(1);
        }
    }
    elsif($mode eq 'restart') {
        Thruk::Utils::LMD::restart($c, $c->config);
        # wait for the startup
        my($status, $started);
        for(my $x = 0; $x <= 20; $x++) {
            eval {
                ($status, $started) = Thruk::Utils::LMD::status($c->config);
            };
            last if($status && scalar @{$status} == $started);
            sleep(1);
        }
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

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
