package Thruk::Utils::CLI::Hostgroup;

=head1 NAME

Thruk::Utils::CLI::Hostgroup - Hostgroup CLI module

=head1 DESCRIPTION

The host command lists hosts from livestatus queries.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] hostgroup <cmd>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<cmd>

    available commands are:

    - list          lists all hostgroups

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
    for my $group (@{$c->{'db'}->get_hostgroups(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' )], sort => {'ASC' => 'name'})}) {
        $output .= sprintf("%-30s %s\n", $group->{'name'}, join(', ', @{$group->{'members'}}));
    }
    return($output, 0);
}

##############################################

=head1 EXAMPLES

List all hostgroups

  %> thruk hostgroup list

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
