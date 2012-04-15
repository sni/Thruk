package Thruk::Controller::reports;

use strict;
use warnings;
use Thruk 1.26;
use Carp;
use parent 'Catalyst::Controller';
use Data::Dumper;
use Thruk::Utils::Reports;

=head1 NAME

Thruk::Controller::reports - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

######################################
# add new menu item
#Thruk::Utils::Menu::insert_item('Reports', {
#                                    'href'  => '/thruk/cgi-bin/reports.cgi',
#                                    'name'  => 'Reporting',
#                         });

# enable reporting features if this plugin is loaded
Thruk->config->{'use_feature_reports'} = 1;

######################################

=head2 reports_cgi

page: /thruk/cgi-bin/reports.cgi

=cut
sub reports_cgi : Regex('thruk\/cgi\-bin\/reports\.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/reports/index');
}

##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    my $report_nr = $c->{'request'}->{'parameters'}->{'report'};
    if(defined $report_nr) {
        return Thruk::Utils::Reports::show_report($c, $report_nr);
    }

    $c->stash->{'no_auto_reload'}      = 1;
    $c->stash->{title}                 = 'Reports';
    $c->stash->{page}                  = 'reports';
    $c->stash->{template}              = 'reports.tt';
    $c->stash->{subtitle}              = 'Reports';
    $c->stash->{infoBoxTitle}          = 'Reporting';
    Thruk::Utils::ssi_include($c);

    return 1;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2012, <sven.nierlein@consol.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
