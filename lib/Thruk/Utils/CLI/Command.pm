package Thruk::Utils::CLI::Command;

=head1 NAME

Thruk::Utils::CLI::Command - Command CLI module

=head1 DESCRIPTION

The command command displays the expanded command for a given host or service

=head1 SYNOPSIS

  Usage: thruk [globaloptions] command <hostname> [<service_description>]

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

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
    my($c, $action, $commandoptions, undef, undef, $global_options) = @_;

    $c->stats->profile(begin => "_cmd_command($action)");
    my $hostname    = shift @{$commandoptions};
    my $description = shift @{$commandoptions};

    return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__)) unless $hostname;

    my $backend = $global_options->{'backends'}->[0] || '';
    my($host, $service);

    my $hosts = $c->{'db'}->get_hosts( filter => [ { 'name' => $hostname } ] );
    $host = $hosts->[0];
    # we have more and backend param is used
    if( scalar @{$hosts} == 1 and defined $backend ) {
        for my $h ( @{$hosts} ) {
            if( $h->{'peer_key'} eq $backend ) {
                $host = $h;
                last;
            }
        }
    }
    if(!$host) {
        return("no such host '".$hostname."'\n", 1);
    }

    if($description) {
        my $services = $c->{'db'}->get_services( filter => [{ 'host_name' => $hostname }, { 'description' => $description }, ] );
        $service = $services->[0];
        # we have more and backend param is used
        if( scalar @{$services} == 1 and defined $services ) {
            for my $s ( @{$services} ) {
                if( $s->{'peer_key'} eq $backend ) {
                    $service = $s;
                    last;
                }
            }
        }
        if(!$service) {
            return("no such service '".$description."' on host '".$hostname."'\n", 1);
        }
    }

    my $command = $c->{'db'}->expand_command('host' => $host, 'service' => $service, 'source' => $c->config->{'show_full_commandline_source'} );
    my $msg;
    $msg .= 'Note:             '.$command->{'note'}."\n" if $command->{'note'};
    $msg .= 'Check Command:    '.$command->{'line'}."\n";
    $msg .= 'Expanded Command: '.$command->{'line_expanded'}."\n";

    $c->stats->profile(end => "_cmd_command($action)");
    return($msg, 0);
}

##############################################

=head1 EXAMPLES

Display expanded command for test service on host localhost

  %> thruk command localhost test

Submitting external commands is possible via the 'url' command. See 'thruk url help' for some examples.

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
