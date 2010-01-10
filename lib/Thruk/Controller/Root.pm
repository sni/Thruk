package Thruk::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Data::Dumper;
use Thruk::Helper;

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

Thruk::Controller::Root - Root Controller for Thruk

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 index

=cut

######################################
# begin, running at the begin of every req
sub begin : Private {
    my ( $self, $c ) = @_;
    my $use_frames = Thruk->config->{'use_frames'};
    $use_frames = 1 unless defined $use_frames;
    $use_frames = !$c->{'request'}->{'parameters'}->{'nav'} if defined $c->{'request'}->{'parameters'}->{'nav'};
    $c->stash->{'use_frames'} = $use_frames;

    my $doc_link = Thruk->config->{'documentation_link'};
    $doc_link    = '/thruk/docs/index.html' unless defined $doc_link;
    $c->stash->{'documentation_link'} = $doc_link;
}

######################################
# auto, runs on every request
#sub auto : Private {
#    my ( $self, $c ) = @_;
#}

######################################
# default page
sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

######################################
# index page
# we dont want index.html in the url
sub index :Path('/') {
    my ( $self, $c ) = @_;
    if(scalar @{$c->request->args} > 0 and $c->request->args->[0] ne 'index.html') {
        $c->detach("default");
    }
    $c->redirect("/thruk/");
}
# we dont want index.html in the url
sub index_html : Path('/index.html') {
    my ( $self, $c ) = @_;
    if($c->stash->{'use_frames'}) {
        $c->detach("thruk_index_html");
    } else {
        $c->detach("thruk_main_html");
    }
}
# but if used not via fastcgi/apache, there is no way around
sub thruk_index : Path('/thruk/') {
    my ( $self, $c ) = @_;
    if($c->stash->{'use_frames'}) {
        $c->detach("thruk_index_html");
    } else {
        $c->detach("thruk_main_html");
    }
}

# but if used not via fastcgi/apache, there is no way around
sub thruk_index_html : Path('/thruk/index.html') {
    my ( $self, $c ) = @_;
    unless($c->stash->{'use_frames'}) {
        $c->detach("thruk_main_html");
    }
    $c->stash->{'template'} = 'index.tt';
}

######################################
sub thruk_side_html : Path('/thruk/side.html') {
    my ( $self, $c ) = @_;

    $c->stash->{'template'} = 'side.tt';
}

######################################
sub thruk_main_html : Path('/thruk/main.html') {
    my ( $self, $c ) = @_;
    $c->stash->{'title'}     = 'Thruk Monitoring Webinterface';
    $c->stash->{'page'}      = 'splashpage';
    $c->stash->{'version'}   = Thruk->config->{'version'};
    $c->stash->{'released'}  = Thruk->config->{'released'};
    $c->stash->{'template'}  = 'main.tt';
}

######################################
sub thruk_changes_html : Path('/thruk/changes.html') :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;
    $c->stash->{infoBoxTitle}     = 'Change Log';
    $c->stash->{'title'}          = 'Change Log';
    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{'template'}       = 'changes.tt';
}

######################################
sub thruk_docs : Path('/thruk/docs/') {
    my ( $self, $c ) = @_;
    $c->stash->{'title'}          = 'Documentation';
    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{'template'}       = 'docs.tt';
}

######################################
# tac
sub tac_cgi : Path('thruk/cgi-bin/tac.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/tac/index');
}

######################################
# statusmap
sub statusmap_cgi : Path('thruk/cgi-bin/statusmap.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/statusmap/index');
}

######################################
# status
sub status_cgi : Path('thruk/cgi-bin/status.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/status/index');
}

######################################
# commands
sub cmd_cgi : Path('thruk/cgi-bin/cmd.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/cmd/index');
}

######################################
# outages
sub outages_cgi : Path('thruk/cgi-bin/outages.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/outages/index');
}

######################################
# avail
sub avail_cgi : Path('thruk/cgi-bin/avail.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/avail/index');
}

######################################
# trends
sub trends_cgi : Path('thruk/cgi-bin/trends.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/trends/index');
}

######################################
# history
sub history_cgi : Path('thruk/cgi-bin/history.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/history/index');
}

######################################
# summary
sub summary_cgi : Path('thruk/cgi-bin/summary.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/summary/index');
}

######################################
# histogram
sub histogram_cgi : Path('thruk/cgi-bin/histogram.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/histogram/index');
}

######################################
# notifications
sub notifications_cgi : Path('thruk/cgi-bin/notifications.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/notifications/index');
}

######################################
# showlog
sub showlog_cgi : Path('thruk/cgi-bin/showlog.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/showlog/index');
}

######################################
# extinfo
sub extinfo_cgi : Path('thruk/cgi-bin/extinfo.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/extinfo/index');
}

######################################
# config
sub config_cgi : Path('thruk/cgi-bin/config.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/config/index');
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;
    my @errors = @{$c->error};
    if(scalar @errors > 0) {
        for my $error (@errors) {
            $c->log->error($error);
        }
        $c->detach('/error/index/13');
    }
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
