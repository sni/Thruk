package Thruk::Utils::CLI::Livecache;

=head1 NAME

Thruk::Utils::CLI::Livecache - Livecache CLI module

=head1 DESCRIPTION

The livecache command is deprecated and replaced by the lmd command

=cut

use warnings;
use strict;

our $skip_backends = 1;

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

1;
