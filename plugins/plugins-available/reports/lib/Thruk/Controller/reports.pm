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
Thruk::Utils::Menu::insert_item('Reports', {
                                    'href'  => '/thruk/cgi-bin/reports.cgi',
                                    'name'  => 'Reporting',
                         });

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

    $c->stash->{'no_auto_reload'}      = 1;
    $c->stash->{title}                 = 'Reports';
    $c->stash->{page}                  = 'reports';
    $c->stash->{template}              = 'reports.tt';
    $c->stash->{subtitle}              = 'Reports';
    $c->stash->{infoBoxTitle}          = 'Reporting';

    my $report_nr = $c->{'request'}->{'parameters'}->{'report'};
    my $action    = $c->{'request'}->{'parameters'}->{'action'} || 'show';
    my $refresh   = 0;
    $refresh = $c->{'request'}->{'parameters'}->{'refresh'} if exists $c->{'request'}->{'parameters'}->{'refresh'};

    if(defined $report_nr) {
        if($action eq 'show') {
            if(!Thruk::Utils::Reports::report_show($c, $report_nr, $refresh)) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
            }
        }
        elsif($action eq 'edit') {
        }
        elsif($action eq 'update') {
            Thruk::Utils::External::perl($c, { expr => 'Thruk::Utils::Reports::generate_report($c, '.$report_nr.')', 'background' => 1 });
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'report scheduled for update' });
            return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/reports.cgi");
        }
        elsif($action eq 'save') {
            my($name, $template, $data, $backends) = Thruk::Utils::Reports::get_report_data_from_param($c->{'request'}->{'parameters'});

            if(Thruk::Utils::Reports::report_save($c, $report_nr, $name, $template, $data, $backends)) {
                Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'report updated' });
            } else {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
            }
        }
        elsif($action eq 'remove') {
            if(Thruk::Utils::Reports::report_remove($c, $report_nr)) {
                Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'report removed' });
            } else {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
            }
        }
    }

    # show list of configured reports
    $c->stash->{'no_auto_reload'} = 0;
    $c->stash->{reports} = Thruk::Utils::Reports::get_report_list($c);

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
