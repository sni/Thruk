package Thruk::Utils::CLI::Service;

=head1 NAME

Thruk::Utils::CLI::Service - Service CLI module

=head1 DESCRIPTION

The service command lists services from livestatus queries.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] service <cmd>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<cmd>

    available commands are:

    - list          lists all services

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
    for my $svc (@{$c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' )], sort => {'ASC' => [ 'host_name', 'description' ] })}) {
        $output .= $svc->{'host_name'}.";".$svc->{'description'}."\n";
    }
    return($output, 0);
}

##############################################

=head1 EXAMPLES

Run all selfchecks

  %> thruk service list

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
