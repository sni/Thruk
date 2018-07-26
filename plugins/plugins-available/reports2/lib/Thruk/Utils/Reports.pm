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
use Thruk::Utils::Reports::Render;
use MIME::Lite;
use File::Copy;
use Encode qw(encode_utf8 decode_utf8 encode);
use Storable qw/dclone/;
use File::Temp qw/tempfile/;
use Cwd qw//;
use Digest::MD5 qw(md5_hex);

##########################################################

=head1 METHODS

=head2 get_report_list

  get_report_list($c, [$noauth], [$nr])

return list of all reports for this user

=cut
sub get_report_list {
    my($c, $noauth, $number_filter) = @_;

    my $reports = [];
    for my $rfile (glob($c->config->{'var_path'}.'/reports/*.rpt')) {
        if($rfile =~ m/\/(\d+)\.rpt/mx) {
            my $nr = $1;
            next if $number_filter && $nr != $number_filter;
            my $r  = _read_report_file($c, $nr, undef, $noauth, 1);
            next unless $r;
            if($r->{'var'} and $r->{'var'}->{'job'}) {
                my($is_running,$time,$percent,$message,$forward) = Thruk::Utils::External::get_status($c, $r->{'var'}->{'job'});
                $r->{'var'}->{'job_data'} = {
                    time    => $time,
                    percent => $percent,
                    message => $message,
                } if defined $time;
            }
            push @{$reports}, $r;
        }
    }

    # sort by name
    @{$reports} = sort { $a->{'name'} cmp $b->{'name'} } @{$reports};

    return $reports;
}

##########################################################

=head2 get_report

  get_report_list($c, $nr, [$noauth])

return report for given id

=cut
sub get_report {
    my($c, $nr, $noauth) = @_;

    my $reports = get_report_list($c, $noauth, $nr);
    if(!$reports->[0]) {
        die("no such report: ".$nr);
    }
    return $reports->[0];
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
        return $c->redirect_to('reports2.cgi');
    }

    my $report_file = $c->config->{'var_path'}.'/reports/'.$nr.'.dat';
    if($refresh || ! -f $report_file) {
        generate_report($c, $nr);
    }

    if(defined $report_file and -f $report_file) {
        $c->stash->{'template'} = 'passthrough.tt';
        if($c->req->parameters->{'html'}) {
            my $html_file   = $c->config->{'var_path'}.'/reports/'.$nr.'.html';
            if(!-e $html_file) {
                $html_file = $c->config->{'var_path'}.'/reports/'.$nr.'.dat';
            }
            my $report_text = decode_utf8(read_file($html_file));
            $report_text    =~ s/^<body>/<body class="preview">/mx;
            $c->stash->{'text'} = $report_text;
        }
        elsif($report->{'var'}->{'attachment'} && (!$report->{'var'}->{'ctype'} || $report->{'var'}->{'ctype'} ne 'html2pdf')) {
            my $name = $report->{'var'}->{'attachment'};
            $name    =~ s/\s+/_/gmx;
            $name    =~ s/[^\wöäüÖÄÜß\-_\.]+//gmx;
            $c->res->headers->header( 'Content-Disposition', 'attachment; filename="'.$name.'"' );
            $c->res->headers->content_type($report->{'var'}->{'ctype'}) if $report->{'var'}->{'ctype'};
            my $fh;
            if($report->{'var'}->{'ctype'} eq 'text/html') {
                open($fh, '<', $c->config->{'var_path'}.'/reports/'.$nr.'.html');
            } else {
                open($fh, '<', $report_file);
            }
            binmode $fh;
            $c->res->body($fh);
            $c->{'rendered'} = 1;
            return 1;
        } else {
            my $name = $report->{'name'};
            $name    =~ s/\s+/_/gmx;
            $name    =~ s/[^\wöäüÖÄÜß\-_\.]+//gmx;
            $c->res->headers->content_type('application/pdf');
            $c->res->headers->header( 'Content-Disposition', 'filename='.$name.'.pdf' );
            open(my $fh, '<', $report_file);
            binmode $fh;
            $c->res->body($fh);
            $c->{'rendered'} = 1;
            return 1;
        }
    } else {
        if($Thruk::Utils::Reports::error) {
            Thruk::Utils::set_message( $c, 'fail_message', 'generating report failed: '.$Thruk::Utils::Reports::error );
        } else {
            Thruk::Utils::set_message( $c, 'fail_message', 'generating report failed' );
        }
        return $c->redirect_to('reports2.cgi');
    }
    return 1;
}

##########################################################

=head2 report_send

  report_send($c, $nr, [$skip_generate, $to, $cc, $subject, $desc])

generate and send the report

