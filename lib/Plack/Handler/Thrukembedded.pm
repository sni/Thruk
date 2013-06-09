package Plack::Handler::Thrukembedded;
use parent 'Plack::Handler::CGI';

use strict;
use warnings;

sub _handle_response {
    my ($self, $res) = @_;
    my %headers = @{$res->[1]};
    $ENV{'HTTP_RESULT'} = {
        headers => \%headers,
        code    => $res->[0],
    };
    my $result = '';

    my $body = $res->[2];
    my $cb = sub { $result .= $_[0]; };

    # inline Plack::Util::foreach here
    if (ref $body eq 'ARRAY') {
        for my $line (@$body) {
            $cb->($line) if length $line;
        }
    }
    elsif (defined $body) {
        local $/ = \65536 unless ref $/;
        while (defined(my $line = $body->getline)) {
            $cb->($line) if length $line;
        }
        $body->close;
    }
    else {
        return Plack::Handler::Thrukembedded::Writer->new;
    }
    $ENV{'HTTP_RESULT'}->{'result'} = $result;
    return;
}

package Plack::Handler::Thrukembedded::Writer;
sub new   { return bless \do { my $x }, $_[0] };
sub write { return $ENV{'HTTP_RESULT'}->{'result'} = $_[1] };
sub close { return; };

1;
__END__

=head1 NAME

Plack::Handler::Thrukembedded - Thruk handler for Plack

=head1 DESCRIPTION

This is a handler module to run the Thruk application as Plack handler.

=head1 SEE ALSO

L<Plack>

=cut
