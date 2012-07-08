package Thruk::Utils::Reports;

=head1 NAME

Thruk::Utils::Reports - Utilities Collection for Reporting

=head1 DESCRIPTION

Utilities Collection for Reporting

=cut

use warnings;
use strict;
use Carp;
use Class::Inspector;
use File::Slurp;
use Data::Dumper;
use Thruk::Utils::CLI;
use Thruk::Utils::PDF;
use MIME::Lite;

##########################################################

=head1 METHODS

=head2 get_report_list

  get_report_list($c)

return list of all reports for this user

=cut
sub get_report_list {
    my($c, $noauth) = @_;

    my $reports = [];
    for my $rfile (glob($c->config->{'var_path'}.'/reports/*.rpt')) {
        if($rfile =~ m/\/(\d+)\.rpt/mx) {
            my $r = _read_report_file($c, $1, undef, $noauth);
            push @{$reports}, $r if defined $r;
        }
    }

    # sort by name
    @{$reports} = sort { $a->{'name'} cmp $b->{'name'} } @{$reports};

    return $reports;
}

##########################################################

=head2 report_show

  report_show($c, $nr)

generate and show the report

=cut
sub report_show {
    my($c, $nr, $refresh) = @_;

    my $report = _read_report_file($c, $nr);
    if(!defined $report) {
        Thruk::Utils::set_message( $c, 'fail_message', 'no such report' );
        return $c->response->redirect('reports.cgi');
    }

    my $pdf_file = $c->config->{'tmp_path'}.'/reports/'.$nr.'.dat';
    if($refresh or ! -f $pdf_file) {
        generate_report($c, $nr, $report);
    }
    if(defined $pdf_file and -f $pdf_file) {
        if($report->{'var'}->{'attachment'}) {
            $c->stash->{'text'}     = read_file($pdf_file);
            $c->stash->{'template'} = 'passthrough.tt';
            $c->res->header( 'Content-Disposition', qq[attachment; filename="] . $report->{'var'}->{'attachment'} . q["] );
            $c->res->content_type($report->{'var'}->{'ctype'}) if $report->{'var'}->{'ctype'};
        } else {
            $c->stash->{'pdf_template'} = 'passthrough_pdf.tt';
            $c->stash->{'pdf_file'}     = $pdf_file;
            $c->stash->{'pdf_filename'} = $report->{'name'}.'.pdf'; # downloaded filename
            $c->forward('View::PDF::Reuse');
        }
    }
    return 1;
}

##########################################################

=head2 report_send

  report_send($c, $nr)

generate and send the report

=cut
sub report_send {
    my($c, $nr) = @_;

    my $report   = _read_report_file($c, $nr);
    if(!defined $report) {
        Thruk::Utils::set_message( $c, 'fail_message', 'no such report' );
        return $c->response->redirect('reports.cgi');
    }
    # make report available in template
    $c->stash->{'r'} = $report;

    my $attachment = generate_report($c, $nr, $report);
    if(defined $attachment) {

        $c->stash->{'block'} = 'mail';
        my $mailtext;
        eval {
            $c->stash->{'start'} = '' unless defined $c->stash->{'start'};
            $mailtext = $c->view("View::TT")->render($c, $c->stash->{'pdf_template'});
        };
        if($@) {
            Thruk::Utils::CLI::_error($@);
            return $c->detach('/error/index/13');
        }

        # extract mail header
        my $mailbody    = "";
        my $bodystarted = 0;
        my $mailheader  = {};
        for my $line (split/\n/mx, $mailtext) {
            if($line !~ m/^$/mx and $line !~ m/^[A-Z]+:/mx) {
                $bodystarted = 1;
            }
            if($bodystarted) {
                $mailbody .= $line."\n"
            } elsif($line =~ m/^([A-Z]+):\s*(.*)$/mx) {
                $mailheader->{lc($1)} = $2;
            }
            if($line =~ m/^$/mx) {
                $bodystarted = 1;
            }
        }
        my $msg = MIME::Lite->new();
        $msg->build(
                 From    => $report->{'from'}    || $mailheader->{'from'},
                 To      => $report->{'to'}      || $mailheader->{'to'},
                 Cc      => $report->{'cc'}      || $mailheader->{'cc'},
                 Bcc     => $report->{'bcc'}     || $mailheader->{'bcc'},
                 Subject => $report->{'subject'} || $mailheader->{'subject'} || 'Thruk Report',
                 Type    => 'multipart/mixed',
        );
        for my $key (keys %{$mailheader}) {
            my $value = $mailheader->{$key};
            $key = lc($key);
            next if $key eq 'from';
            next if $key eq 'to';
            next if $key eq 'cc';
            next if $key eq 'bcc';
            next if $key eq 'subject';
            $msg->add($key => $mailheader->{$key});
        }
        $msg->attach(Type     => 'TEXT',
                     Data     => $mailbody,
        );

        if($report->{'var'}->{'attachment'}) {
            $msg->attach(Type    => $report->{'var'}->{'ctype'},
                     Path        => $attachment,
                     Filename    => $report->{'var'}->{'attachment'},
                     Disposition => 'attachment',
            );
        } else {
            $msg->attach(Type    => 'application/pdf',
                     Path        => $attachment,
                     Filename    => 'report.pdf',
                     Disposition => 'attachment',
            );
        }
        return 1 if $msg->send;
    }
    Thruk::Utils::set_message( $c, 'fail_message', 'failed to send report' );
    return 0;
}