=cut
sub report_send {
    my($c, $nr, $skip_generate, $to, $cc, $subject, $desc) = @_;
    $c->stats->profile(begin => "Utils::Reports::report_send()");

    if($c->config->{'demo_mode'}) {
        Thruk::Utils::set_message( $c, 'fail_message', 'sending mails disabled in demo mode');
        return $c->redirect_to('reports2.cgi');
    }

    my $report = _read_report_file($c, $nr);
    if(!defined $report) {
        Thruk::Utils::set_message( $c, 'fail_message', 'no such report' );
        return $c->redirect_to('reports2.cgi');
    }
    # make report available in template
    $report->{'desc'} = $desc if $to;
    $c->stash->{'r'} = $report;

    local $SIG{CHLD} = 'DEFAULT';
    local $SIG{PIPE} = 'DEFAULT';

    my $attachment;
    if($skip_generate) {
        $attachment = $c->config->{'var_path'}.'/reports/'.$report->{'nr'}.'.dat';
        if(!-s $attachment) {
            Thruk::Utils::set_message( $c, 'fail_message', 'report not yet generated' );
            return $c->redirect_to('reports2.cgi');
        }
    } else {
        $attachment = generate_report($c, $nr);
    }
    $report = _read_report_file($c, $nr); # update report data, attachment would be wrong otherwise
    _initialize_report_templates($c, $report);
    if(!defined $attachment) {
        Thruk::Utils::set_message( $c, 'fail_message', 'failed to send report' );
        return 0;
    }
    if($attachment eq "-2") {
        return(-2);
    }

    # mail should not be sent
    if(defined $report->{'var'}->{'send_mail_threshold_reached'} && !$report->{'var'}->{'send_mail_threshold_reached'}) {
        return 2;
    }

    $c->stash->{'block'} = 'mail';
    my $mailtext;
    eval {
        $c->stash->{'start'} = '' unless defined $c->stash->{'start'};
        Thruk::Views::ToolkitRenderer::render($c, 'reports/'.$report->{'template'}, undef, \$mailtext);
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
            $mailbody .= $line."\n";
        } elsif($line =~ m/^([A-Z]+):\s*(.*)$/mx) {
            $mailheader->{lc($1)} = $2;
        }
        if($line =~ m/^$/mx) {
            $bodystarted = 1;
        }
    }
    my $bcc  = '';
    my $from = $report->{'from'} || $mailheader->{'from'} || $c->config->{'Thruk::Plugin::Reports2'}->{'report_from_email'};
    if(!$to) {
        $to      = $report->{'to'}      || $mailheader->{'to'};
        $cc      = $report->{'cc'}      || $mailheader->{'cc'};
        $bcc     = $report->{'bcc'}     || $mailheader->{'bcc'};
        $subject = $report->{'subject'} || $mailheader->{'subject'} || 'Thruk Report';
    }
    my $msg = MIME::Lite->new();
    $msg->build(
             From    => $from,
             To      => $to,
             Cc      => $cc,
             Bcc     => $bcc,
             Subject => encode("MIME-B", decode_utf8($subject)),
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
    $msg->attach(Type     => 'text/plain; charset=UTF-8',
                 Data     => $mailbody,
    );

    # url reports as html
    if(defined $report->{'params'}->{'pdf'} && $report->{'params'}->{'pdf'} eq 'no') {
        $attachment = $c->config->{'var_path'}.'/reports/'.$report->{'nr'}.'.html';
        if(!-s $attachment) {
            $attachment = $c->config->{'var_path'}.'/reports/'.$report->{'nr'}.'.dat';
        }
        my $ctype = 'text/html';
        if($report->{'var'}->{'ctype'} && $report->{'var'}->{'ctype'} ne 'html2pdf') {
            $ctype = $report->{'var'}->{'ctype'};
        }
        $msg->attach(Type    => $ctype,
                 Path        => $attachment,
                 Filename    => encode_utf8($report->{'var'}->{'attachment'}),
                 Disposition => 'attachment',
        );
    }
    elsif($report->{'var'}->{'attachment'} && (!$report->{'var'}->{'ctype'} || $report->{'var'}->{'ctype'} ne 'html2pdf')) {
        $msg->attach(Type    => $report->{'var'}->{'ctype'},
                 Path        => $attachment,
                 Filename    => encode_utf8($report->{'var'}->{'attachment'}),
                 Disposition => 'attachment',
        );
    } else {
        $msg->attach(Type    => 'application/pdf',
                 Path        => $attachment,
                 Filename    => 'report.pdf',
                 Disposition => 'attachment',
        );
    }

    if($ENV{'THRUK_MAIL_TEST'}) {
        $msg->send_by_testfile($ENV{'THRUK_MAIL_TEST'});
        return 1;
    } else {
        return 1 if $msg->send;
    }
    $c->stats->profile(end => "Utils::Reports::report_send()");
    return 0;
}

##########################################################

=head2 report_save

  report_save($c, $nr, $data)

save a report

=cut
sub report_save {
    my($c, $nr, $data) = @_;

    Thruk::Utils::IO::mkdir($c->config->{'var_path'}.'/reports/');
    my $file = $c->config->{'var_path'}.'/reports/'.$nr.'.rpt';
    my $old_report;
    if($nr ne 'new' and -f $file) {
        $old_report = _read_report_file($c, $nr);
        return unless defined $old_report;
    }
    my $report        = _get_new_report($c, $data);
    $report->{'var'}  = $old_report->{'var'}  if defined $old_report->{'var'};
    $report->{'user'} = $old_report->{'user'} if defined $old_report->{'user'};
    my $fields;
    eval {
        $fields       = _get_required_fields($c, $report);
    };
    if($@) {
        Thruk::Utils::set_message( $c, 'fail_message', 'report template had errors or does not exist');
        $c->log->error($@);
        $report->{'var'}->{'opt_errors'} = ['report template had errors or does not exist'];
    }
    _verify_fields($c, $fields, $report);
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

    unlink($c->config->{'var_path'}.'/reports/'.$nr.'.rpt') if -e $c->config->{'var_path'}.'/reports/'.$nr.'.rpt';
    clean_report_tmp_files($c, $nr);

    # remove cron entries
    update_cron_file($c);

    return 1;
}

##########################################################

=head2 generate_report

  generate_report($c, $nr)

generate a new report

