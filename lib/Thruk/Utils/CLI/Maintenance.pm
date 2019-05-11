package Thruk::Utils::CLI::Maintenance;

=head1 NAME

Thruk::Utils::CLI::Maintenance - Maintenance CLI module

=head1 DESCRIPTION

The maintenance command performs regular maintenance jobs like

    - cleaning old session files

=head1 SYNOPSIS

  Usage: thruk [globaloptions] maintenance

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=back

=cut

use warnings;
use strict;
use Thruk::Utils::Log qw/_error _info _debug _trace/;
use Thruk::Utils::CookieAuth;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action) = @_;
    $c->stats->profile(begin => "_cmd_maintenance($action)");

    Thruk::Utils::CookieAuth::clean_session_files($c->config);

    $c->stats->profile(end => "_cmd_maintenance($action)");
    return("maintenance complete\n", 0);
}

##############################################

1;