##########################################################

=head2 report_save

  report_save($c, $nr, $data)

save a report

=cut
sub report_save {
    my($c, $nr, $data) = @_;
    Thruk::Utils::IO::mkdir($c->config->{'var_path'}.'/reports/',
                            $c->config->{'tmp_path'}.'/reports/');
    my $file = $c->config->{'var_path'}.'/reports/'.$nr.'.rpt';
    my $old_report;
    if($nr ne 'new' and -f $file) {
        $old_report = _read_report_file($c, $nr);
        return unless defined $old_report;
    }
    my $report       = _get_new_report($c, $data);
    $report->{'var'} = $old_report->{'var'} if defined $old_report->{'var'};
    return _report_save($c, $nr, $report);
}

##########################################################

=head2 report_remove

  report_remove($c, $nr)

remove report

=cut
sub report_remove {
    my($c, $nr) = @_;

    my $report = _read_report_file($c, $nr);
    return unless defined $report;
    return unless defined $report->{'readonly'};
    return unless $report->{'readonly'} == 0;

    my @files;
    push @files, $c->config->{'var_path'}.'/reports/'.$nr.'.rpt' if -e $c->config->{'var_path'}.'/reports/'.$nr.'.rpt';
    push @files, $c->config->{'tmp_path'}.'/reports/'.$nr.'.dat' if -e $c->config->{'tmp_path'}.'/reports/'.$nr.'.dat';
    push @files, $c->config->{'tmp_path'}.'/reports/'.$nr.'.log' if -e $c->config->{'tmp_path'}.'/reports/'.$nr.'.log';
    return 1 if unlink @files;

    # remove cron entries
    Thruk::Utils::Reports::update_cron_file($c);

    return;
}

##########################################################

=head2 generate_report

  generate_report($c, $nr, $options)

generate a new report

