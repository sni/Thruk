package Thruk::Utils::Livestatus;

use strict;
use warnings;
use Carp;
use Data::Dumper;

=head1 NAME

Thruk::Utils::Livestatus - Utils for livestatus

=head1 DESCRIPTION

Utils for Livestatus

=head1 METHODS

=head2 new

create new livestatus helper

########################################

=head2 get_livestatus_conf

  get_livestatus_conf()

returns config for livestatus backends

=cut
sub get_livestatus_conf {
    my $self = shift;

    my $livestatus_config = Thruk->config->{'Monitoring::Livestatus'};

    if(defined $livestatus_config) {
        # with only on peer, we have to convert to an array
        if(defined $livestatus_config->{'peer'} and ref $livestatus_config->{'peer'} eq 'HASH') {
            my $peer = $livestatus_config->{'peer'};
            delete $livestatus_config->{'peer'};
            push @{$livestatus_config->{'peer'}}, $peer;
        }
    }

    return($livestatus_config);
}

########################################

=head2 convert_config

  convert_config()

returns the converted config for livestatus backends

=cut
sub convert_config {
    my $config = shift;

    my $new_conf = "<Component Thruk::Backend>\n";
    for my $peer (@{$config->{'peer'}}) {
        $new_conf .= "  <peer>\n";
        $new_conf .= "    name   = ".$peer->{'name'}."\n";
        $new_conf .= "    type   = livestatus\n";
        $new_conf .= "    <options>\n";
        $new_conf .= "      peer   = ".$peer->{'peer'}."\n";
        $new_conf .= "    </options>\n";
        $new_conf .= "  </peer>\n";
    }
    $new_conf .= "</Component>\n";
    return $new_conf;
}


=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
