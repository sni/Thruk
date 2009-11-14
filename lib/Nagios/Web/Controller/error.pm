package Nagios::Web::Controller::error;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Nagios::Web::Controller::error - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index :Path :Args(1) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    my $errorMessage     = 'It appears as though you do not have permission to view process information...';
    my $errorDescription = 'If you believe this is an error, check the HTTP server authentication requirements for accessing this CGI<br>and check the authorization options in your CGI configuration file.';

    $c->stash->{errorMessage}       = $errorMessage;
    $c->stash->{errorDescription}   = $errorDescription;

    #$c->stash->{title}              = 'Current Network Status';
    #$c->stash->{infoBoxTitle}       = 'Current Network Status';
    #$c->stash->{page}               = 'status';

    Nagios::Web->config->{'custom-error-message'}->{'error-template'}    = 'error.tt';
    Nagios::Web->config->{'custom-error-message'}->{'response-status'}   = 403;
    $c->error($errorMessage);
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
