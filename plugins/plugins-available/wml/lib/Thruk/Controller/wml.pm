package Thruk::Controller::wml;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::wml - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

# enable wml features if this plugin is loaded
Thruk->config->{'use_feature_wml'} = 1;

######################################

=head2 wml_cgi

page: /thruk/cgi-bin/statuswml.cgi

=cut
sub wml_cgi : Regex('thruk\/cgi\-bin\/statuswml\.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/wml/index');
}


##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    my $style='uprobs';
    my $hostfilter = [ { 'state'=> { '>' => 0 } }, {'has_been_checked' => 1}, {'acknowledged' => 0}, {'scheduled_downtime_depth' => 0} ];
    my $servicefilter = [ { 'state'=> { '>' => 0 } }, {'has_been_checked' => 1}, {'acknowledged' => 0}, {'scheduled_downtime_depth' => 0} ];
    if(defined $c->{'request'}->{'parameters'}->{'style'}) {
       $style=$c->{'request'}->{'parameters'}->{'style'};
    }

    if ($style eq 'aprobs') {
            $hostfilter = [ { 'state'=> { '>' => 0 } }, {'has_been_checked' => 1} ];
            $servicefilter = [ { 'state'=> { '>' => 0 } }, {'has_been_checked' => 1} ];
    }
    my $services = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter ]);
    my $hosts = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ]);
    $c->stash->{services}	= $services;
    $c->stash->{hosts}    	= $hosts;
    $c->stash->{template}	= 'wml.tt';

    return 1;
}

=head1 AUTHOR

Franky Van Liedekerke, 2012

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
