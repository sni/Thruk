package Thruk::Utils::CLI::R;

=head1 NAME

Thruk::Utils::CLI::R - Rest API CLI module

=head1 DESCRIPTION

The r command is an alias for the rest command.

=cut

use warnings;
use strict;

##############################################

=head1 METHODS

=head2 cmd

    cmd(...)

=cut
sub cmd {
    require Thruk::Utils::CLI::Rest;
    return(Thruk::Utils::CLI::Rest::cmd(@_));
}

##############################################

1;
