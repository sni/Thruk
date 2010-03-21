package Catalyst::View::GD;

use strict;
use warnings;

use Class::C3::Adopt::NEXT -no_warn;
use Scalar::Util 'blessed';

use Catalyst::Exception;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use base 'Catalyst::View';

__PACKAGE__->mk_accessors(qw[
    gd_image_type
    gd_image_content_type
    gd_image_render_args
]);

sub new {
    my($class, $c, $args) = @_;
    my $self = $class->NEXT::new($c, $args);

    eval {
        require("GD.pm");
        GD->import;
    };
    if($@) {
        $c->log->error("error loading gd, did you forget to install libgd, libxml or GD.pm?\n".$@);
    }

    my $config = $c->config->{'View::GD'};

    $args->{gd_image_type}         ||= $config->{gd_image_type}         || 'gif';
    $args->{gd_image_content_type} ||= $config->{gd_image_content_type} || ('image/' . $args->{gd_image_type});
    $args->{gd_image_render_args}  ||= $config->{gd_image_render_args}  || [];

    $self->gd_image_type($args->{gd_image_type});
    $self->gd_image_content_type($args->{gd_image_content_type});
    $self->gd_image_render_args($args->{gd_image_render_args});

    return $self;
}

sub process {
    my $self = shift;
    my $c    = shift;
    my @args = @_;

    my $gd_image_type         = $c->stash->{gd_image_type}         || $self->gd_image_type;
    my $gd_image_content_type = $c->stash->{gd_image_content_type} || $self->gd_image_content_type;
    my $gd_image_render_args  = $c->stash->{gd_image_render_args}  || $self->gd_image_render_args;

    my $gd_image = $c->stash->{gd_image};

    (defined $gd_image)
        || die "No image to render";

    (blessed $gd_image && $gd_image->isa('GD::Image'))
        || die "Bad image ($gd_image), must be an instance of GD::Image";

    my $render_method = $gd_image->can($gd_image_type);

    (defined $render_method)
        || die "Cannot render '$gd_image_type' for '$gd_image' : no '$gd_image_type' available";

    my $img = eval {
        $gd_image->$render_method(@{$self->gd_image_render_args})
    };
    if ($@) {
        die "Failed to render '$gd_image' as '$gd_image_type' because: $@";
    }

    $c->response->content_type($gd_image_content_type);
    $c->response->body($img);
    return 1;
}

1;

__END__

=pod

=head1 NAME

Catalyst::View::GD - A Catalyst View for GD images

=head1 SYNOPSIS

  # lib/MyApp/View/GD.pm
  package MyApp::View::GD;
  use base 'Catalyst::View::GD';
  1;

  # configure in lib/MyApp.pm
  MyApp->config({
      ...
      'View::GD' => {
          gd_image_type         => 'png',        # defaults to 'gif'
          gd_image_content_type => 'images/png', # defaults to 'image/$gd_image_type'
          gd_image_render_args  => [ 5 ],        # defaults to []
      },
  });

  sub foo : Local {
      my($self, $c) = @_;
      $c->stash->{gd_image} = $self->create_foo_image();
      $c->forward('MyApp::View::GD');
  }

=head1 DESCRIPTION

This is a Catalyst View subclass which can handle rendering GD based
image content.

=head1 CONFIG OPTIONS

=over 4

=item I<gd_image_type>

This defaults to C<gif> but should be the name of the method to call on the
GD::Image instance in order to render the images.

=item I<gd_image_render_args>

This is an array ref of values to be passed as an argument to the GD::Image
render method.

=item I<gd_image_content_type>

The default for this is built from the C<gd_image_type> parameter, which in
most cases will just work, but in some more specific rendering methods in
GD::Image it will not and you will need to assign this explicitly.

=back

=head1 METHODS

=over 4

=item B<new>

This really just handles consuming the configuration parameters.

=item B<process>

This method will always look in the C<gd_image> stash for an instance of
GD::Image and it will then render and serve it according to the
configuration setup.

It is also possible to override the global configuration on a per-request
basis by assigning values in the stash using the same keys as used in
the configuration.

=back

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 AUTHOR

Stevan Little E<lt>stevan.little@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
