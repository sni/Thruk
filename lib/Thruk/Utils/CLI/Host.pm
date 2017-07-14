package Thruk::Utils::CLI::Host;

=head1 NAME

Thruk::Utils::CLI::Host - Host CLI module

=head1 DESCRIPTION

The host command lists hosts from livestatus queries.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] host <cmd>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<cmd>

    available commands are:

    - list          lists all hosts

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
    my($c) = @_;
    my $output = '';
    for my $host (@{$c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' )], sort => {'ASC' => 'name'})}) {
        $output .= $host->{'name'}."\n";
    }
    return($output, 0);
}

##############################################

=head1 EXAMPLES

Run all selfchecks

  %> thruk host list

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
