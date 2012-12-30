package Thruk::Controller::reports2;

use strict;
use warnings;
use Thruk 1.60;
use Carp;
use parent 'Catalyst::Controller';
use Data::Dumper;
use Thruk::Utils::Reports;

=head1 NAME

Thruk::Controller::reports2 - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

######################################
# add new menu item
Thruk::Utils::Menu::insert_item('Reports', {
                                    'href'  => '/thruk/cgi-bin/reports2.cgi',
                                    'name'  => 'Reporting',
                         });

# enable reporting features if this plugin is loaded
Thruk->config->{'use_feature_reports'} = 'reports2.cgi';

######################################

=head2 reports2_cgi

page: /thruk/cgi-bin/reports2.cgi

=cut
sub reports2_cgi : Regex('thruk\/cgi\-bin\/reports2\.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/reports2/index');
}

##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    $c->stash->{'no_auto_reload'}      = 1;
    $c->stash->{title}                 = 'Reports';
    $c->stash->{page}                  = 'status'; # otherwise we would have to create a reports.css for every theme
    $c->stash->{template}              = 'reports.tt';
    $c->stash->{subtitle}              = 'Reports';
    $c->stash->{infoBoxTitle}          = 'Reporting';

    $Thruk::Utils::CLI::c              = $c;

    my $report_nr = $c->{'request'}->{'parameters'}->{'report'};
    my $action    = $c->{'request'}->{'parameters'}->{'action'} || 'show';
    my $refresh   = 0;
    $refresh = $c->{'request'}->{'parameters'}->{'refresh'} if exists $c->{'request'}->{'parameters'}->{'refresh'};

    if($action eq 'updatecron') {
        if(Thruk::Utils::Reports::update_cron_file($c)) {
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'updated crontab' });
        } else {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'failed to update crontab' });
        }
        return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/reports2.cgi");
    }

    if(defined $report_nr) {
        if($report_nr !~ m/^\d+$/mx and $report_nr ne 'new') {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'invalid report number: '.$report_nr });
            return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/reports2.cgi");
        }
        if($action eq 'show') {
            if(!Thruk::Utils::Reports::report_show($c, $report_nr, $refresh)) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
            }
        }
        elsif($action eq 'edit') {
            return $self->report_edit($c, $report_nr);
        }
        elsif($action eq 'edit2') {
            return $self->report_edit_step2($c, $report_nr);
        }
        elsif($action eq 'update') {
            return $self->report_update($c, $report_nr);
        }
        elsif($action eq 'save') {
            return $self->report_save($c, $report_nr);
        }
        elsif($action eq 'remove') {
            return $self->report_remove($c, $report_nr);
        }
    }

    # show list of configured reports
    $c->stash->{'no_auto_reload'} = 0;
    $c->stash->{reports} = Thruk::Utils::Reports::get_report_list($c);

    Thruk::Utils::ssi_include($c);

    return 1;
}

##########################################################

=head2 report_edit

