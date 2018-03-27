package Thruk::Views::ToolkitRenderer;

=head1 NAME

Thruk::Views::ToolkitRenderer - Render TT templates

=head1 DESCRIPTION

TT template renderer

=cut

use strict;
use warnings;
use Carp qw/confess/;
use Template ();
use Time::HiRes qw/gettimeofday tv_interval/;

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
    my $t1 = [gettimeofday];
    my $template = $c->stash->{'template'};
    $c->stats->profile(begin => "render_tt: ".$template);
    my $output;
    render($c, $template, undef, \$output);
    $c->{'rendered'} = 1;
    $c->res->content_type('text/html; charset=utf-8') unless $c->res->content_type();
    $c->res->body($output);
    $c->stats->profile(end => "render_tt: ".$template);
    my $elapsed = tv_interval($t1);
    $c->stash->{'total_render_waited'} += $elapsed;
    return;
}

=head2 render

    render template and return output

=cut
sub render {
    my($c, $template, $stash, $output) = @_;
    my $tt = $c->app->{'tt'};
    confess("no template") unless $template;
    $c->stats->profile(begin => "render: ".$template);

    if($c->stash->{'additional_template_paths'}) {
        $tt->context->{'LOAD_TEMPLATES'}->[0]->{'INCLUDE_PATH'} =
            [ @{$c->stash->{'additional_template_paths'}},
                $c->config->{'View::TT'}->{'INCLUDE_PATH'},
            ];
    }

    $tt->process(
        $template,
        ($stash || $c->stash),
        $output,
    ) || do {
        die($tt->error.' on '.$template);
    };
    $c->stats->profile(end => "render: ".$template);
    if($output) {
        ${$output} =~ s/^\s+//sgmxo unless $c->stash->{no_tt_trim};
        my $ctype = $c->res->headers->content_type || '';
        if($ctype !~ m|^image/|mx) {
            utf8::encode(${$output});
        }
    }
    return;
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
