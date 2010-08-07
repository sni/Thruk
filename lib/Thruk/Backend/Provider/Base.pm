package Thruk::Backend::Provider::Base;

use strict;
use warnings;
use Carp;

=head1 NAME

Thruk::Backend::Provider::Base - Base class for backend connection provider

=head1 DESCRIPTION

Base class for backend connection provider

=head1 METHODS

=cut
##########################################################

=head2 new

create new manager

=cut
sub new {
    my( $class, $c ) = @_;
    my $self = {};
    bless $self, $class;
    return $self;
}

##########################################################

=head2 peer_key

return the peers key

=cut
sub peer_key {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 peer_addr

return the peers address

=cut
sub peer_addr {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_processinfo

return the process info

=cut
sub get_processinfo {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_can_submit_commands

returns if this user is allowed to submit commands

=cut
sub get_can_submit_commands {
    my $self = shift;
    confess("unimplemented");
}

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
