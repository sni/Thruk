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

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
