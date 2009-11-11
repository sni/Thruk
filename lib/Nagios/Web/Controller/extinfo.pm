package Nagios::Web::Controller::extinfo;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Nagios::Web::Controller::extinfo - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;
    my $type = $c->{'request'}->{'parameters'}->{'type'} || 0;

    #print "HTTP 200 OK\nContent-Type: text/html\n\n<pre>\n";
    #print Dumper($c);
    #print Dumper($self);
    #exit;

    my $infoBoxTitle;
    if($type == 0) {
        $infoBoxTitle = 'Nagios Process Information';
    }
    if($type == 1) {
        $infoBoxTitle = 'Host Information';
    }
    if($type == 2) {
        $infoBoxTitle = 'Service Information';
    }
    if($type == 3) {
        $infoBoxTitle = 'All Host and Service Comments';
    }
    if($type == 4) {
        $infoBoxTitle = 'Performance Information';
    }
    if($type == 5) {
        $infoBoxTitle = 'Hostgroup Information';
    }
    if($type == 6) {
        $infoBoxTitle = 'All Host and Service Scheduled Downtime';
    }
    if($type == 7) {
        $infoBoxTitle = 'Check Scheduling Queue';
    }
    if($type == 8) {
        $infoBoxTitle = 'Servicegroup Information';
    }

    $c->stash->{title}          = 'Extended Information';
    $c->stash->{infoBoxTitle}   = $infoBoxTitle;
    $c->stash->{page}           = 'extinfo';
    $c->stash->{template}       = 'extinfo_type_'.$type.'.tt';
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
