package Thruk::Controller::remote;

use strict;
use warnings;
use utf8;
use Data::Dumper;
use Thruk::Utils::CLI;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::remote - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

##########################################################

=head2 remote_cgi

page: /thruk/cgi-bin/remote.cgi

=cut

sub remote_cgi : Regex('thruk\/cgi\-bin\/remote\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    Thruk::Utils::check_pid_file($c);
    return $c->detach('/remote/index');
}

##########################################################
sub index :Path :Args(0) :MyAction('AddSafeDefaults') {
    my ( $self, $c ) = @_;
    $c->stash->{'text'} = '';
    if(defined $c->{'request'}->{'parameters'}->{'data'}) {
        $c->stash->{'text'} = Thruk::Utils::CLI::_from_fcgi($c, $c->{'request'}->{'parameters'}->{'data'});
    }
    $c->stash->{'template'} = 'passthrough.tt';
    return;
}

=head1 AUTHOR

Sven Nierlein, 2012, <sven.nierlein@consol.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
