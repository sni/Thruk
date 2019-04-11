package Thruk::Utils::CLI::Maintainance;

=head1 NAME

Thruk::Utils::CLI::Maintainance - Maintainance CLI module

=head1 DESCRIPTION

The maintainance command performs regular maintainance jobs like

    - cleaning old session files

=head1 SYNOPSIS

  Usage: thruk [globaloptions] maintainance

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
    $c->stats->profile(begin => "_cmd_maintainance($action)");

    Thruk::Utils::CookieAuth::clean_session_files($c->config);

    $c->stats->profile(end => "_cmd_maintainance($action)");
    return("maintainance complete\n", 0);
}

##############################################

1;