=cut
sub generate_report {
    my($c, $nr) = @_;
    $Thruk::Utils::PDF::attachment     = '';
    $Thruk::Utils::PDF::ctype          = 'html2pdf';
    $c->stash->{'tmp_files_to_delete'} = [];

    Thruk::Utils::IO::mkdir($c->config->{'var_path'}.'/reports/');
    my $report_file = $c->config->{'var_path'}.'/reports/'.$nr.'.rpt';
    my $attachment  = $c->config->{'var_path'}.'/reports/'.$nr.'.dat';
    $c->stash->{'attachment'} = $attachment;

    # set waiting flag on queued reports
    $c->stats->profile(begin => "Utils::Reports::generate_report()");
    my $options = _read_report_file($c, $nr);
    unless(defined $options) {
        $Thruk::Utils::Reports::error = 'got no report options';
        return;
    }

    set_waiting($c, $nr, 0);

    # don't run report twice per minute
    if($ENV{'THRUK_CRON'} && !($options->{'var'}->{'is_running'} == $$ && $options->{'var'}->{'running_node'} eq $Thruk::NODE_ID)) {
        if($options->{'var'}->{'start_time'}) {
            if(POSIX::strftime("%Y-%m-%d %H:%M", localtime($options->{'var'}->{'start_time'})) eq POSIX::strftime("%Y-%m-%d %H:%M", localtime())) {
                return -2;
            }
        }
    }

    set_running($c, $nr, $$, time()) unless $options->{'var'}->{'is_running'} > 0;

    # report is already beeing generated, check if the other process is alive
    if($options->{'var'}->{'is_running'} > 0 && ($options->{'var'}->{'is_running'} != $$ || $options->{'var'}->{'running_node'} ne $Thruk::NODE_ID)) {
        # if started by cron, just exit, some other node is doing the report already
        return -2 if $ENV{'THRUK_CRON'};

        # just wait till its finished and return
        while($options->{'var'}->{'is_running'}) {
            sleep 1;
            $options = _read_report_file($c, $nr);
        }
        if(-e $attachment) {
            return $attachment;
        }
    }

    # update report runtime data
    set_running($c, $nr, $$, time());

    my $default_time_locale = POSIX::setlocale(POSIX::LC_TIME);

    $c->req->parameters->{'debug'} = 1 if $ENV{'THRUK_REPORT_DEBUG'};

    Thruk::Utils::set_user($c, $options->{'user'});
    local $ENV{'REMOTE_USER'} = $options->{'user'};
    $c->stash->{'remote_user'} = $options->{'user'};

    $c->stash->{'refresh_rate'}   = 0;
    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{'inject_stats'}   = 0;

    # clean up first
    clean_report_tmp_files($c, $nr);

    if($options->{'var'}->{'debug_file'}) {
        unlink($options->{'var'}->{'debug_file'});
        undef($options->{'var'}->{'debug_file'});
    }

    # empty logfile
    my $logfile = $c->config->{'var_path'}.'/reports/'.$nr.'.log';
    open(my $fh, '>', $logfile);
    Thruk::Utils::IO::close($fh, $logfile);

    # check for exposed custom variables
    my $allowed = Thruk::Utils::list($c->config->{'show_custom_vars'});
    for my $key (qw/hostnameformat_cust servicenameformat_cust/) {
        if($options->{'params'}->{$key}) {
            if(!Thruk::Utils::check_custom_var_list($options->{'params'}->{$key}, $allowed)) {
                return(_report_die($c, "report contains custom variable ".$options->{'params'}->{$key}." which is not exposed by: show_custom_vars", $logfile));
            }
        }
    }

    # do we have errors in our options, ex.: missing required fields?
    if(defined $options->{'var'}->{'opt_errors'}) {
        set_running($c, $nr, 0, undef, time());
        return(_report_die($c, join("\n", @{$options->{'var'}->{'opt_errors'}}), $logfile));
    }

    Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 1, 'starting') if $ENV{'THRUK_JOB_DIR'};
    delete $options->{'var'}->{'send_mail_threshold_reached'};

    if(defined $options->{'backends'}) {
        $options->{'backends'} = ref $options->{'backends'} eq 'ARRAY' ? $options->{'backends'} : [ $options->{'backends'} ];
    }
    local $ENV{'THRUK_BACKENDS'} = join(';', @{$options->{'backends'}}) if(defined $options->{'backends'} and scalar @{$options->{'backends'}} > 0);

    # need to update defaults backends
    my($disabled_backends,$has_groups);
    eval {
        ($disabled_backends,$has_groups) = Thruk::Action::AddDefaults::_set_enabled_backends($c);
        Thruk::Action::AddDefaults::_set_possible_backends($c, $disabled_backends);
    };
    if($@) {
        return(_report_die($c, $@, $logfile));
    }

    Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 2, 'getting backends') if $ENV{'THRUK_JOB_DIR'};

    # check backend connections
    my $processinfo = $c->{'db'}->get_processinfo();
    if($options->{'backends'}) {
        my @failed;
        for my $b (keys %{$disabled_backends}) {
            next unless $disabled_backends->{$b} == 0;
            if($c->stash->{'failed_backends'}->{$b}) {
                push @failed, $c->{'db'}->get_peer_by_key($b)->peer_name().': '.$c->stash->{'failed_backends'}->{$b};
            }
        }
        if($options->{'failed_backends'} eq 'cancel') {
            if(scalar @failed > 0) {
                my $error = "Some backends are not connected, cannot create report!\n".join("\n", @failed)."\n";
                return(_report_die($c, $error, $logfile));
            }
        }
    }
    $c->stash->{'selected_backends'} = [];
    for my $b (keys %{$disabled_backends}) {
        next unless $disabled_backends->{$b} == 0;
        push @{$c->stash->{'selected_backends'}}, $b;
    }

    Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 3, 'setting defaults') if $ENV{'THRUK_JOB_DIR'};

    # set some defaults
    Thruk::Utils::Reports::Render::set_unavailable_states([qw/DOWN UNREACHABLE CRITICAL UNKNOWN/]);
    $c->req->parameters->{'show_log_entries'}           = 1;
    $c->req->parameters->{'assumeinitialstates'}        = 'yes';
    #$c->req->parameters->{'initialassumedhoststate'}    = 3; # UP
    #$c->req->parameters->{'initialassumedservicestate'} = 6; # OK
    $c->req->parameters->{'initialassumedhoststate'}    = 0; # Unspecified
    $c->req->parameters->{'initialassumedservicestate'} = 0; # Unspecified

    if(!defined $options->{'template'}) {
        confess('template reports/'.$options->{'template'}.' does not exist');
    }

    Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 4, 'initializing') if $ENV{'THRUK_JOB_DIR'};
    _initialize_report_templates($c, $options);

    # disable tt cache to read custom templates every time
    my $orig_stat_ttl = $c->app->{'tt'}->context->{'LOAD_TEMPLATES'}->[0]->{'STAT_TTL'};
    $c->app->{'tt'}->context->{'LOAD_TEMPLATES'}->[0]->{'STAT_TTL'} = 0;

    # prepage stage, functions here could still change stash
    eval {
        Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 5, 'preparing') if $ENV{'THRUK_JOB_DIR'};
        $c->stash->{'block'} = 'prepare';
        my $discard;
        Thruk::Views::ToolkitRenderer::render($c, 'reports/'.$options->{'template'}, undef, \$discard);
    };
    if($@) {
        return(_report_die($c, $@, $logfile));
    }

    # render report
    $c->stash->{'param'}->{'mail_max_level_count'} = 0;
    my $reportdata;
    eval {
        Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 80, 'rendering') if $ENV{'THRUK_JOB_DIR'};
        $c->stash->{'block'} = 'render';
        Thruk::Views::ToolkitRenderer::render($c, 'reports/'.$options->{'template'}, undef, \$reportdata);
    };
    if($@) {
        return(_report_die($c, $@, $logfile));
    }
    POSIX::setlocale(POSIX::LC_TIME, $default_time_locale);

    # convert to pdf
    if($Thruk::Utils::PDF::ctype eq 'text/html') {
        if(!$options->{'params'}->{'pdf'} || $options->{'params'}->{'pdf'} eq 'yes') {
            $Thruk::Utils::PDF::ctype = "html2pdf";
        }
        my $htmlfile = $c->config->{'var_path'}.'/reports/'.$nr.'.html';
        move($attachment, $htmlfile);
        Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 90, 'converting') if $ENV{'THRUK_JOB_DIR'};
        _convert_to_pdf($c, $reportdata, $attachment, $nr, $logfile);
    }
    elsif($Thruk::Utils::PDF::ctype eq 'html2pdf') {
        Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 90, 'converting') if $ENV{'THRUK_JOB_DIR'};
        _convert_to_pdf($c, $reportdata, $attachment, $nr, $logfile);
    }

    # set error if not already set
    if(!-f $attachment && !$Thruk::Utils::Reports::error) {
        $Thruk::Utils::Reports::error = read_file($logfile);
    }
    Thruk::Utils::CLI::_error($Thruk::Utils::Reports::error);

    # check backend errors from during report generation
    if($options->{'backends'}) {
        my @failed;
        for my $b (@{$options->{'backends'}}) {
            if($c->stash->{'failed_backends'}->{$b}) {
                push @failed, $c->{'db'}->get_peer_by_key($b)->peer_name().': '.$c->stash->{'failed_backends'}->{$b};
            }
        }
        if($options->{'failed_backends'} eq 'cancel' and scalar @failed > 0) {
            unlink($attachment);
            my $error = "Some backends threw errors, cannot create report!\n".join("\n", @failed)."\n";
            return(_report_die($c, $error, $logfile));
        }
    }

    Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 95, 'clean up') if $ENV{'THRUK_JOB_DIR'};

    # clean up tmp files
    for my $file (@{$c->stash->{'tmp_files_to_delete'}}) {
        unlink($file);
    }

    if($c->stash->{'debug_info'}) {
        my $debug_file = Thruk::Action::AddDefaults::save_debug_information_to_tmp_file($c);
        if($debug_file) {
            my $rpt_debug_file = $c->config->{'var_path'}.'/reports/'.$nr.'.dbg';
            if(-s $debug_file > 1000000) {
                `gzip $debug_file >/dev/null 2>&1`;
                if(!-s $debug_file && -s $debug_file.'.gz') {
                    $rpt_debug_file = $c->config->{'var_path'}.'/reports/'.$nr.'.dbg.gz';
                    move($debug_file.'.gz', $rpt_debug_file);
                }
            } else {
                move($debug_file, $rpt_debug_file);
            }
            my $patch = {};
            Thruk::Utils::IO::json_lock_patch($report_file, { var => { debug_file => $rpt_debug_file } }, 1);
        }
    }

    # restore tt cache settings
    $c->app->{'tt'}->context->{'LOAD_TEMPLATES'}->[0]->{'STAT_TTL'} = $orig_stat_ttl;

    $c->stats->profile(end => "Utils::Reports::generate_report()");

    my $send_mail_threshold_reached = 1;
    if(defined $c->stash->{'param'}->{'mail_max_level'} && $c->stash->{'param'}->{'mail_max_level'} != -1) {
        $send_mail_threshold_reached = 0;
        if($c->stash->{'param'}->{'mail_max_level_count'} > 0) {
            $send_mail_threshold_reached = 1;
        }
        Thruk::Utils::IO::json_lock_patch($report_file, { var => { send_mail_threshold_reached => $send_mail_threshold_reached } }, 1);
    }

    if($options->{'var'}->{'send_mails_next_time'} && $send_mail_threshold_reached) {
        report_send($c, $nr, 1);
    }
    Thruk::Utils::IO::json_lock_patch($report_file, { var => { send_mails_next_time => undef } }, 1);


    # update report runtime data
    Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 100, 'finished') if $ENV{'THRUK_JOB_DIR'};
    set_running($c, $nr, 0, undef, time());

    check_for_waiting_reports($c);
    return $attachment;
}

