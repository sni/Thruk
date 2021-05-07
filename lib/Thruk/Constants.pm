package Thruk::Constants;

=head1 NAME

Thruk::Constants - Defines all constants

=head1 DESCRIPTION

defines global constants

=head1 METHODS

=cut

use warnings;
use strict;
use Exporter qw( import );

use constant qw( );

our @EXPORT_OK;
our %EXPORT_TAGS;

###################################################
# peer states used on initial backends and sites
my %peer_states = (
    REACHABLE        => 0,
    UNREACHABLE      => 1,
    HIDDEN_USER      => 2,
    HIDDEN_PARAM     => 3,
    DISABLED_AUTH    => 4,

    DISABLED_CONF    => 5,  # site has no backend config at all
    HIDDEN_CONF      => 6,  # site has backend config but is not selected
    UP_CONF          => 7,  # site has backend config and is currently selected

    HIDDEN_LMD_PARENT => 8,
);

push @EXPORT_OK, keys(%peer_states);
constant->import(\%peer_states);
$EXPORT_TAGS{peer_states} = [keys %peer_states];

###################################################
# available AddDefaults variants
my %add_defaults = (
    ADD_DEFAULTS        => 0,
    ADD_SAFE_DEFAULTS   => 1,
    ADD_CACHED_DEFAULTS => 2,
);

push @EXPORT_OK, keys(%add_defaults);
constant->import(\%add_defaults);
$EXPORT_TAGS{add_defaults} = [keys %add_defaults];

###################################################

=head1 SEE ALSO

L<Thruk>

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

Thruk is Copyright (c) 2009-2019 by Sven Nierlein and others.
This is free software; you can redistribute it and/or modify it under the
same terms as the Perl5 programming language system
itself.

=cut

1;
