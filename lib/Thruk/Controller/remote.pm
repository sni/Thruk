package Thruk::Controller::remote;

use strict;
use warnings;
use Module::Load qw/load/;
use parent 'Catalyst::Controller';
use Data::Dumper;

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

sub remote_cgi : Path('/thruk/cgi-bin/remote.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    Thruk::Utils::check_pid_file($c);

    if(!$c->config->{'remote_modules_loaded'}) {
        load Data::Dumper;
        load Thruk::Utils::CLI;
        load File::Slurp, qw/read_file/;
        $c->config->{'remote_modules_loaded'} = 1;
    }

    return $c->detach('/remote/index');
}

##########################################################
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{'text'} = 'OK';
    if(defined $c->{'request'}->{'parameters'}->{'data'}) {
        $c->stash->{'text'} = Thruk::Utils::CLI::_from_fcgi($c, $c->{'request'}->{'parameters'}->{'data'});
    }
    $c->stash->{'template'} = 'passthrough.tt';

    my $action = $c->{'request'}->query_keywords() || '';

    # startup request?
    if($action eq 'startup') {
        if(!$c->config->{'started'}) {
            $c->config->{'started'} = 1;
            $c->log->info("started ($$)");
            $c->stash->{'text'} = 'startup done';
            if(defined $c->{'request'}->{'headers'}->{'user-agent'} and $c->{'request'}->{'headers'}->{'user-agent'} =~ m/wget/mix) {
                # compile templates in background
                $c->run_after_request('Thruk::Utils::precompile_templates($c)');
            }
        }
        return;
    }

    # compile request?
    if($action eq 'compile' or exists $c->{'request'}->{'parameters'}->{'compile'}) {
        if($c->config->{'precompile_templates'} == 2) {
            $c->stash->{'text'} = 'already compiled';
        } else {
            $c->stash->{'text'} = Thruk::Utils::precompile_templates($c);
            $c->log->info($c->stash->{'text'});
        }
        return;
    }

    # log requests?
    if($action eq 'log' and $c->{'request'}->{'method'} eq 'POST') {
        my $body = $c->{'request'}->body();
        if($body) {
            if(ref $body eq 'File::Temp') {
                my $file = $body->filename();
                if($file and -e $file) {
                    my $msg = read_file($file);
                    unlink($file);
                    $c->log->error($msg);
                    return;
                }
            }
        }
        $c->log->error('log request without a file: '.Dumper($c->{'request'}));
        return;
    }

    return;
}

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
