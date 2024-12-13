package Thruk::Controller::Rest::V1::nc;

use warnings;
use strict;

use Thruk::Controller::rest_v1 ();

=head1 NAME

Thruk::Controller::Rest::V1::nc - Node-Control Rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=cut

##########################################################
# REST PATH: GET /thruk/node-control/nodes
# lists node control nodes.

# REST PATH: GET /thruk/nc/nodes
# alias for /thruk/node-control/nodes
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/(nc|node\-control)/nodes$%mx, \&_rest_get_thruk_nodes, ['admin']);
sub _rest_get_thruk_nodes {
    my($c, $path_info) = @_;

    require Thruk::Controller::node_control;
    return(Thruk::Controller::node_control::TO_JSON($c));
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
