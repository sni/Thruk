package Thruk::Utils::CLI::Nc;

=head1 NAME

Thruk::Utils::CLI::Nc - Node Control CLI module

=head1 DESCRIPTION

The nc command is an alias for the nodecontrol command.

=cut

use warnings;
use strict;

use Thruk::Utils::CLI::Nodecontrol ();

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
*cmd = *Thruk::Utils::CLI::Nodecontrol::cmd;

##############################################

1;
