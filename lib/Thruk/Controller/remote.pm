package Thruk::Controller::remote;

use strict;
use warnings;
use Data::Dumper;
use Cpanel::JSON::XS qw/encode_json/;
use File::Slurp qw/read_file/;
use Module::Load qw/load/;
use Thruk::Utils::Log qw/:all/;

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
    my($c) = @_;

    if(!$c->config->{'remote_modules_loaded'}) {
        load Thruk::Utils::CLI;
        $c->config->{'remote_modules_loaded'} = 1;
    }
    Thruk::Utils::check_pid_file($c);

    $c->stash->{'navigation'} = 'off'; # would be useless here, so set it non-empty, otherwise AddDefaults::end would read it again
    $c->stash->{'text'}       = 'OK';

    if(defined $c->req->parameters->{'data'}) {
        $c->stash->{'inject_stats'} = 0;
        my $res = Thruk::Utils::CLI::from_fcgi($c, $c->req->parameters->{'data'});
        if(defined $res->{'output'} && $c->req->headers->{'accept'} && $c->req->headers->{'accept'} =~ m/application\/json/mx) {
            $c->res->body($res->{'output'});
            $c->{'rendered'} = 1;
            return;
        }
        if(ref $res eq 'HASH') {
            $res->{'version'} = $c->config->{'version'} unless defined $res->{'version'};
            $res->{'branch'}  = $c->config->{'branch'}  unless defined $res->{'branch'};
        }
        my $res_json;
        eval {
            $res_json = encode_json($res);
        };
        if($@) {
            die("ERROR - unable to encode to json: $@\n".Dumper($res));
        }
        $c->stash->{'text'} = $res_json;
    }

    # set template after the CLI call above, it might get lost otherwise
    $c->stash->{'template'} = 'passthrough.tt';

    my $action = $c->req->uri->query || '';

    # startup request?
    if($action eq 'startup') {
        if(!$c->config->{'started'}) {
            $c->config->{'started'} = 1;
            _debug("started ($$)") unless $ENV{'THRUK_TEST_NO_LOG'};
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
            _info($c->stash->{'text'});
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
                    _error($msg);
                    return;
                }
            }
            if(ref $body eq 'FileHandle') {
                while(<$body>) {
                    _error($_);
                }
                return;
            }
        }
        _error('log request without a file: '.Dumper($c->req));
        return;
    }

    if($action eq 'lb_ping' or exists $c->req->parameters->{'lb_ping'}) {
        if($c->cluster->is_clustered() && $c->cluster->maint()) {
            $c->stash->{'text'} = 'MAINTENANCE';
            $c->res->code(503); # Service Unavailable
        }
    }

    return;
}

1;
