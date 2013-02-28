package Thruk::Controller::remote;

use strict;
use warnings;
use utf8;
use Data::Dumper;
use Thruk::Utils::CLI;
use File::Slurp;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::remote - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

##########################################################

=head2 remote_cgi

page: /thruk/cgi-bin/remote.cgi

=cut

sub remote_cgi : Regex('thruk\/cgi\-bin\/remote\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    Thruk::Utils::check_pid_file($c);
    return $c->detach('/remote/index');
}

##########################################################
sub index :Path :Args(0) :MyAction('AddSafeDefaults') {
    my ( $self, $c ) = @_;
    $c->stash->{'text'} = 'OK';
    if(defined $c->{'request'}->{'parameters'}->{'data'}) {
        $c->stash->{'text'} = Thruk::Utils::CLI::_from_fcgi($c, $c->{'request'}->{'parameters'}->{'data'});
    }
    $c->stash->{'template'} = 'passthrough.tt';

    my $action = $c->{'request'}->query_keywords();
    return unless $action;

    # startup request?
    if($action eq 'startup') {
        if(!$c->config->{'started'}) {
            $c->config->{'started'} = 1;
            $c->log->info("started ($$)");
            $c->stash->{'text'} = 'startup done';
            if($c->config->{'precompile_templates'}) {
                # compile templates in background
                my $url = "".$c->request->uri;
                $url    =~ s/\?startup$/?compile/gmx;
                `bash -l -c "echo \$(nohup wget -q -O - '$url' > /dev/null 2>&1 &)"`;
            }
        }
        return;
    }

    # compile request?
    if($action eq 'compile') {
        if($c->config->{'precompile_templates'}) {
            $c->stash->{'text'} = Thruk::Utils::precompile_templates($c);
            $c->log->info($c->stash->{'text'});
        } else {
            $c->stash->{'text'} = 'disabled or already compiled';
        }
        return;
    }

    # log requests?
    if($action eq 'log') {
        my $file = "".$c->{'request'}->body();
        my $msg = read_file($file);
        unlink($file);
        $c->log->error($msg);
        return;
    }

    return;
}

=head1 AUTHOR

Sven Nierlein, 2012, <sven.nierlein@consol.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
