package Thruk::Utils::CLI::Servicegroup;

=head1 NAME

Thruk::Utils::CLI::Servicegroup - Servicegroup CLI module

=head1 DESCRIPTION

The servicegroup command lists hosts from livestatus queries.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] servicegroup <cmd>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<cmd>

    available commands are:

    - list          lists all servicegroups

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
    for my $group (@{$c->{'db'}->get_servicegroups(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'servicegroups' )], sort => {'ASC' => 'name'})}) {
        $output .= sprintf("%-30s %s\n", $group->{'name'}, join(', ', map({ join(";", @{$_}) } @{$group->{'members'}}) ) );
    }
    return($output, 0);
}

##############################################

=head1 EXAMPLES

List all servicegroups

  %> thruk servicegroup list

=cut

##############################################

1;