=cut
sub report_edit {
    my($self, $c, $report_nr) = @_;

    my $r;
    $c->stash->{'params'} = {};
    if($report_nr eq 'new') {
        $r = Thruk::Utils::Reports::_get_new_report($c);
        $r->{'backends'} = [ keys %{$c->stash->{'backend_detail'}} ];
        for my $key (keys %{$c->{'request'}->{'parameters'}}) {
            if($key =~ m/^params\.(.*)$/mx) {
                $c->stash->{'params'}->{$1} = $c->{'request'}->{'parameters'}->{$key};
            } else {
                $r->{$key} = $c->{'request'}->{'parameters'}->{$key} if defined $c->{'request'}->{'parameters'}->{$key};
            }
        }
        $r->{'template'} = $c->{'request'}->{'parameters'}->{'template'} || 'sla_host.tt';
        if($c->{'request'}->{'parameters'}->{'params.url'}) {
            $r->{'params'}->{'url'} = $c->{'request'}->{'parameters'}->{'params.url'};
        }
    } else {
        $r = Thruk::Utils::Reports::_read_report_file($c, $report_nr);
        if(!defined $r or $r->{'readonly'}) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'cannot change report' });
            return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/reports2.cgi");
        }
    }

    $c->stash->{r} = $r;

    # get templates
    my $templates = {};
    for my $path (@{$c->config->{templates_paths}}, $c->config->{'View::TT'}->{'INCLUDE_PATH'}) {
        for my $file (glob($path.'/reports/*.tt')) {
            $file =~ s/^.*\/(.*)$/$1/mx;
            my $name = $file;
            $name    =~ s/\.tt$//gmx;
            $name    = join(' ', map(ucfirst, split(/_/mx, $name)));
            $name    =~ s/Sla/SLA/gmx;
            $templates->{$file} = {
                file => $file,
                name => $name,
            };
        }
    }
    $c->stash->{templates} = $templates;

    $c->stash->{timeperiods} = $c->{'db'}->get_timeperiods(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'timeperiods')], remove_duplicates => 1, sort => 'name');

    Thruk::Utils::ssi_include($c);
    $c->stash->{template} = 'reports_edit.tt';
    return;
}

##########################################################

=head2 report_edit_step2

=cut
sub report_edit_step2 {
    my($self, $c, $report_nr) = @_;

    my $r;
    if($report_nr eq 'new') {
        $r = Thruk::Utils::Reports::_get_new_report($c);
    } else {
        $r = Thruk::Utils::Reports::_read_report_file($c, $report_nr);
        if(!defined $r or $r->{'readonly'}) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'cannot change report' });
            return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/reports2.cgi");
        }
    }

    $c->stash->{timeperiods} = $c->{'db'}->get_timeperiods(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'timeperiods')], remove_duplicates => 1, sort => 'name');

    my $template = $c->{'request'}->{'parameters'}->{'template'};
    $r->{'template'}      = $template if defined $template;
    $c->stash->{r}        = $r;
    $c->stash->{template} = 'reports_edit_step2.tt';
    return;
}


##########################################################

=head2 report_save

=cut
sub report_save {
    my($self, $c, $report_nr) = @_;

    my($data) = Thruk::Utils::Reports::get_report_data_from_param($c->{'request'}->{'parameters'});
    my $msg = 'report updated';
    if($report_nr eq 'new') { $msg = 'report created'; }
    my $report;
    if($report = Thruk::Utils::Reports::report_save($c, $report_nr, $data)) {
        if(Thruk::Utils::Reports::update_cron_file($c)) {
            if(defined $report->{'var'}->{'opt_errors'}) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => "Error in Report Options:<br>".join("<br>", @{$report->{'var'}->{'opt_errors'}}) });
            } else {
                Thruk::Utils::set_message( $c, { style => 'success_message', msg => $msg });
            }
        }
    } else {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
    }
    return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/reports2.cgi");
}

##########################################################

=head2 report_update

=cut
sub report_update {
    my($self, $c, $report_nr) = @_;

    my $report = Thruk::Utils::Reports::_read_report_file($c, $report_nr);
    if($report) {
        Thruk::Utils::Reports::set_running($c, $report_nr, -1, time());
        unlink($c->config->{'tmp_path'}."/reports/".$report_nr.".log");
        my $cmd = Thruk::Utils::Reports::_get_report_cmd($c, $report, 0);
        Thruk::Utils::External::cmd($c, { cmd => $cmd, 'background' => 1, 'no_shell' => 1 });
        Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'report scheduled for update' });
    } else {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
    }
    return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/reports2.cgi");
}

##########################################################

=head2 report_remove

=cut
sub report_remove {
    my($self, $c, $report_nr) = @_;

    if(Thruk::Utils::Reports::report_remove($c, $report_nr)) {
        Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'report removed' });
    } else {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
    }
    return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/reports2.cgi");
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
