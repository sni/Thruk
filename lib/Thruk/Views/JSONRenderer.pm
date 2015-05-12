package Thruk::Views::JSONRenderer;

use strict;
use warnings;
use Carp qw/confess/;
use JSON::XS ();

=head1 METHODS

=head2 register

    register this renderer

=cut
sub register {
    my($app) = @_;
    $app->{'jsonencoder'} = JSON::XS->new
                                    ->ascii
                                    ->pretty
                                    ->allow_blessed
                                    ->allow_nonref;
    return;
}

=head2 render_json

    $c->render_json($data)

=cut
sub render_json {
    my($c, $data) = @_;
    my $output = $c->app->{'jsonencoder'}->encode($data);
    $c->{'rendered'} = 1;
    $c->res->content_type('application/json;charset=UTF-8');
    $c->res->body($output);
    return($output);
}

1;
__END__

=head1 SYNOPSIS

    $c->render_json()

=head1 DESCRIPTION

This module renders L<JSON::XS> data.

=head1 SEE ALSO

L<JSON::XS>.

=cut