=cut
sub generate_report {
    my($c, $nr, $options) = @_;
    $Thruk::Utils::PDF::c = $c;
    $Thruk::Utils::CLI::c = $c;
    $Thruk::Utils::PDF::attachment = '';
    $Thruk::Utils::PDF::ctype      = '';

    $c->stash->{'tmp_files_to_delete'} = [];

    $c->stats->profile(begin => "Utils::Reports::generate_report()");
    $options = _read_report_file($c, $nr) unless defined $options;
    return unless defined $options;

    Thruk::Utils::set_user($c, $options->{'user'});
    $ENV{'REMOTE_USER'} = $options->{'user'};

    Thruk::Utils::IO::mkdir($c->config->{'tmp_path'}.'/reports/');
    my $attachment = $c->config->{'tmp_path'}.'/reports/'.$nr.'.dat';
    $c->stash->{'attachment'} = $attachment;

    # report is already beeing generated
    if($options->{'var'}->{'is_running'} > 0) {
        while($options->{'var'}->{'is_running'} > 0) {
            if(kill(0, $options->{'var'}->{'is_running'}) != 1) {
                unlink($attachment);
                last;
            }
            sleep 1;
        }
        # just wait till its finished and return
        if(-e $attachment) {
            return $attachment;
        }
    }

    # empty logfile
    my $logfile = $c->config->{'tmp_path'}.'/reports/'.$nr.'.log';
    open(my $fh, '>', $logfile);
    Thruk::Utils::IO::close($fh, $logfile);

    # update report runtime data
    set_running($c, $nr, $$, time());

    if(defined $options->{'backends'}) {
        $options->{'backends'} = ref $options->{'backends'} eq 'ARRAY' ? $options->{'backends'} : [ $options->{'backends'} ];
    }
    local $ENV{'THRUK_BACKENDS'} = join(',', @{$options->{'backends'}}) if(defined $options->{'backends'} and scalar @{$options->{'backends'}} > 0);

    # set some defaults
    Thruk::Utils::PDF::set_unavailable_states([qw/DOWN UNREACHABLE CRITICAL UNKNOWN/]);
    $c->{'request'}->{'parameters'}->{'show_log_entries'}           = 1;
    $c->{'request'}->{'parameters'}->{'assumeinitialstates'}        = 'yes';
    $c->{'request'}->{'parameters'}->{'initialassumedhoststate'}    = 3; # UP
    $c->{'request'}->{'parameters'}->{'initialassumedservicestate'} = 6; # OK


    $c->stash->{'param'} = $options->{'params'};
    $c->stash->{'r'}     = $options;
    for my $p (keys %{$options->{'params'}}) {
        $c->{'request'}->{'parameters'}->{$p} = $options->{'params'}->{$p};
    }

    if(!defined $options->{'template'} or !Thruk::Utils::PDF::path_to_template('pdf/'.$options->{'template'})) {
        confess('template pdf/'.$options->{'template'}.' does not exist');
    }

    # set some render helper
    for my $s (@{Class::Inspector->functions('Thruk::Utils::PDF')}) {
        $c->stash->{$s} = \&{'Thruk::Utils::PDF::'.$s};
    }

    # prepare report
    $c->stash->{'pdf_template'} = 'pdf/'.$options->{'template'};
    $c->stash->{'block'} = 'prepare';
    eval {
        $c->view("PDF::Reuse")->render_pdf($c);
    };
    if($@) {
        Thruk::Utils::CLI::_error($@);
        return $c->detach('/error/index/13');
    }

    # render report
    $c->stash->{'block'} = 'render';
    my $attach_data;
    eval {
        $attach_data = $c->view("PDF::Reuse")->render_pdf($c);
    };
    if($@) {
        Thruk::Utils::CLI::_error($@);
        return $c->detach('/error/index/13');
    }

    # write out attachment
    if($Thruk::Utils::PDF::attachment eq '') {
        open($fh, '>', $attachment);
        binmode $fh;
        print $fh $attach_data;
        Thruk::Utils::IO::close($fh, $attachment);
    }

    # clean up tmp files
    for my $file (@{$c->stash->{'tmp_files_to_delete'}}) {
        unlink($file);
    }

    # update report runtime data
    set_running($c, $nr, 0, undef, time());

    $c->stats->profile(end => "Utils::Reports::generate_report()");
    return $attachment;
}

##########################################################

=head2 get_report_data_from_param

  get_report_data_from_param($params)

return report data for given params

=cut
sub get_report_data_from_param {
    my $params = shift;
    my $p = {};
    for my $key (keys %{$params}) {
        next unless $key =~ m/^params\.([\w\.]+)$/mx;
        if(ref $params->{$key} eq 'ARRAY') {
            # remove empty elements
            @{$params->{$key}} = grep(!/^$/mx, @{$params->{$key}});
        }
        $p->{$1} = $params->{$key};
    }

    my $send_types = Thruk::Utils::get_cron_entries_from_param($params);
    my $data = {
        'name'       => $params->{'name'}        || 'New Report',
        'desc'       => $params->{'desc'}        || '',
        'template'   => $params->{'template'}    || 'sla.tt',
        'is_public'  => $params->{'is_public'}   || 0,
        'to'         => $params->{'to'}          || '',
        'cc'         => $params->{'cc'}          || '',
        'backends'   => $params->{'backends'}    || [],
        'params'     => $p,
        'send_types' => $send_types,
    };

    return($data);
}

