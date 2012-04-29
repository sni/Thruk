package Thruk::View::PDF::Reuse;

use strict;
use File::Spec::Functions qw/catfile rel2abs/;
use File::Temp qw/tmpnam/;
use PDF::Reuse;
use base 'Catalyst::View::PDF::Reuse';

=head1 NAME

Thruk::View::PDF::Reuse - PDF::Reuse View for Thruk

=head1 DESCRIPTION

PDF::Reuse View for Thruk.

=head1 METHODS

=head2 render_pdf

  set additional template paths

  otherwise only INCLUDE_PATH would be searched

=cut
sub render_pdf {
    my ($self, $c) = @_;

    my $template = <<'EOT';
    [% USE pdf = Catalyst::View::PDF::Reuse %]
    [% USE barcode = Catalyst::View::PDF::Reuse::Barcode %]
    [% PROCESS $pdf_template %]
EOT

    my $tempfile = tmpnam();
    prInitVars();
    prFile($tempfile);

    my $output;
    for my $path (@{$c->stash->{additional_template_paths}}, @{$self->config->{INCLUDE_PATH}}) {
        $path = rel2abs($path);
        if (-e catfile($path,$c->stash->{pdf_template})) {
            $output = $self->render($c,\$template);
            last;
        }
    }

    prEnd();

    my $pdf;
    local $/ = undef;
    open my $fh,'<',$tempfile;
    $pdf = (<$fh>);
    close $fh;
    unlink $tempfile;

    return (UNIVERSAL::isa($output, 'Template::Exception')) ? $output : $pdf;
}

=head1 AUTHOR

Sven Nierlein, 2012, <sven.nierlein@consol.de>

=head1 SEE ALSO

L<Thruk>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
