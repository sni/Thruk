package Thruk::Controller::Rest::V1::editor;

use warnings;
use strict;

use Thruk::Controller::rest_v1 ();

=head1 NAME

Thruk::Controller::Rest::V1::editor - Editor Rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=cut

##########################################################
# REST PATH: GET /thruk/editor
# lists editor sections.
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/editor$%mx, \&_rest_get_thruk_editor);
sub _rest_get_thruk_editor {
    my($c, $path_info) = @_;

    require Thruk::Controller::editor;
    return(Thruk::Controller::editor::TO_JSON($c, 1));
}

##########################################################
# REST PATH: GET /thruk/editor/files
# lists editor files and path.
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/editor/files?$%mx, \&_rest_get_thruk_editor_files);
sub _rest_get_thruk_editor_files {
    my($c, $path_info) = @_;

    require Thruk::Controller::editor;
    return(Thruk::Controller::editor::TO_JSON($c));
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
