package Thruk::Views::GDRenderer;

use strict;
use warnings;
use Carp qw/confess/;

=head1 METHODS

=head2 register

    register this renderer

=cut
sub register {
    return;
}

=head2 render_gd

    $c->render_gd()

=cut
sub render_gd {
    my($c) = @_;
    $c->stats->profile(begin => "render_gd");
    my $gd_image = $c->stash->{gd_image} or die('no gd_image found in stash');
    $c->res->content_type('image/png');
    my $output = $gd_image->png;
    $c->{'rendered'} = 1;
    $c->res->body($output);
    $c->stats->profile(end => "render_gd");
    return($output);
}

1;
__END__

=head1 SYNOPSIS

    $c->render_gd();

=head1 DESCRIPTION

This module renders L<GD> data.

=head1 SEE ALSO

L<GD>.

=cut
