package Thruk::Utils::CLI::Contact;

=head1 NAME

Thruk::Utils::CLI::Contact - Contact CLI module

=head1 DESCRIPTION

The contact command lists contacts from livestatus queries.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] contact <cmd>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<cmd>

    available commands are:

    - list          lists all contacts

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
    my $uniq = {};
    for my $contact (@{$c->{'db'}->get_contacts(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'contacts' )], sort => {'ASC' => 'name'})}) {
        $output .= $contact->{'name'}."\n" unless $uniq->{$contact->{'name'}};
        $uniq->{$contact->{'name'}} = 1;
    }
    return($output, 0);
}

##############################################

=head1 EXAMPLES

List all contacts

  %> thruk contact list

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