##########################################################

=head2 queue_report

  queue_report($c, $nr, [$mail])

queue a report for update.
returns true if report got queued.

=cut
sub queue_report {
    my($c, $nr, $with_mails) = @_;

    my $options = _read_report_file($c, $nr);
    if(!$c->stash->{'remote_user'}) {
        $c->stash->{'remote_user'} = $options->{'user'};
    }
    return if $options->{'var'}->{'is_running'};

    # don't queue report if it has been run this minute already
    if($ENV{'THRUK_CRON'}) {
        if($options->{'var'}->{'start_time'}) {
            if(POSIX::strftime("%Y-%m-%d %H:%M", localtime($options->{'var'}->{'start_time'})) eq POSIX::strftime("%Y-%m-%d %H:%M", localtime())) {
                return;
            }
        }
    }

    set_waiting($c, $nr, time(), $with_mails);
    return 1;
}

##########################################################

=head2 queue_report_if_busy

  queue_report_if_busy($c, $nr, [$mail])

Queue a report for update. Queue will only be used if all slots are busy.
Returns 1 if queue is used or undef if there are free slots.

=cut
sub queue_report_if_busy {
    my($c, $nr, $with_mails) = @_;

    my $options = _read_report_file($c, $nr);
    return   if $options->{'var'}->{'is_running'} == $$;
    return 1 if $options->{'var'}->{'is_running'};

    my $max_concurrent_reports = $c->config->{'Thruk::Plugin::Reports2'}->{'max_concurrent_reports'} || 2;
    my($running, $waiting) = get_running_reports_number($c);

    # free slots on current host?
    if($running >= $max_concurrent_reports) {
        if(queue_report($c, $nr,$with_mails)) {
            return(1);
        }
    }

    return;
}

##########################################################

=head2 generate_report_background

  generate_report_background($c, $report_nr, $with_mails, $report, $force, $debug)

start a report in the background and queue it if all slots are busy

=cut
sub generate_report_background {
    my($c, $report_nr, $with_mails, $report, $force, $debug) = @_;

    # using queue
    if(!$force && queue_report_if_busy($c, $report_nr)) {
        return;
    }

    $report = _read_report_file($c, $report_nr) unless $report;

    if(!defined $c->stash->{'remote_user'}) {
        Thruk::Utils::set_user($c, $report->{'user'});
    }

    set_running($c, $report_nr, $$, time());
    my $cmd = _get_report_cmd($c, $report->{'nr'}, 0);
    clean_report_tmp_files($c, $report_nr);
    delete $c->config->{'no_external_job_forks'}; # always start in background
    my $job = Thruk::Utils::External::cmd($c, {
                                               'cmd'        => $cmd,
                                               'background' => 1,
                                               'no_shell'   => 1,
                                               'env'        => {
                                                                THRUK_REPORT_DEBUG => $debug,
                                                                THRUK_REPORT_PARENT => $$,
                                                            },
                                            });

    set_running($c, $report_nr, undef, undef, undef, $job);

    return $job;
}

##########################################################

=head2 get_report_data_from_param

  get_report_data_from_param($params)

return report data for given params

