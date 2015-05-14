package Thruk::Views::ExcelRenderer;

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

=head2 render_excel

    $c->render_excel()

=cut
sub render_excel {
    my($c) = @_;
    my $template = $c->stash->{'template'};
    $c->stats->profile(begin => "render_excel: ".$template);
    my $output = render($c, $template);
    $c->{'rendered'} = 1;
    $c->res->content_type('application/x-msexcel');
    $c->res->body($output);
    $c->stats->profile(end => "render_excel: ".$template);
    return($output);
}

=head2 render

    render template and return output

=cut
sub render {
    my($c, $template) = @_;
    $c->stats->profile(begin => "render: ".$template);
    my $worksheets = Thruk::Views::ToolkitRenderer::render($c, $template);
    require IO::String;
    require Excel::Template;
    my $fh = IO::String->new($worksheets);
    $fh->pos(0);

    my $excel_template = eval { Excel::Template->new(file => $fh) };
    if($@) {
        warn $$worksheets;
        confess $@;
    }
    my $output = ''.$excel_template->output;
    $c->stats->profile(end => "render: ".$template);
    return($output);
}

1;
__END__

=head1 SYNOPSIS

    $c->render_excel();

=head1 DESCRIPTION

This module renders L<use Excel::Template> data.

=head1 SEE ALSO

L<Excel::Template>.

=cut
