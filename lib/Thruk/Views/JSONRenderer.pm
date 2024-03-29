package Thruk::Views::JSONRenderer;

=head1 NAME

Thruk::Views::JSONRenderer - Render JSON data

=head1 DESCRIPTION

JSON data renderer

=cut

use warnings;
use strict;
use Cpanel::JSON::XS ();
use Time::HiRes qw/gettimeofday tv_interval/;

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
    my $t1 = [gettimeofday];
    $c->stats->profile(begin => "render_json");
    my $output = encode_json($c, $data);
    $c->{'rendered'} = 1;
    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body($output);
    $c->stats->profile(end => "render_json");
    my $elapsed = tv_interval($t1);
    $c->stash->{'total_render_waited'} += $elapsed;
    return($output);
}

=head2 encode_json

    $c->encode_json($data)

=cut
sub encode_json {
    my($c, $data) = @_;
    my $encoder = $c->app->{'jsonencoder'} || _get_encoder($c);
    return($encoder->encode($data));
}

sub _get_encoder {
    my($c) = @_;
    $c->app->{'jsonencoder'} =
        Cpanel::JSON::XS->new
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

This module renders L<Cpanel::JSON::XS> data.

=head1 SEE ALSO

L<Cpanel::JSON::XS>.

=cut
