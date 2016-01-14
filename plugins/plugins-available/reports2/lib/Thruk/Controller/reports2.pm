package Thruk::Controller::reports2;

use strict;
use warnings;
use Module::Load qw/load/;

=head1 NAME

Thruk::Controller::reports2 - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

##########################################################

=head2 index

=cut
sub index {
    my ( $c ) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_CACHED_DEFAULTS);

    if(!$c->config->{'reports2_modules_loaded'}) {
        load Carp, qw/confess carp/;
        load Thruk::Utils::Reports;
        load Thruk::Utils::Avail;
        $c->config->{'reports2_modules_loaded'} = 1;
    }

    $c->stash->{'no_auto_reload'}      = 1;
    $c->stash->{title}                 = 'Reports';
    $c->stash->{page}                  = 'status'; # otherwise we would have to create a reports.css for every theme
    $c->stash->{template}              = 'reports.tt';
    $c->stash->{subtitle}              = 'Reports';
    $c->stash->{infoBoxTitle}          = 'Reporting';
    $c->stash->{has_jquery_ui}         = 1;
    $c->stash->{'phantomjs'}           = 1;
    $c->stash->{'disable_backspace'}   = 1;

    my $report_nr = $c->req->parameters->{'report'};
    my $action    = $c->req->parameters->{'action'}    || 'show';
    my $highlight = $c->req->parameters->{'highlight'} || '';
    my $refresh   = 0;
    $refresh = $c->req->parameters->{'refresh'} if exists $c->req->parameters->{'refresh'};

    if(ref $action eq 'ARRAY') { $action = pop @{$action}; }

    if($action eq 'updatecron') {
        if(Thruk::Utils::Reports::update_cron_file($c)) {
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'updated crontab' });
        } else {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'failed to update crontab' });
        }
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi");
    }

    if($action eq 'check_affected_objects') {
        $c->req->parameters->{'get_total_numbers_only'} = 1;
        my @res;
        my $backends = $c->req->parameters->{'backends'} || $c->req->parameters->{'backends[]'};
        my $template = $c->req->parameters->{'template'};
        my $sub;
        if($template) {
            eval {
                $sub = Thruk::Utils::get_template_variable($c, 'reports/'.$template, 'affected_sla_objects', { block => 'edit' }, 1);
            };
        }
        $sub = 'Thruk::Utils::Avail::calculate_availability' unless $sub;
        if($backends and ($c->req->parameters->{'backends_toggle'} or $c->req->parameters->{'report_backends_toggle'})) {
            $c->{'db'}->disable_backends();
            $c->{'db'}->enable_backends($backends);
        }
        if($c->req->parameters->{'param'}) {
            for my $str (split/&/mx, $c->req->parameters->{'param'}) {
                my($key,$val) = split(/=/mx, $str, 2);
                if($key =~ s/^params\.//mx) {
                    $c->req->parameters->{$key} = $val unless exists $c->req->parameters->{$key};
                }
            }
        }
        eval {
            eval {
                require Thruk::Utils::Reports::CustomRender;
            };
            @res = &{\&{$sub}}($c);
        };
        my $json;
        if($@ or scalar @res == 0) {
            $json        = { 'hosts' => 0, 'services' => 0, 'error' => $@ };
        } else {
            my $total    = $res[0] + $res[1];
            my $too_many = $total > $c->config->{'report_max_objects'} ? 1 : 0;
            $json        = { 'hosts' => $res[0], 'services' => $res[1], 'too_many' => $too_many };
        }
        return $c->render(json => $json);
    }

    if(defined $report_nr) {
        if($report_nr !~ m/^\d+$/mx and $report_nr ne 'new') {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'invalid report number: '.$report_nr });
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi");
        }
        if($action eq 'show') {
            if(!Thruk::Utils::Reports::report_show($c, $report_nr, $refresh)) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
            }
        }
        elsif($action eq 'edit') {
            return report_edit($c, $report_nr);
        }
        elsif($action eq 'edit2') {
            return report_edit_step2($c, $report_nr);
        }
        elsif($action eq 'update') {
            return report_update($c, $report_nr);
        }
        elsif($action eq 'save') {
            return report_save($c, $report_nr);
        }
        elsif($action eq 'remove') {
            return report_remove($c, $report_nr);
        }
        elsif($action eq 'cancel') {
            return report_cancel($c, $report_nr);
        }
        elsif($action eq 'email') {
            return report_email($c, $report_nr);
        }
        elsif($action eq 'profile') {
            return report_profile($c, $report_nr);
        }
    }

    if($c->config->{'Thruk::Plugin::Reports2'}->{'phantomjs'} && !-x $c->config->{'Thruk::Plugin::Reports2'}->{'phantomjs'}) {
        $c->stash->{'phantomjs'} = 0;
        $c->stash->{'phantomjs_file'} = $c->config->{'Thruk::Plugin::Reports2'}->{'phantomjs'};
    }

    # show list of configured reports
    $c->stash->{'no_auto_reload'} = 0;
    $c->stash->{'highlight'}      = $highlight;
    $c->stash->{'reports'}        = Thruk::Utils::Reports::get_report_list($c);

    Thruk::Utils::ssi_include($c);

    return 1;
}

