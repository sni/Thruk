package Thruk::Views::ToolkitRenderer;

use strict;
use warnings;
use Carp qw/confess/;
use Template ();
use Encode qw/encode_utf8 decode_utf8/;

=head1 METHODS

=head2 register

    register this renderer

=cut
sub register {
    my($app, $settings) = @_;
    $app->{'tt'} = Template->new($settings->{'config'});
    return;
}

=head2 render_tt

    do the rendering

=cut
sub render_tt {
    my($c) = @_;
    my $template = $c->stash->{'template'};
    $c->stats->profile(begin => "render_tt: ".$template);
    my $output = render($c, $template);
    $c->{'rendered'} = 1;
    $c->res->content_type('text/html; charset=utf-8') unless $c->res->content_type();
    $c->res->body($output);
    $c->stats->profile(end => "render_tt: ".$template);
    return($output);
}

=head2 render

    render template and return output

=cut
sub render {
    my($c, $template) = @_;
    my $tt = $c->app->{'tt'};
    $c->stats->profile(begin => "render: ".$template);

    if($c->stash->{'additional_template_paths'}) {
        $tt->context->{'LOAD_TEMPLATES'}->[0]->{'INCLUDE_PATH'} =
            [ @{$c->stash->{'additional_template_paths'}},
                $c->config->{'View::TT'}->{'INCLUDE_PATH'},
            ];
    }

    my $output = "";
    $tt->process(
        $template,
        $c->stash,
        \$output,
    ) || do {
        die($tt->error.' on '.$template);
    };
    $c->stats->profile(end => "render: ".$template);
    return(encode_utf8($output));
}

1;
__END__

=head1 SYNOPSIS

    $c->render_tt()

=head1 DESCRIPTION

This module renders L<Template> Toolkit templates.

=head1 SEE ALSO

L<Template>

=cut
