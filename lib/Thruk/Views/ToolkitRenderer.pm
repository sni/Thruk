package Thruk::Views::ToolkitRenderer;

=head1 NAME

Thruk::Views::ToolkitRenderer - Render TT templates

=head1 DESCRIPTION

TT template renderer

=cut

use warnings;
use strict;
use Carp qw/confess/;
use Template ();
use Template::Provider ();
use Template::Stash ();
use Time::HiRes qw/gettimeofday tv_interval/;

use Thruk::Base ();
use Thruk::Config 'noautoload';

my $template_provider_user;

=head1 METHODS

=head2 register

    register this renderer

=cut
sub register {
    my($app) = @_;
    my $settings = Thruk::Config::get_toolkit_config();

    # set Template::Provider
    $settings->{'LOAD_TEMPLATES'} = [];

    if($app->config->{'thruk_author'}) {
        $settings->{'STRICT'}     = 1;
        $settings->{'CACHE_SIZE'} = 0 unless($app->config->{'demo_mode'} || Thruk::Base->mode eq 'TEST');
        $settings->{'STAT_TTL'}   = 1 unless($app->config->{'demo_mode'} || Thruk::Base->mode eq 'TEST');
    }

    # user template provider
    if($app->config->{'user_template_path'}) {
        # use short ttl, because folder is user writable
        my %custom_settings = (%{$settings}, (STAT_TTL => 30, INCLUDE_PATH => [$app->config->{'user_template_path'}]));
        $custom_settings{'STAT_TTL'} = $settings->{'STAT_TTL'} if $custom_settings{'STAT_TTL'} > $settings->{'STAT_TTL'};
        $template_provider_user = Template::Provider->new(\%custom_settings);
        push @{$settings->{'LOAD_TEMPLATES'}}, $template_provider_user;
    }

    # base template provider
    my %base_settings = (%{$settings}, (INCLUDE_PATH => [
        reverse @{$app->config->{'plugin_templates_paths'}},
        $app->config->{'base_templates_dir'},
    ]));
    push @{$settings->{'LOAD_TEMPLATES'}}, Template::Provider->new(\%base_settings);

    $app->{'tt'} = Template->new($settings);

    # make private _ hash keys available
    $Template::Stash::PRIVATE = undef;

    return($app->{'tt'});
}

=head2 render_tt

    do the rendering

=cut
sub render_tt {
    my($c) = @_;
    my $t1 = [gettimeofday];
    my $template = $c->stash->{'template'};
    confess("no template") unless $template;
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
    my $tt = $c->app->{'tt'} || &register($c->app);
    confess("no template") unless $template;
    $c->stats->profile(begin => "render: ".$template);

    # update Template::Provider include paths
    $template_provider_user->include_path([$c->config->{'user_template_path'}]) if $template_provider_user;

    if($Thruk::Globals::tt_profiling) {
        require Thruk::Template::Context;
        Thruk::Template::Context::reset_stack();
    }

    $tt->process(
        $template,
        ($stash || $c->stash),
        $output,
    ) || do {
        $c->stats->profile(end => "render: ".$template);
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
