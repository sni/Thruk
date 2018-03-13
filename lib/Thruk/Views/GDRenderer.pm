package Thruk::Views::GDRenderer;

=head1 NAME

Thruk::Views::GDRenderer - Render GD files

=head1 DESCRIPTION

GD file renderer

=cut

use strict;
use warnings;
use Carp qw/confess/;
use Time::HiRes qw/gettimeofday tv_interval/;

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
    my $t1 = [gettimeofday];
    $c->stats->profile(begin => "render_gd");
    my $gd_image = $c->stash->{gd_image} or die('no gd_image found in stash');
    $c->res->content_type('image/png');
    my $output = $gd_image->png;
    $c->{'rendered'} = 1;
    $c->res->body($output);
    $c->stats->profile(end => "render_gd");
    my $elapsed = tv_interval($t1);
    $c->stash->{'total_render_waited'} += $elapsed;
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