=cut
sub get_report_data_from_param {
    my($params) = @_;
    my $p = {};
    for my $key (keys %{$params}) {
        next unless $key =~ m/^params\.([\w\.]+)$/mx;
        if(ref $params->{$key} eq 'ARRAY') {
            # remove empty elements
            @{$params->{$key}} = grep(!/^$/mx, @{$params->{$key}});
        }
        if($1 eq 'sla') { $params->{$key} =~ s/,/./gmx }
        $p->{$1} = $params->{$key};
    }

    for my $key (keys %{$params}) {
        next unless $key =~ m/^optional\.([\w\.]+)$/mx;
        if(!$params->{'enabled.'.$1}) {
            $p->{$1} = -1;
        }
    }

    # only save backends if checkbox checked
    if(!$params->{'backends_toggle'} && !$params->{'report_backends_toggle'}) {
        $params->{'report_backends'} = [];
    }

    my $send_types = Thruk::Utils::get_cron_entries_from_param($params);
    my $data = {
        'name'            => $params->{'name'}            || 'New Report',
        'desc'            => $params->{'desc'}            || '',
        'template'        => $params->{'template'}        || 'sla.tt',
        'is_public'       => $params->{'is_public'}       || 0,
        'to'              => $params->{'to'}              || '',
        'cc'              => $params->{'cc'}              || '',
        'backends'        => $params->{'report_backends'} || [],
        'failed_backends' => $params->{'failed_backends'} || 'cancel',
        'params'          => $p,
        'send_types'      => $send_types,
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
    my $combined_entries = {};
    my $reports = get_report_list($c, 1);
    @{$reports} = sort { $a->{'nr'} <=> $b->{'nr'} } @{$reports};

    for my $r (@{$reports}) {
        next unless defined $r->{'send_types'};
        next unless scalar @{$r->{'send_types'}} > 0;
        for my $st (@{$r->{'send_types'}}) {
            my $time = Thruk::Utils::get_cron_time_entry($st);
            $combined_entries->{$time} = [] unless $combined_entries->{$time};
            push @{$combined_entries->{$time}}, $r->{'nr'};
        }
    }
    my $cron_entries = [];
    for my $time (sort keys %{$combined_entries}) {
        my $cmd = _get_report_cmd($c, $combined_entries->{$time});
        push @{$cron_entries}, [$time, $cmd];
    }

    # REMOVE AFTER: 01.01.2020
    unlink(glob($c->config->{'var_path'}.'/reports/report*.sh'));
    # </REMOVE AFTER>

    Thruk::Utils::update_cron_file($c, 'reports', $cron_entries);
    return 1;
}

##########################################################

=head2 set_running

  set_running($c, $nr, [$val])

    $val can be
        * 0 to indicate the report is finished
        * pid of the report generating process

update running state of report

=cut
sub set_running {
    my($c, $nr, $val, $start, $end, $job) = @_;

    my $update = {};
    if(defined $val) {
        my $index_file = $c->config->{'var_path'}.'/reports/.index';
        $update->{'var'}->{'is_running'} = $val;
        if($val == 0) {
            $update->{'var'}->{'running_node'} = undef;
            Thruk::Utils::IO::json_lock_patch($index_file, { $nr => undef }, 1, 1);
        } else {
            $update->{'var'}->{'running_node'} = $Thruk::NODE_ID;
            Thruk::Utils::IO::json_lock_patch($index_file, { $nr => {
                                        is_running   => $val,
                                        running_node => $Thruk::NODE_ID,
                                        is_waiting   => undef,
                                    }}, 1, 1);
        }
    }
    $update->{'var'}->{'start_time'} = $start if defined $start;
    $update->{'var'}->{'end_time'}   = $end   if defined $end;
    $update->{'var'}->{'is_waiting'} = undef  if defined $val;
    $update->{'var'}->{'job'}        = $ENV{'THRUK_JOB_ID'} if defined $ENV{'THRUK_JOB_ID'};
    $update->{'var'}->{'job'}        = $job   if defined $job;
    $update->{'var'}->{'attachment'} = $Thruk::Utils::PDF::attachment if $Thruk::Utils::PDF::attachment;
    $update->{'var'}->{'ctype'}      = $Thruk::Utils::PDF::ctype      if $Thruk::Utils::PDF::ctype;

    my $report_file = $c->config->{'var_path'}.'/reports/'.$nr.'.rpt';
    Thruk::Utils::IO::json_lock_patch($report_file, $update, 1);
    return;
}

##########################################################

=head2 set_waiting

  set_waiting($c, $nr, $with_mails)

set waiting status of job

=cut
sub set_waiting {
    my($c, $nr, $waiting, $with_mails) = @_;
    my $index_file = $c->config->{'var_path'}.'/reports/.index';

    my $update = {};
    $update->{'var'}->{'is_waiting'} = ($waiting || undef);
    Thruk::Utils::IO::json_lock_patch($index_file, { $nr => { is_waiting => ($waiting||undef) }}, 1, 1) if defined $waiting;
    if(defined $with_mails) {
        $update->{'var'}->{'send_mails_next_time'} = $with_mails ? 1 : undef;
    }
    my $report_file = $c->config->{'var_path'}.'/reports/'.$nr.'.rpt';
    Thruk::Utils::IO::json_lock_patch($report_file, $update, 1);
    return;
}

##########################################################

=head2 clean_report_tmp_files

  clean_report_tmp_files($c, $nr)

remove any tmp files from this report

=cut
sub clean_report_tmp_files {
    my($c, $nr) = @_;
    unlink $c->config->{'var_path'}.'/reports/'.$nr.'.dat'  if -e $c->config->{'var_path'}.'/reports/'.$nr.'.dat';
    unlink $c->config->{'var_path'}.'/reports/'.$nr.'.log'  if -e $c->config->{'var_path'}.'/reports/'.$nr.'.log';
    unlink $c->config->{'var_path'}.'/reports/'.$nr.'.html' if -e $c->config->{'var_path'}.'/reports/'.$nr.'.html';
    unlink $c->config->{'var_path'}.'/reports/'.$nr.'.dbg'  if -e $c->config->{'var_path'}.'/reports/'.$nr.'.dbg';
    return;
}

##########################################################

=head2 get_report_templates

  get_report_templates($c)

return available report templates

=cut
sub get_report_templates {
    my($c) = @_;
    my $templates = {};
    for my $path (@{$c->config->{templates_paths}}, $c->config->{'View::TT'}->{'INCLUDE_PATH'}) {
        for my $file (glob($path.'/reports/*.tt')) {
            my $name;
            ($file, $name) = _get_report_tt_name($file);
            $templates->{$file} = {
                file => $file,
                name => $name,
            };
        }
    }
    return($templates);
}

##########################################################
sub _get_report_tt_name {
    my($file) = @_;
    $file =~ s/^.*\/(.*)$/$1/mx;
    my $name = $file;
    $name    =~ s/\.tt$//gmx;
    $name    = join(' ', map(ucfirst, split(/_/mx, $name)));
    $name    =~ s/Sla/SLA/gmx;
    return($file, $name);
}

##########################################################

=head2 get_report_languages

  get_report_languages($c)

return available report languages

=cut
sub get_report_languages {
    my($c) = @_;
    my $languages = {};
    for my $path (@{$c->config->{templates_paths}}, $c->config->{'View::TT'}->{'INCLUDE_PATH'}) {
        for my $file (glob($path.'/reports/locale/*.tt')) {
            $file    =~ s/^.*\/(.*)$/$1/mx;
            next if $file =~ m/_custom\.tt/mx;
            my $name = _get_locale_name($c, $file) || 'unknown';
            my $abrv = $file;
            $abrv    =~ s/\.tt$//gmx;
            $languages->{$name} = {
                file => $file,
                name => $name,
                abrv => $abrv,
            };
        }
    }
    return($languages);
}

##########################################################

=head2 add_report_defaults

  add_report_defaults($c, [$fields], $report)

add report defaults

=cut
sub add_report_defaults {
    my($c, $fields, $report) = @_;
    $fields = _get_required_fields($c, $report) unless defined $fields;
    for my $d (@{$fields}) {
        my $key = (keys %{$d})[0];
        my $f   = $d->{$key};

        # fill in default
        if(defined $f->[4] && $f->[2] ne '' && (!defined $report->{'params'}->{$key} || $report->{'params'}->{$key} =~ /^\s*$/mx)) {
            $report->{'params'}->{$key} = $f->[2];
        }

        # unavailable states may be empty when switching from hosts to services templates
        if($f->[1] eq 'hst_unavailable' or $f->[1] eq 'svc_unavailable') {
            my %default = map {$_ => 1} @{$f->[2]};
            $report->{'params'}->{$key} = [$report->{'params'}->{$key}] unless ref $report->{'params'}->{$key} eq 'ARRAY';
            my @used    = grep {$default{$_}} @{$report->{'params'}->{$key}};
            if(scalar @used == 0) {
                push @{$report->{'params'}->{$key}}, @{$f->[2]};
            }
        }
    }
    return;
}

##########################################################

=head2 get_running_reports_number

  get_running_reports_number($c)

returns list ($running, $waiting)

=cut
sub get_running_reports_number {
    my($c) = @_;
    my $index_file = $c->config->{'var_path'}.'/reports/.index';
    return(0,0) unless -s $index_file;
    my $index   = Thruk::Utils::IO::json_lock_retrieve($index_file);
    my $running = 0;
    my $waiting = 0;
    for my $nr (keys %{$index}) {
        if($index->{$nr}->{'is_waiting'}) {
            $waiting++;
        } elsif($index->{$nr}->{'is_running'} != 0 && $index->{$nr}->{'running_node'} eq $Thruk::NODE_ID) {
            $running++;
        }
    }
    return($running, $waiting);
}

##########################################################
sub _get_locale_name {
    my($c, $template) = @_;
    return Thruk::Utils::get_template_variable($c, 'reports/locale/'.$template, 'locale_name');
}

##########################################################
sub _get_new_report {
    my($c, $data) = @_;
    $data = {} unless defined $data;
    my $r = {
        'name'            => 'New Report',
        'desc'            => 'Description',
        'nr'              => 'new',
        'template'        => '',
        'params'          => {},
        'var'             => {},
        'to'              => '',
        'cc'              => '',
        'is_public'       => 0,
        'user'            => $c->stash->{'remote_user'},
        'backends'        => [],
        'send_types'      => [],
        'failed_backends' => 'cancel',
    };
    for my $key (keys %{$data}) {
        $r->{$key} = $data->{$key};
    }
    return $r;
}

##########################################################
sub _report_save {
    my($c, $nr, $r) = @_;
    my $report = dclone($r);
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
    delete $report->{'long_error'};
    delete $report->{'failed'};

    # save backends as hash with name
    $report->{'backends'} = Thruk::Utils::backends_list_to_hash($c, ($report->{'backends_hash'} || $report->{'backends'}));
    delete $report->{'backends_hash'};

    # sanity checks
    if(!$report->{'user'}) {
        confess("tried to save report without user");
    }
    if($report->{'desc'} eq 'Description' && $report->{'name'} eq 'New Report' && !$report->{'params'}->{'timeperiod'} && $report->{'template'} eq 'sla_host.tt') {
        confess("tried to save empty report");
    }

    Thruk::Utils::IO::json_store($file, $report, 1);

    $report->{'backends_hash'} = $report->{'backends'};

    return $report;
}

##########################################################
sub _read_report_file {
    my($c, $nr, $rdata, $noauth, $simple) = @_;

    my $index_file = $c->config->{'var_path'}.'/reports/.index';
    if(!defined $nr || $nr !~ m/^\d+$/mx) {
        Thruk::Utils::CLI::_error("not a valid report number");
        $c->stash->{errorMessage}       = "report does not exist";
        $c->stash->{errorDescription}   = "not a valid report number.";
        return $c->detach('/error/index/99');
    }
    my $file = $c->config->{'var_path'}.'/reports/'.$nr.'.rpt';
    unless(-f $file) {
        Thruk::Utils::CLI::_error("report does not exist: $!\n");
        $c->stash->{errorMessage}       = "report does not exist";
        $c->stash->{errorDescription}   = "please make sure this report exists.";
        return $c->detach('/error/index/99');
    }

    my($report_fh, $lock_fh) = Thruk::Utils::IO::file_lock($file, 'ex');
    my $report = Thruk::Utils::IO::json_retrieve($file, $report_fh);
    $report->{'nr'} = $nr;
    $report = _get_new_report($c, $report);

    my $needs_save = 0;
    my $available_templates = $c->stash->{'available_templates'} || get_report_templates($c);
    if($report->{'template'} && !defined $available_templates->{$report->{'template'}}) {
        my($oldfile, $oldname) = _get_report_tt_name($report->{'template'});
        $report->{'template'} = $c->req->parameters->{'template'} || $c->config->{'Thruk::Plugin::Reports2'}->{'default_template'} || 'sla_host.tt';
        $needs_save = 1;
        Thruk::Utils::set_message( $c, 'fail_message', 'Report Template \''.$oldname.'\' not available in \''.$report->{'name'}.'\', using default: \''.$available_templates->{$report->{'template'}}->{'name'}.'\'' );
    }
    if(!$report->{'template'}) {
        $report->{'template'} = $c->req->parameters->{'template'} || $c->config->{'Thruk::Plugin::Reports2'}->{'default_template'} || 'sla_host.tt';
        $needs_save = 1;
        Thruk::Utils::set_message( $c, 'fail_message', 'No Report Template set in \''.$report->{'name'}.'\', using default: \''.$available_templates->{$report->{'template'}}->{'name'}.'\'' );
    }
    $c->stash->{'available_templates'} = $available_templates;

    # add defaults
    add_report_defaults($c, undef, $report) unless $simple;
    $report->{'failed_backends'} = 'cancel' unless $report->{'failed_backends'};

    unless($noauth) {
        $report->{'readonly'}   = 1;
        my $authorized = _is_authorized_for_report($c, $report);
        Thruk::Utils::IO::file_unlock($file, $report_fh, $lock_fh);
        return unless $authorized;
        $report->{'readonly'}   = 0 if $authorized == 1;
    }

    # migrate some options
    if($report->{'params'}) {
        if(defined $report->{'params'}->{'max_outages_pages'} && $report->{'params'}->{'max_outages_pages'} eq "0") { $report->{'params'}->{'max_outages_pages'} = "-1"; }
        if(defined $report->{'params'}->{'max_worst_pages'}   && $report->{'params'}->{'max_worst_pages'}   eq "0") { $report->{'params'}->{'max_worst_pages'}   = "-1"; }
        if(defined $report->{'params'}->{'max_outages_pages'} && $report->{'params'}->{'max_outages_pages'} eq "0") { $report->{'params'}->{'max_outages_pages'} = "-1"; }
    }

    # add some runtime information
    my $rfile = $c->config->{'var_path'}.'/reports/'.$nr.'.dat';
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
    if($report->{'var'}->{'is_running'} == -1 && $report->{'var'}->{'start_time'} < time() - 10) {
        $report->{'var'}->{'is_running'} = 0;
        Thruk::Utils::IO::json_lock_patch($index_file, { $nr => undef }, 1, 1);
        $needs_save = 1;
    }
    if($report->{'var'}->{'is_running'} > 0 && $c->cluster->kill($c, $report->{'var'}->{'running_node'}, 0, $report->{'var'}->{'is_running'}) != 1) {
        $report->{'var'}->{'is_running'} = 0;
        Thruk::Utils::IO::json_lock_patch($index_file, { $nr => undef }, 1, 1);
        $needs_save = 1;
    }
    if($ENV{'THRUK_REPORT_PARENT'} && $report->{'var'}->{'is_running'} == $ENV{'THRUK_REPORT_PARENT'}) {
        $report->{'var'}->{'is_running'} = $$;
        $report->{'var'}->{'running_node'} = $Thruk::NODE_ID;
        Thruk::Utils::IO::json_lock_patch($index_file, { $nr => { is_running => $$, running_node => $Thruk::NODE_ID, is_waiting => undef }}, 1, 1);
        $needs_save = 1;
    }
    if($report->{'var'}->{'end_time'} < $report->{'var'}->{'start_time'}) {
        $report->{'var'}->{'end_time'} = $report->{'var'}->{'start_time'};
        $needs_save = 1;
    }

    my $log = $c->config->{'var_path'}.'/reports/'.$nr.'.log';
    if(!$report->{'var'}->{'is_running'} && $report->{'var'}->{'job'} && !Thruk::Utils::External::is_running($c, $report->{'var'}->{'job'}, 1)) {
        my $jobid = delete $report->{'var'}->{'job'};
        my($out,$err,$time, $dir,$stash,$rc,$profile) = Thruk::Utils::External::get_result($c, $jobid, 1);
        if($err && $err !~ m/\Qno such job:\E/mx) {
            # append job error to report logfile
            open(my $fh, '>>', $log);
            print $fh $err;
            Thruk::Utils::IO::close($fh, $log);
        }
        $report->{'var'}->{'profile'} = $profile;
        $needs_save = 1;
    }
    if($report->{'var'}->{'debug_file'} && !-e $report->{'var'}->{'debug_file'}) {
        delete $report->{'var'}->{'debug_file'};
        $needs_save = 1;
    }

    # failed?
    $report->{'failed'} = 0;
    if(-s $log) {
        $report->{'error'} = read_file($log);

        # strip performance debug output
        $report->{'error'}  =~ s%^\[.*INFO.*Req:.*$%%gmx;
        if($report->{'error'} =~ m%\S+%mx) {
            $report->{'failed'} = 1;
            $report->{'var'}->{'is_running'} = 0;
            Thruk::Utils::IO::json_lock_patch($index_file, { $nr => undef }, 1, 1);
        }

        # nice error message
        if($report->{'error'} =~ m/\[ERROR\]\s+(.*?)\s+at\s+[\w\/\.\-]+\.pm\s+line\s+\d+\./gmx) {
            $report->{'long_error'} = $report->{'error'};
            $report->{'error'} = $1;
            $report->{'error'} =~ s/^'//mx;
            $report->{'error'} =~ s/\\'/'/gmx;
        }
        elsif($report->{'error'} =~ m/\[ERROR\]\s+(internal\s+server\s+error)/gmx) {
            $report->{'long_error'} = $report->{'error'};
            $report->{'error'} = $1;
        }
        $report->{'error'} =~ s/^\Qundef error - \E//mx;
        if(!$report->{'long_error'} && $report->{'error'} =~ m/\n/mx) {
            ($report->{'error'}, $report->{'long_error'}) = split(/\n/mx, $report->{'error'}, 2);
        }
        $needs_save = 1;
    }

    # preset values from data
    if(defined $rdata) {
        for my $key (keys %{$rdata}) {
            $report->{$key} = $rdata->{$key};
        }
    }

    _report_save($c, $nr, $report) if $needs_save;

    $report->{'backends_hash'} = $report->{'backends'};
    $report->{'backends'}      = Thruk::Utils::backends_hash_to_list($c, $report->{'backends'});

    Thruk::Utils::IO::file_unlock($file, $report_fh, $lock_fh);
    return $report;
}

##########################################################
# returns:
#     undef    no access
#     1        private report, readwrite access
#     2        public report, readonly access
sub _is_authorized_for_report {
    my($c, $report) = @_;

    # super user have permission for all reports
    if($c->check_user_roles('authorized_for_system_commands') && $c->check_user_roles('authorized_for_configuration_information')) {
        return 1;
    }

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
    my($c, $numbers) = @_;
    Thruk::Utils::IO::mkdir($c->config->{'var_path'}.'/reports/');
    my $thruk_bin = $c->config->{'thruk_bin'};
    my $nice      = '/usr/bin/nice';
    my $niceval   = $c->config->{'Thruk::Plugin::Reports2'}->{'report_nice_level'} || $c->config->{'report_nice_level'} || 5;
    if(-e '/bin/nice') { $nice = '/bin/nice'; }
    if($niceval > 0) {
        $thruk_bin = $nice.' -n '.$niceval.' '.$thruk_bin;
    }
    $numbers = Thruk::Utils::list($numbers);
    my $cmd = sprintf("cd %s && %s '%s report \"%s\"' >/dev/null 2>%s/reports/%d.log",
                            $c->config->{'project_root'},
                            $c->config->{'thruk_shell'},
                            $thruk_bin,
                            join('|', @{$numbers}),
                            $c->config->{'var_path'},
                            $numbers->[0],
                    );
    return $cmd;
}

##########################################################
sub _get_required_fields {
    my($c, $report) = @_;
    confess("no template in ".Dumper($report)) unless $report->{'template'};
    my $fields = Thruk::Utils::get_template_variable($c, 'reports/'.$report->{'template'}, 'required_fields', { block => 'edit' });
    confess("no fields? -> ".Dumper($report)) unless(defined $fields and ref $fields eq 'ARRAY');
    return $fields;
}

##########################################################
sub _verify_fields {
    my($c, $fields, $report) = @_;
    return unless defined $fields;
    return unless ref $fields eq 'ARRAY';
    delete $report->{'var'}->{'opt_errors'};
    my @errors;

    # add defaults first
    add_report_defaults($c, $fields, $report);

    for my $d (@{$fields}) {
        my $key = (keys %{$d})[0];
        my $f   = $d->{$key};

        # required fields
        if(defined $f->[4] && $f->[2] eq '' && (!defined $report->{'params'}->{$key} || $report->{'params'}->{$key} =~ m/^\s*$/mx)) {
            push @errors, $f->[0].': required field';
        }

        # regular expressions
        if($f->[1] eq 'pattern' && !Thruk::Utils::is_valid_regular_expression($c, $report->{'params'}->{$key})) {
            push @errors, $f->[0].': invalid regular expression';
        }
    }
    if(scalar @errors > 0) {
        Thruk::Utils::set_message( $c, 'fail_message', 'Found errors in report options:', \@errors );
        $report->{'var'}->{'opt_errors'} = \@errors;
    }
    return;
}

##########################################################
sub _convert_to_pdf {
    my($c, $reportdata, $attachment, $nr, $logfile) = @_;
    my $htmlfile = $c->config->{'var_path'}.'/reports/'.$nr.'.html';

    my $htmlonly = 0;

    # skip pdf creator for ondemand html preview
    if($c->req->parameters->{'html'} and $c->req->parameters->{'refresh'}) {
        $htmlonly = 1;
    }

    unless($htmlonly) {
        $c->stash->{'param'}->{'js'} = 1;
        $reportdata = Thruk::Utils::Reports::Render::_replace_css_and_images($reportdata);
    }

    # write out result
    open(my $fh, '>', $htmlfile);
    binmode $fh;
    print $fh $reportdata;
    Thruk::Utils::IO::close($fh, $htmlfile);

    if($htmlonly) {
        `touch $attachment`;
        return;
    }

    my $phantomjs = $c->config->{'Thruk::Plugin::Reports2'}->{'phantomjs'} || 'phantomjs';
    my $autoscale = 0;
    if($c->stash->{'param'}->{'pdf'}) {
        $autoscale = 1;
    }

    local $ENV{PHANTOMJSSCRIPTOPTIONS} = '--autoscale=1' if $autoscale;
    my $cmd = $c->config->{home}.'/script/html2pdf.sh "'.$htmlfile.'" "'.$attachment.'.pdf" "'.$logfile.'" "'.$phantomjs.'"';
    my $out = `$cmd 2>&1`;

    # try again to avoid occasionally qt errors
    if(!-e $attachment.'.pdf') {
        my $error = read_file($logfile);
        if($error eq "") { $error = $out; }
        if($error =~ m/QPainter::begin/mx) {
            `$cmd`;
        }
        if($error eq "") {
            $error = "failed to produce a pdf file without any error message.\npwd: ".Cwd::getcwd()."\ncmdline:\n$cmd";
        }
        if(!-e $attachment.'.pdf') {
            Thruk::Utils::IO::write($logfile, $error, undef, 1) unless -s $logfile;
            die('report failed: '.$error);
        }
    }

    move($attachment.'.pdf', $attachment) or die('move '.$attachment.'.pdf to '.$attachment.' failed: '.$!);
    Thruk::Utils::IO::ensure_permissions('file', $attachment);
    return;
}

##########################################################
sub _initialize_report_templates {
    my($c, $options) = @_;

    # add default params
    add_report_defaults($c, undef, $options);

    $c->stash->{'param'}              = $options->{'params'};
    $c->stash->{'r'}                  = $options;
    $c->stash->{'show_empty_outages'} = 1;
    for my $p (keys %{$options->{'params'}}) {
        $c->req->parameters->{$p} = $options->{'params'}->{$p};
    }

    # set some render helper
    for my $s (@{Class::Inspector->functions('Thruk::Utils::Reports::Render')}) {
        $c->stash->{$s} = \&{'Thruk::Utils::Reports::Render::'.$s};
    }
    # set custom render helper
    my $custom = [];
    eval {
        require Thruk::Utils::Reports::CustomRender;
        Thruk::Utils::Reports::CustomRender->import;
        $custom = Class::Inspector->functions('Thruk::Utils::Reports::CustomRender');
    };
    # show errors if module was found
    if($@ and $@ !~ m|Can\'t\ locate\ Thruk/Utils/Reports/CustomRender\.pm\ in|mx) {
        $Thruk::Utils::Reports::error = $@;
        $c->log->error($@);
    }
    for my $s (@{$custom}) {
        $c->stash->{$s} = \&{'Thruk::Utils::Reports::CustomRender::'.$s};
    }

    # initialize localization
    if($options->{'params'}->{'language'}) {
        $c->stash->{'loc'} = $c->stash->{'_locale'};
        $Thruk::Utils::Reports::Render::locale = Thruk::Utils::get_template_variable($c, 'reports/locale/'.$options->{'params'}->{'language'}.'.tt', 'translations');
        my $overrides = {};
        for my $path (@{$c->config->{templates_paths}}, $c->config->{'View::TT'}->{'INCLUDE_PATH'}) {
            if(-e $path.'/reports/locale/'.$options->{'params'}->{'language'}.'_custom.tt') {
                $overrides = Thruk::Utils::get_template_variable($c, 'reports/locale/'.$options->{'params'}->{'language'}.'_custom.tt', 'translations_overrides');
                last;
            }
        }
        if($overrides) {
            for my $key (keys %{$overrides}) {
                $Thruk::Utils::Reports::Render::locale->{$key} = $overrides->{$key};
            }
        }
    }
    return;
}

##########################################################

=head2 check_for_waiting_reports

  check_for_waiting_reports($c)

works on next queued report

returns nothing

=cut
sub check_for_waiting_reports {
    my($c) = @_;
    my $index_file = $c->config->{'var_path'}.'/reports/.index';
    return unless -s $index_file;
    my $index   = Thruk::Utils::IO::json_lock_retrieve($index_file);
    for my $nr (keys %{$index}) {
        if($index->{$nr}->{'is_waiting'}) {
            generate_report_background($c, $nr, undef, undef, 1);
            return;
        }
    }
    return;
}

##########################################################
sub _report_die {
    my($c, $err, $logfile) = @_;
    Thruk::Utils::CLI::_error($err);
    Thruk::Utils::IO::write($logfile, $err, undef, 1);
    $Thruk::Utils::Reports::error = $err;
    check_for_waiting_reports($c);
    return $c->detach('/error/index/13');
}

##########################################################

1;
