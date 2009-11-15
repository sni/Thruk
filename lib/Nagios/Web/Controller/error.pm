package Nagios::Web::Controller::error;

use strict;
use warnings;
use Data::Dumper;
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
    my ( $self, $c, $arg1 ) = @_;

    my $errors = {
        '1'  => {
            'mess' => 'It appears as though you do not have permission to view process information...',
            'dscr' => 'If you believe this is an error, check the HTTP server authentication requirements for accessing this CGI<br>and check the authorization options in your CGI configuration file.',
        },
        '2'  => {
            'mess' => 'It appears as though you do not have permission to view the log file...',
            'dscr' => 'If you believe this is an error, check the HTTP server authentication requirements for accessing this CGI<br>and check the authorization options in your CGI configuration file.',
        },
        '3'  => {
            'mess' => 'Sorry Dave, I can\'t let you do that...',
            'dscr' => 'It seems that you have chosen to not use the authentication functionality of the CGIs.<br><br>I don\'t want to be personally responsible for what may happen as a result of allowing unauthorized users to issue commands to Nagios,so you\'ll have to disable this safeguard if you are really stubborn and want to invite trouble.<br><br><strong>Read the section on CGI authentication in the HTML documentation to learn how you can enable authentication and why you should want to.',
        },
    };

    $c->stash->{errorMessage}       = $errors->{$arg1}->{'mess'};
    $c->stash->{errorDescription}   = $errors->{$arg1}->{'dscr'};

    #$c->stash->{title}              = 'Current Network Status';
    #$c->stash->{infoBoxTitle}       = 'Current Network Status';
    #$c->stash->{page}               = 'status';

    Nagios::Web->config->{'custom-error-message'}->{'error-template'}    = 'error.tt';
    Nagios::Web->config->{'custom-error-message'}->{'response-status'}   = 403;
    $c->error($errors->{$arg1}->{'mess'});
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