##########################################################

=head2 update_cron_file

  update_cron_file($c)

update reporting cronjobs

=cut
sub update_cron_file {
    my($c) = @_;

    # gather reporting send types from all reports
    my $cron_entries = [];
    my $reports = get_report_list($c, 1);
    @{$reports} = sort { $a->{'nr'} <=> $b->{'nr'} } @{$reports};
    for my $r (@{$reports}) {
        next unless defined $r->{'send_types'};
        next unless scalar @{$r->{'send_types'}} > 0;
        my $mail = 0;
        $mail = 1 if ($r->{'to'} or $r->{'cc'});
        for my $st (@{$r->{'send_types'}}) {
            $st->{'nr'} = $r->{'nr'};
            push @{$cron_entries}, [_get_cron_entry($c, $r, $st, $mail)];
        }
    }

    Thruk::Utils::update_cron_file($c, 'reports', $cron_entries);
    return 1;
}

##########################################################

=head2 set_running

  set_running($c)

update running state of report

=cut
sub set_running {
    my($c, $nr, $val, $start, $end) = @_;
    my $options = _read_report_file($c, $nr);
    $options->{'var'}->{'is_running'} = $val;
    $options->{'var'}->{'start_time'} = $start if defined $start;
    $options->{'var'}->{'end_time'}   = $end   if defined $end;
    $options->{'var'}->{'attachment'} = $Thruk::Utils::PDF::attachment if defined $Thruk::Utils::PDF::attachment;
    $options->{'var'}->{'ctype'}      = $Thruk::Utils::PDF::ctype      if defined $Thruk::Utils::PDF::ctype;
    _report_save($c, $nr, $options);
    return;
}

##########################################################
sub _get_cron_entry {
    my($c, $report, $st, $mail) = @_;

    my $cmd = _get_report_cmd($c, $report, $mail);
    my $time = Thruk::Utils::get_cron_time_entry($st);
    return($time, $cmd);
}

##########################################################
sub _get_new_report {
    my($c, $data) = @_;
    $data = {} unless defined $data;
    my $r = {
        'name'       => 'New Report',
        'desc'       => 'Description',
        'nr'         => 'new',
        'template'   => '',
        'params'     => {},
        'var'        => {},
        'to'         => '',
        'cc'         => '',
        'is_public'  => 0,
        'user'       => $c->stash->{'remote_user'},
        'backends'   => [],
        'send_types' => [],
    };
    for my $key (keys %{$data}) {
        $r->{$key} = $data->{$key};
    }
    return $r;
}

##########################################################
sub _report_save {
    my($c, $nr, $report) = @_;
    Thruk::Utils::IO::mkdir($c->config->{'var_path'}.'/reports/');
    my $file = $c->config->{'var_path'}.'/reports/'.$nr.'.rpt';
    if($nr eq 'new') {
        # find next free number
        $nr = 1;
        $file = $c->config->{'var_path'}.'/reports/'.$nr.'.rpt';
        while(-e $file) {
            $nr++;
            $file = $c->config->{'var_path'}.'/reports/'.$nr.'.rpt';
        }
    }
    delete $report->{'readonly'};
    delete $report->{'nr'};
    delete $report->{'error'};
    delete $report->{'failed'};

    Thruk::Utils::write_data_file($file, $report);
    return $nr;
}