##########################################################

=head2 report_edit

=cut
sub report_edit {
    my($c, $report_nr) = @_;

    my $r;
    $c->stash->{'params'} = {};
    if($report_nr eq 'new') {
        $r = Thruk::Utils::Reports::_get_new_report($c);
        # set currently enabled backends
        $r->{'backends'} = [];
        for my $b (keys %{$c->stash->{'backend_detail'}}) {
            push @{$r->{'backends'}}, $b if $c->stash->{'backend_detail'}->{$b}->{'disabled'} == 0;
        }
        for my $key (keys %{$c->req->parameters}) {
            if($key =~ m/^params\.(.*)$/mx) {
                $c->stash->{'params'}->{$1} = $c->req->parameters->{$key};
            } else {
                $r->{$key} = $c->req->parameters->{$key} if defined $c->req->parameters->{$key};
            }
        }
        $r->{'template'} = $c->req->parameters->{'template'} || $c->config->{'Thruk::Plugin::Reports2'}->{'default_template'} || 'sla_host.tt';
        if($c->req->parameters->{'params.url'}) {
            $r->{'params'}->{'url'} = $c->req->parameters->{'params.url'};
        }
    } else {
        $r = Thruk::Utils::Reports::_read_report_file($c, $report_nr);
        if(!defined $r || $r->{'readonly'}) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'cannot change report' });
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi");
        }
    }

    $c->stash->{templates} = Thruk::Utils::Reports::get_report_templates($c);
    _set_report_data($c, $r);

    Thruk::Utils::ssi_include($c);
    $c->stash->{template} = 'reports_edit.tt';
    return;
}

##########################################################

=head2 report_edit_step2

=cut
sub report_edit_step2 {
    my($c, $report_nr) = @_;

    my $r;
    if($report_nr eq 'new') {
        $r = Thruk::Utils::Reports::_get_new_report($c);
    } else {
        $r = Thruk::Utils::Reports::_read_report_file($c, $report_nr);
        if(!defined $r || $r->{'readonly'}) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'cannot change report' });
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi");
        }
    }

    my $template     = $c->req->parameters->{'template'};
    $r->{'template'} = $template if defined $template;

    _set_report_data($c, $r);

    $c->stash->{template} = 'reports_edit_step2.tt';
    return;
}


##########################################################

=head2 report_save

=cut
sub report_save {
    my($c, $report_nr) = @_;

    return unless Thruk::Utils::check_csrf($c);

    my $params = $c->req->parameters;
    $params->{'params.t1'} = Thruk::Utils::parse_date($c, $params->{'t1'}) if defined $params->{'t1'};
    $params->{'params.t2'} = Thruk::Utils::parse_date($c, $params->{'t2'}) if defined $params->{'t2'};

    my($data) = Thruk::Utils::Reports::get_report_data_from_param($params);
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
    return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi?highlight=".$report_nr);
}

##########################################################

=head2 report_update

=cut
sub report_update {
    my($c, $report_nr) = @_;

    my $report = Thruk::Utils::Reports::_read_report_file($c, $report_nr);
    if($report) {
        Thruk::Utils::Reports::generate_report_background($c, $report_nr, undef, $report);
        Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'report scheduled for update' });
    } else {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
    }
    return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi");
}

##########################################################

=head2 report_remove

