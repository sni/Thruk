package Thruk::Utils::CLI::Service;

=head1 NAME

Thruk::Utils::CLI::Service - Service CLI module

=head1 DESCRIPTION

The service command lists services from livestatus queries.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] service [<host>]

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
    my($c, undef, $options) = @_;
    my $output = '';
    my $hostfilter = [];
    my $hostname = $options->[0] || '';
    if(!$hostname || ($hostname ne 'list' && $hostname ne 'help')) {
        $hostfilter = [{ host_name => $hostname }];
    }
    my $uniq = {};
    for my $svc (@{$c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $hostfilter], sort => {'ASC' => [ 'host_name', 'description' ] })}) {
        my $name;
        if($hostname) {
            $name = $svc->{'description'};
        } else {
            $name = $svc->{'host_name'}.";".$svc->{'description'};
        }
        $output .= $name."\n" unless $uniq->{$name};
        $uniq->{$name} = 1;
    }
    return($output, 0);
}

##############################################

=head1 EXAMPLES

List all services for host localhost

  %> thruk service localhost

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
