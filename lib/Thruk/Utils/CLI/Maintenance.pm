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
use Thruk::Utils::Log qw/:all/;
use Thruk::Utils::CookieAuth;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action) = @_;
    $c->stats->profile(begin => "_cmd_maintenance($action)");

    if(!$c->check_user_roles('authorized_for_admin')) {
        return("ERROR - authorized_for_admin role required", 1);
    }

    Thruk::Utils::CookieAuth::clean_session_files($c);

    $c->stats->profile(end => "_cmd_maintenance($action)");
    return("maintenance complete\n", 0);
}

##############################################

1;
