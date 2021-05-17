package Thruk::Utils::CLI::R;

=head1 NAME

Thruk::Utils::CLI::R - Rest API CLI module

=head1 DESCRIPTION

The r command is an alias for the rest command.

=cut

use warnings;
use strict;

use Thruk::Utils::CLI::Rest ();

our $skip_backends = \&Thruk::Utils::CLI::Rest::_skip_backends;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
*cmd = *Thruk::Utils::CLI::Rest::cmd;

##############################################

1;
