package Thruk::Controller::mobile;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::mobile - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

# enable statusmap if this plugin is loaded
Thruk->config->{'use_feature_mobile'} = 1;

######################################

=head2 mobile_cgi

page: /thruk/cgi-bin/mobile.cgi

=cut
sub mobile_cgi : Regex('thruk\/cgi\-bin\/mobile\.cgi') {
    my ( $self, $c ) = @_;
    return $c->detach('/mobile/index');
}


##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    if(defined $c->{'request'}->{'parameters'}->{'data'}) {
        my $type  = $c->{'request'}->{'parameters'}->{'data'};
        my $limit = $c->{'request'}->{'parameters'}->{'limit'} || 10;
        if($type eq 'host_notifications') {
            $c->stash->{'json'} = $c->{'db'}->get_logs(filter => [ class => 3, Thruk::Utils::Auth::get_auth_filter($c, 'log')], limit => $limit, sort => {'DESC' => 'time'});
            $c->forward('Thruk::View::JSON');
            return;
        }
        else {
            $c->log->error("unknown type: ".$type);
            return;
        }
    }

    my $host_stats    = $c->{'db'}->get_host_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts')]);
    my $service_stats = $c->{'db'}->get_service_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services')]);

    $c->stash->{hosts}     = $host_stats;
    $c->stash->{services}  = $service_stats;
    $c->stash->{template}  = 'mobile.tt';

    return 1;
}


=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