##########################################################
sub _read_report_file {
    my($c, $nr, $rdata, $noauth) = @_;
    unless($nr =~ m/^\d+$/mx) {
        Thruk::Utils::CLI::_error("not a valid report number");
        return $c->detach('/error/index/13');
    }
    my $file = $c->config->{'var_path'}.'/reports/'.$nr.'.rpt';
    unless(-f $file) {
        Thruk::Utils::CLI::_error("report does not exist: $!");
        return $c->detach('/error/index/13');
    }

    my $report = Thruk::Utils::read_data_file($file);
    $report->{'nr'} = $nr;
    # add defaults
    $report = _get_new_report($c, $report);

    unless($noauth) {
        $report->{'readonly'}   = 1;
        my $authorized = _is_authorized_for_report($c, $report);
        return unless $authorized;
        $report->{'readonly'}   = 0 if $authorized == 1;
    }

    # add some runtime information
    my $rfile = $c->config->{'tmp_path'}.'/reports/'.$nr.'.dat';
    $report->{'var'}->{'file_exists'} = 0;
    $report->{'var'}->{'file_exists'} = 1  if -f $rfile;
    $report->{'var'}->{'is_running'}  = 0  unless defined $report->{'var'}->{'is_running'};
    $report->{'var'}->{'start_time'}  = 0  unless defined $report->{'var'}->{'start_time'};
    $report->{'var'}->{'end_time'}    = 0  unless defined $report->{'var'}->{'end_time'};
    $report->{'var'}->{'ctype'}       = '' unless defined $report->{'var'}->{'ctype'};
    $report->{'var'}->{'attachment'}  = '' unless defined $report->{'var'}->{'attachment'};
    $report->{'desc'}       = '' unless defined $report->{'desc'};
    $report->{'to'}         = '' unless defined $report->{'to'};
    $report->{'cc'}         = '' unless defined $report->{'cc'};
    $report->{'is_public'}  = 0 unless defined $report->{'is_public'};

    # check if its really running
    if($report->{'var'}->{'is_running'} and kill(0, $report->{'var'}->{'is_running'}) != 1) {
        $report->{'var'}->{'is_running'} = 0;
    }
    if($report->{'var'}->{'is_running'} == -1 and $report->{'var'}->{'start_time'} < time() - 10) {
        $report->{'var'}->{'is_running'} = 0;
    }
    if($report->{'var'}->{'end_time'} < $report->{'var'}->{'start_time'}) {
        $report->{'var'}->{'end_time'} = $report->{'var'}->{'start_time'};
    }

    # failed?
    my $log = $c->config->{'tmp_path'}.'/reports/'.$nr.'.log';
    $report->{'failed'} = 0;
    if(-s $log) {
        $report->{'failed'} = 1;
        $report->{'error'}  = read_file($log);
        $report->{'var'}->{'is_running'} = 0;
    }


    # preset values from data
    if(defined $rdata) {
        for my $key (keys %{$rdata}) {
            $report->{$key} = $rdata->{$key};
        }
    }

    return $report;
}

##########################################################
sub _is_authorized_for_report {
    my($c, $report) = @_;
    return 1 if defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'CLI';
    if(defined $report->{'user'} and defined $c->stash->{'remote_user'} and $report->{'user'} eq $c->stash->{'remote_user'}) {
        return 1;
    }
    if(defined $report->{'is_public'} and $report->{'is_public'} == 1) {
        return 2;
    }
    Thruk::Utils::CLI::_debug("user: ".(defined $c->stash->{'remote_user'} ? $c->stash->{'remote_user'} : '?')." is not authorized for report: ".$report->{'nr'});
    return;
}

##########################################################
sub _get_report_cmd {
    my($c, $report, $mail) = @_;
    Thruk::Utils::IO::mkdir($c->config->{'var_path'}.'/reports/',
                            $c->config->{'tmp_path'}.'/reports/');
    my $thruk_bin = $c->config->{'thruk_bin'};
    my $type      = 'report';
    if($mail) {
        $type = 'reportmail';
    }
    my $nice = '/usr/bin/nice';
    if(-e '/bin/nice') { $nice = '/bin/nice'; }
    if($c->config->{'report_nice_level'} > 0) {
        $thruk_bin = $nice.' -n '.$c->config->{'report_nice_level'}.' '.$thruk_bin;
    }
    my $cmd = sprintf("cd %s && %s '%s --local -a % 10s=%-3s' >/dev/null 2>%s/reports/%d.log",
                            $c->config->{'project_root'},
                            $c->config->{'thruk_shell'},
                            $thruk_bin,
                            $type,
                            $report->{'nr'},
                            $c->config->{'tmp_path'},
                            $report->{'nr'},
                    );
    return $cmd;
}

##########################################################

1;
