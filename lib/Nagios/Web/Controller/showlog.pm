package Nagios::Web::Controller::showlog;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Nagios::Web::Controller::showlog - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    my $oldestfirst = $c->{'request'}->{'parameters'}->{'oldestfirst'} || 0;
    my $archive     = $c->{'request'}->{'parameters'}->{'archive'}     || 0;

    my $query = "GET log\nLimit: 100\n";
#    $query   .= "Columns: message host_name service_description plugin_output state time command_name contact_name\n";
    $query   .= Nagios::Web::Helper::get_auth_filter($c, 'log');

    my $logs = $c->{'live'}->selectall_arrayref($query, { Slice => 1, AddPeer => 1});
#use Data::Dumper;
#print "HTTP/1.1 200 OK\n\n<html><pre>";
#$Data::Dumper::Sortkeys = 1;
#print Dumper($query);
#print Dumper($logs);

    if(!$oldestfirst) {
        @{$logs} = reverse @{$logs};
    }

    $c->stash->{logs}             = $logs;
    $c->stash->{title}            = 'Nagios Log File';
    $c->stash->{infoBoxTitle}     = 'Event Log';
    $c->stash->{page}             = 'showlog';
    $c->stash->{template}         = 'showlog.tt';
    $c->stash->{'no_auto_reload'} = 1;
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
