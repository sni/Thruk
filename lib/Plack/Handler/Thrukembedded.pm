package Plack::Handler::Thrukembedded;
use strict;
use warnings;
use base 'Plack::Handler::CGI';

sub _handle_response {
    my ($self, $res) = @_;

    $ENV{'HTTP_CODE'} = $res->[0];

    *STDOUT->autoflush(1);
    binmode STDOUT;


    my $body = $res->[2];
    my $cb = sub { print STDOUT $_[0]; };

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
    return;
}

package Plack::Handler::Thrukembedded::Writer;
sub new   { return bless \do { my $x }, $_[0] };
sub write { return print STDOUT $_[1] };
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


