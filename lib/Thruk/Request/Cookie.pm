package Thruk::Request::Cookie;

use warnings;
use strict;

=head1 NAME

Thruk::Request::Cookie - Wrapper for request cookies

=head1 SYNOPSIS

  use Thruk::Request;

=head1 DESCRIPTION

C<Thruk::Request> Request wrapper

=head1 METHODS

=head2 new

    new()

return new request object

=cut
sub new {
    my($class, $value) = @_;
    my $self = {
        value => $value,
    };
    bless($self, $class);
    return($self);
}

=head2 value

    value()

return value of this cookie

=cut
sub value {
    my($self) = @_;
    return($self->{'value'});
}

1;
