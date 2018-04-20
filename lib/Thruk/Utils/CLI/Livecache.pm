package Thruk::Utils::CLI::Livecache;

=head1 NAME

Thruk::Utils::CLI::Livecache - Livecache CLI module

=head1 DESCRIPTION

The livecache command is deprecated and replaced by the lmd command

=cut

use warnings;
use strict;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    require Thruk::Utils::CLI::Lmd;
    return(Thruk::Utils::CLI::Lmd::cmd(@_));
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
