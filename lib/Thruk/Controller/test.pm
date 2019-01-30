package Thruk::Controller::test;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::test - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

=head2 index

=cut

##########################################################
sub index {
    my ( $c ) = @_;

    if(   (!defined $ENV{'THRUK_SRC'} || ($ENV{'THRUK_SRC'} ne 'TEST_LEAK' && $ENV{'THRUK_SRC'} ne 'TEST'))
       && !$c->config->{'thruk_debug'}) {
        die("test.cgi is disabled unless in test mode!");
    }

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_DEFAULTS);

    $c->stash->{'template'} = 'main.tt';

    my $action = $c->req->parameters->{'action'} || '';

    if($action eq 'leak') {
        my $leak = Thruk::Backend::Manager->new();
        $leak->{'test'} = $leak;
        $c->stash->{ctx} = $c;
    }

    return 1;
}

1;