=cut
sub report_remove {
    my($c, $report_nr) = @_;

    return unless Thruk::Utils::check_csrf($c);

    if(Thruk::Utils::Reports::report_remove($c, $report_nr)) {
        Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'report removed' });
    } else {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
    }
    return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi");
}

##########################################################

=head2 report_cancel

=cut
sub report_cancel {
    my($c, $report_nr) = @_;

    my $report = Thruk::Utils::Reports::_read_report_file($c, $report_nr);
    if($report) {
        if($report->{'var'}->{'is_waiting'}) {
            Thruk::Utils::Reports::set_running($c, $report_nr, 0);
            Thruk::Utils::Reports::set_waiting($c, $report_nr, 0, 0);
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'report canceled' });
        }
        elsif($report->{'var'}->{'job'}) {
            Thruk::Utils::External::cancel($c, $report->{'var'}->{'job'});
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'report canceled' });
        } else {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'report could not be canceled' });
        }
    } else {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
    }
    return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi");
}

##########################################################

=head2 report_profile

=cut
sub report_profile {
    my($c, $report_nr) = @_;

    my $data = '';
    my $report = Thruk::Utils::Reports::_read_report_file($c, $report_nr);
    if($report) {
        if($report->{'var'}->{'profile'}) {
            $data = $report->{'var'}->{'profile'};
        } else {
            $data = "no profile information available";
        }
    } else {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
    }
    my $json = { 'data' => $data };
    return $c->render(json => $json);
}

##########################################################

=head2 report_email

=cut
sub report_email {
    my($c, $report_nr) = @_;

    my $r = Thruk::Utils::Reports::_read_report_file($c, $report_nr);
    if(!defined $r) {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'report does not exist' });
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi");
    }

    if($c->req->parameters->{'send'}) {
        return unless Thruk::Utils::check_csrf($c);
        my $to      = $c->req->parameters->{'to'}      || '';
        my $cc      = $c->req->parameters->{'cc'}      || '';
        my $desc    = $c->req->parameters->{'desc'}    || '';
        my $subject = $c->req->parameters->{'subject'} || '';
        if($to) {
            local $ENV{'THRUK_MAIL_TEST'} = '/tmp/mailtest.'.$$ if $c->req->parameters->{'testmode'};
            Thruk::Utils::Reports::report_send($c, $report_nr, 1, $to, $cc, $subject, $desc);
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'report successfully sent by e-mail' });
            if($c->req->parameters->{'testmode'}) {
                Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'report successfully sent to testfile: '.$ENV{'THRUK_MAIL_TEST'} });
            }
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi?highlight=".$report_nr);
        }
        Thruk::Utils::set_message( $c, { style => 'success_message', msg => '\'to\' address missing' });
    }

    $c->stash->{size} = -s $c->config->{'var_path'}.'/reports/'.$r->{'nr'}.'.dat';
    if($r->{'var'}->{'attachment'} && (!$r->{'var'}->{'ctype'} || $r->{'var'}->{'ctype'} ne 'html2pdf')) {
        $c->stash->{attach}  = $r->{'var'}->{'attachment'};
    } else {
        $c->stash->{attach}  = 'report.pdf';
    }
    $c->stash->{subject} = $r->{'subject'} || 'Report: '.$r->{'name'};
    $c->stash->{r}       = $r;

    Thruk::Utils::ssi_include($c);
    $c->stash->{template} = 'reports_email.tt';
    return;
}

##########################################################
sub _set_report_data {
    my($c, $r) = @_;

    $c->stash->{'t1'} = $r->{'params'}->{'t1'} || time() - 86400;
    $c->stash->{'t2'} = $r->{'params'}->{'t2'} || time();
    $c->stash->{'t1'} = $c->stash->{'t1'} - $c->stash->{'t1'}%60;
    $c->stash->{'t2'} = $c->stash->{'t2'} - $c->stash->{'t2'}%60;

    $c->stash->{r}           = $r;
    $c->stash->{timeperiods} = $c->{'db'}->get_timeperiods(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'timeperiods')], remove_duplicates => 1, sort => 'name');
    $c->stash->{languages}   = Thruk::Utils::Reports::get_report_languages($c);

    Thruk::Utils::Reports::add_report_defaults($c, undef, $r);

    return;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
