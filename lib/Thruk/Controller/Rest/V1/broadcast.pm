package Thruk::Controller::Rest::V1::broadcast;

use strict;
use warnings;
use Thruk::Controller::rest_v1;

=head1 NAME

Thruk::Controller::Rest::V1::broadcast - Broadcast rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=cut

##########################################################
# REST PATH: GET /thruk/broadcasts
# lists broadcasts
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/broadcasts?$%mx, \&_rest_get_thruk_broadcast);
sub _rest_get_thruk_broadcast {
    my($c, undef, $file) = @_;
    require Thruk::Utils::Broadcast;
    $file = '*' unless $file;
    my @files  = glob($c->config->{'var_path'}.'/broadcast/'.$file.'.json');
    my $broadcasts = Thruk::Controller::rest_v1::load_json_files($c, {
            files                  => \@files,
            authorization_callback => \&Thruk::Utils::Broadcast::is_authorized_for_broadcast,
    });

    for my $b (@{$broadcasts}) {
        Thruk::Utils::Broadcast::process_broadcast($c, $b);
        $b->{'text'} = Thruk::Utils::Filter::replace_macros($b->{'text'}, $b->{'macros'});
        $b->{'text'} = Thruk::Utils::Filter::replace_macros($b->{'text'}, $b->{'frontmatter'});
    }

    if($file eq '*') {
        return($broadcasts);
    }

    if(!$broadcasts->[0]) {
        return({ 'message' => 'no such broadcast', code => 404 });
    }

    my $method = $c->req->method();
    if($method eq 'PATCH') {
        Thruk::Utils::IO::merge_deep($broadcasts->[0], $c->req->parameters);
        Thruk::Utils::IO::json_lock_store($c->config->{'var_path'}.'/broadcast/'.$file.'.json', $broadcasts->[0], 1, 1);
        return({
            'message' => 'successfully saved 1 broadcast.',
            'count'   => 1,
        });
    }
    elsif($method eq 'POST') {
        $broadcasts->[0] = \%{$c->req->parameters};
        Thruk::Utils::IO::mkdir_r($c->config->{'var_path'}.'/broadcast/');
        Thruk::Utils::IO::json_lock_store($c->config->{'var_path'}.'/broadcast/'.$file.'.json', $broadcasts->[0], 1, 1);
        return({
            'message' => 'successfully saved 1 broadcast.',
            'count'   => 1,
        });
    }
    elsif($method eq 'DELETE') {
        if(unlink($c->config->{'var_path'}.'/broadcast/'.$file.'.json')) {
            return({
                'message' => 'successfully removed 1 broadcast.',
                'count'   => 1,
            });
        }
        return({
            'message' => 'failed to removed broadcast',
            'code'    => 500,
        });
    }

    if($file ne '*') {
        return($broadcasts->[0]);
    }
}

##########################################################
# REST PATH: GET /thruk/broadcasts/<file>
# alias for /thruk/broadcasts?file=<file>
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/broadcasts?/([^/\.]+)$%mx, \&_rest_get_thruk_broadcast);

# REST PATH: PATCH /thruk/broadcasts/<file>
# update attributes for given broadcast.

# REST PATH: POST /thruk/broadcasts/<file>
# update entire broadcast for given file.

# REST PATH: DELETE /thruk/broadcasts/<file>
# remove broadcast for given file.
Thruk::Controller::rest_v1::register_rest_path_v1(['POST', 'PATCH', 'DELETE'], qr%^/thruk/broadcasts?/([^/\.]+)$%mx, \&_rest_get_thruk_broadcast, ["admin"]);

##########################################################
# REST PATH: POST /thruk/broadcasts
# create new broadcast.
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/thruk/broadcasts?$%mx, \&_rest_get_thruk_broadcast_new, ["admin"]);
sub _rest_get_thruk_broadcast_new {
    my($c) = @_;

    require Thruk::Utils::Broadcast;

    my $broadcast = {};
    $broadcast    = Thruk::Utils::Broadcast::update_broadcast_from_param($c, $broadcast);
    my $file = $c->req->parameters->{'file'};
    if(!$file) {
        $file = POSIX::strftime('%Y-%m-%d-'.$c->stash->{'remote_user'}.'.json', localtime);
        my $x  = 1;
        while(-e $c->config->{'var_path'}.'/broadcast/'.$file) {
            $file = POSIX::strftime('%Y-%m-%d-'.$c->stash->{'remote_user'}.'_'.$x.'.json', localtime);
            $x++;
        }
    }
    if($file =~ m/^[\.\/]+/mx) {
        return({
            'message' => 'invalid file name',
            'code'    => 400,
        });
    }
    Thruk::Utils::IO::mkdir_r($c->config->{'var_path'}.'/broadcast/');
    Thruk::Utils::IO::json_lock_store($c->config->{'var_path'}.'/broadcast/'.$file.'.json', $broadcast, 1, 1);
    return({
        'message' => 'successfully created broadcast.',
        'file'    => $file,
        'count'   => 1,
    });
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
