package Thruk::Controller::remote;

use warnings;
use strict;
use Data::Dumper;

use Thruk::Utils ();
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

    Thruk::Utils::check_pid_file($c);

    $c->stash->{'navigation'} = 'off'; # would be useless here, so set it non-empty, otherwise AddDefaults::end would read it again

    if(defined $c->req->parameters->{'data'}) {
        $c->stash->{'inject_stats'} = 0;
        require Thruk::Utils::CLI;
        my $res = Thruk::Utils::CLI::from_fcgi($c, $c->req->parameters->{'data'});
        return if $c->{'rendered'};
        if(defined $res->{'output'} && $c->req->headers->{'accept'} && $c->req->headers->{'accept'} =~ m/application\/json/mx) {
            $c->res->body($res->{'output'});
            $c->{'rendered'} = 1;
            return;
        }
        if(ref $res eq 'HASH') {
            $res->{'version'} = $c->config->{'thrukversion'} unless defined $res->{'version'};
        }
        return $c->render(json => $res);
    }

    # set template after the CLI call above, it might get lost otherwise

    my $action = $c->req->uri->query || '';

    # startup request?
    if($action eq 'startup') {
        if(!$c->config->{'started'}) {
            $c->config->{'started'} = 1;
            _debug("started ($$)") unless $ENV{'THRUK_TEST_NO_LOG'};
            return $c->render("text" => 'startup done');
        }
        return $c->render("text" => 'already started');
    }

    # compile request?
    if($action eq 'compile' or exists $c->req->parameters->{'compile'}) {
        if($c->config->{'precompile_templates'} == 2) {
            return $c->render("text" => 'already compiled');
        }
        my $text = Thruk::Utils::precompile_templates($c);
        _info($text);
        return $c->render("text" => $text);
    }

    # log requests?
    if($action eq 'log' and $c->req->method eq 'POST') {
        my $body = $c->req->body;
        if($body) {
            if(ref $body eq 'File::Temp') {
                my $file = $body->filename();
                if($file and -e $file) {
                    my $msg = Thruk::Utils::IO::read($file);
                    unlink($file);
                    _error($msg);
                    return $c->render("text" => 'OK');
                }
            }
            if(ref $body eq 'FileHandle') {
                while(<$body>) {
                    _error($_);
                }
                return $c->render("text" => 'OK');
            }
        }
        _error('log request without a file: '.Dumper($c->req));
        return $c->render("text" => '');
    }

    if($action eq 'lb_ping' or exists $c->req->parameters->{'lb_ping'}) {
        if($c->cluster->is_clustered() && $c->cluster->maint()) {
            $c->res->code(503); # Service Unavailable
            return $c->render("text" => 'MAINTENANCE');
        }
    }

    return $c->render("text" => 'OK');
}

1;
