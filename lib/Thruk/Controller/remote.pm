package Thruk::Controller::remote;

use strict;
use warnings;
use Data::Dumper;
use Module::Load qw/load/;

=head1 NAME

Thruk::Controller::remote - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

=head2 index

=cut

##########################################################
sub index {
    my ( $c ) = @_;

    if(!$c->config->{'remote_modules_loaded'}) {
        load Data::Dumper;
        load Thruk::Utils::CLI;
        load File::Slurp, qw/read_file/;
        $c->config->{'remote_modules_loaded'} = 1;
    }
    Thruk::Utils::check_pid_file($c);

    $c->stash->{'template'} = 'passthrough.tt';
    $c->stash->{'text'}     = 'OK';

    if(defined $c->req->parameters->{'data'}) {
        $c->stash->{'text'} = Thruk::Utils::CLI::_from_fcgi($c, $c->req->parameters->{'data'});
    }

    my $action = $c->req->uri->query || '';

    # startup request?
    if($action eq 'startup') {
        if(!$c->config->{'started'}) {
            $c->config->{'started'} = 1;
            $c->log->info("started ($$)") unless $ENV{'THRUK_TEST_NO_LOG'};
            $c->stash->{'text'} = 'startup done';
        }
        return;
    }

    # compile request?
    if($action eq 'compile' or exists $c->req->parameters->{'compile'}) {
        if($c->config->{'precompile_templates'} == 2) {
            $c->stash->{'text'} = 'already compiled';
        } else {
            $c->stash->{'text'} = Thruk::Utils::precompile_templates($c);
            $c->log->info($c->stash->{'text'});
        }
        return;
    }

    # log requests?
    if($action eq 'log' and $c->req->method eq 'POST') {
        my $body = $c->req->body;
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
            if(ref $body eq 'FileHandle') {
                while(<$body>) {
                    $c->log->error($_);
                }
                return;
            }
        }
        $c->log->error('log request without a file: '.Dumper($c->req));
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

1;
