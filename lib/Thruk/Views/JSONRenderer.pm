package Thruk::Views::JSONRenderer;

=head1 NAME

Thruk::Views::JSONRenderer - Render JSON data

=head1 DESCRIPTION

JSON data renderer

=cut

use strict;
use warnings;
use Carp qw/confess/;
use JSON::XS ();

=head1 METHODS

=head2 register

    register this renderer

=cut
sub register {
    return;
}

=head2 render_json

    $c->render_json($data)

=cut
sub render_json {
    my($c, $data) = @_;
    $c->stats->profile(begin => "render_json");
    my $encoder = $c->app->{'jsonencoder'} || _get_encoder($c);
    my $output = $encoder->encode($data);
    $c->{'rendered'} = 1;
    $c->res->content_type('application/json;charset=UTF-8');
    $c->res->body($output);
    $c->stats->profile(end => "render_json");
    return($output);
}

sub _get_encoder {
    my($c) = @_;
    $c->app->{'jsonencoder'} =
        JSON::XS->new
                ->ascii
                ->pretty
                ->canonical             # sort hash keys, breaks panorama if not set
                ->allow_blessed
                ->allow_nonref;
    return($c->app->{'jsonencoder'});
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
