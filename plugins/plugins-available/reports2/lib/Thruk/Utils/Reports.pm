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
            my $r = _read_report_file($c, $1, undef, $noauth, 1);
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
        return $c->response->redirect('reports2.cgi');
    }

    my $report_file = $c->config->{'tmp_path'}.'/reports/'.$nr.'.dat';
    if($refresh or ! -f $report_file) {
        generate_report($c, $nr, $report);
    }

    if(defined $report_file and -f $report_file) {
        $c->stash->{'template'} = 'passthrough.tt';
        if($c->{'request'}->{'parameters'}->{'html'}) {
            my $html_file   = $c->config->{'tmp_path'}.'/reports/'.$nr.'.html';
            my $report_text = decode_utf8(read_file($html_file));
            $report_text    =~ s/^<body>/<body class="preview">/mx;
            $c->stash->{'text'} = $report_text;
        }
        elsif($report->{'var'}->{'attachment'}) {
            my $name = $report->{'var'}->{'attachment'};
            $name    =~ s/\s+/_/gmx;
            $name    =~ s/[^a-zA-Z0-9-_\.]+//gmx;
            $c->res->header( 'Content-Disposition', 'attachment; filename="'.$name.'"' );
            $c->res->content_type($report->{'var'}->{'ctype'}) if $report->{'var'}->{'ctype'};
            open(my $fh, '<', $report_file);
            binmode $fh;
            $c->res->body($fh);
        } else {
            my $name = $report->{'name'};
            $name    =~ s/\s+/_/gmx;
            $name    =~ s/[^a-zA-Z0-9-_]+//gmx;
            $c->res->content_type('application/pdf');
            $c->res->header( 'Content-Disposition', 'filename='.$name.'.pdf' );
            open(my $fh, '<', $report_file);
            binmode $fh;
            $c->res->body($fh);
        }
    } else {
        if($Thruk::Utils::Reports::error) {
            Thruk::Utils::set_message( $c, 'fail_message', 'generating report failed: '.$Thruk::Utils::Reports::error );
        } else {
            Thruk::Utils::set_message( $c, 'fail_message', 'generating report failed' );
        }
        return $c->response->redirect('reports2.cgi');
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
        return $c->response->redirect('reports2.cgi');
    }
    # make report available in template
    $c->stash->{'r'} = $report;

    my $attachment = generate_report($c, $nr, $report);
    $report        = _read_report_file($c, $nr); # update report data, attachment would be wrong otherwise
    if(defined $attachment) {

        $c->stash->{'block'} = 'mail';
        my $mailtext;
        eval {
            $c->stash->{'start'} = '' unless defined $c->stash->{'start'};
            $mailtext = $c->view("TT")->render($c, 'reports/'.$report->{'template'});
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
                 From    => $report->{'from'}    || $mailheader->{'from'} || $c->config->{'Thruk::Plugin::Reports2'}->{'report_from_email'},
                 To      => $report->{'to'}      || $mailheader->{'to'},
                 Cc      => $report->{'cc'}      || $mailheader->{'cc'},
                 Bcc     => $report->{'bcc'}     || $mailheader->{'bcc'},
                 Subject => encode("MIME-B", ($report->{'subject'} || $mailheader->{'subject'} || 'Thruk Report')),
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
                     Data     => encode_utf8($mailbody),
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
    Thruk::Utils::Reports::update_cron_file($c);

    return 1;
}

##########################################################

=head2 generate_report

  generate_report($c, $nr, $options)

generate a new report

=cut
sub generate_report {
    my($c, $nr, $options) = @_;
    $Thruk::Utils::Reports::Render::c = $c;
    $Thruk::Utils::CLI::c             = $c;
    $Thruk::Utils::PDF::attachment    = '';
    $Thruk::Utils::PDF::ctype         = 'html2pdf';

    $c->stash->{'tmp_files_to_delete'} = [];

    $c->stats->profile(begin => "Utils::Reports::generate_report()");
    $options = _read_report_file($c, $nr) unless defined $options;
    unless(defined $options) {
        $Thruk::Utils::Reports::error = 'got no report options';
        return;
    }

    # do we have errors in our options, ex.: missing required fields?
    if(defined $options->{'var'}->{'opt_errors'}) {
        print STDERR join("\n", @{$options->{'var'}->{'opt_errors'}});
        exit 1;
    }

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

    # need to update defaults backends
    my($disabled_backends,$has_groups) = Thruk::Action::AddDefaults::_set_enabled_backends($c);
    Thruk::Action::AddDefaults::_set_possible_backends($c, $disabled_backends);

    # check backend connections
    my $processinfo = $c->{'db'}->get_processinfo();
    if($options->{'backends'}) {
        my @failed;
        for my $b (@{$options->{'backends'}}) {
            if($c->stash->{'failed_backends'}->{$b}) {
                push @failed, $c->{'db'}->get_peer_by_key($b)->peer_name().': '.$c->stash->{'failed_backends'}->{$b};
            }
        }
        die("Some backends are not connected, cannot create report!\n".join("\n", @failed)."\n") if scalar @failed > 0;
    }

    # set some defaults
    Thruk::Utils::Reports::Render::set_unavailable_states([qw/DOWN UNREACHABLE CRITICAL UNKNOWN/]);
    $c->{'request'}->{'parameters'}->{'show_log_entries'}           = 1;
    $c->{'request'}->{'parameters'}->{'assumeinitialstates'}        = 'yes';
    #$c->{'request'}->{'parameters'}->{'initialassumedhoststate'}    = 3; # UP
    #$c->{'request'}->{'parameters'}->{'initialassumedservicestate'} = 6; # OK
    $c->{'request'}->{'parameters'}->{'initialassumedhoststate'}    = 0; # Unspecified
    $c->{'request'}->{'parameters'}->{'initialassumedservicestate'} = 0; # Unspecified

    # add default params
    add_report_defaults($c, undef, $options);

    $c->stash->{'param'}              = $options->{'params'};
    $c->stash->{'r'}                  = $options;
    $c->stash->{'show_empty_outages'} = 1;
    for my $p (keys %{$options->{'params'}}) {
        $c->{'request'}->{'parameters'}->{$p} = $options->{'params'}->{$p};
    }

    if(!defined $options->{'template'}) {
        confess('template reports/'.$options->{'template'}.' does not exist');
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
    }

    # prepage stage, functions here could still change stash
    eval {
        $c->stash->{'block'} = 'prepare';
        $c->view("TT")->render($c, 'reports/'.$options->{'template'});
    };
    if($@) {
        Thruk::Utils::CLI::_error($@);
        $Thruk::Utils::Reports::error = $@;
        return $c->detach('/error/index/13');
    }

    # render report
    my $reportdata;
    eval {
        $c->stash->{'block'} = 'render';
        $reportdata = $c->view("TT")->render($c, 'reports/'.$options->{'template'});
    };
    if($@) {
        Thruk::Utils::CLI::_error($@);
        $Thruk::Utils::Reports::error = $@;
        return $c->detach('/error/index/13');
    }

    # convert to pdf
    if($Thruk::Utils::PDF::ctype eq 'html2pdf') {
        _convert_to_pdf($c, $reportdata, $attachment, $nr, $logfile);
    }

    # clean up tmp files
    for my $file (@{$c->stash->{'tmp_files_to_delete'}}) {
        unlink($file);
    }

    # update report runtime data
    set_running($c, $nr, 0, undef, time());

    # set error if not already set
    if(!-f $attachment and !$Thruk::Utils::Reports::error) {
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
        if(scalar @failed > 0) {
            unlink($attachment);
            die("Some backends threw errors, cannot create report!\n".join("\n", @failed)."\n")
        }
    }

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
        if($1 eq 'sla') { $params->{$key} =~ s/,/./gmx }
        $p->{$1} = $params->{$key};
    }

    # only save backends if checkbox checked
    if(!$params->{'report_backends_toggle'}) {
        $params->{'report_backends'} = [];
    }

    my $send_types = Thruk::Utils::get_cron_entries_from_param($params);
    my $data = {
        'name'       => $params->{'name'}            || 'New Report',
        'desc'       => $params->{'desc'}            || '',
        'template'   => $params->{'template'}        || 'sla.tt',
        'is_public'  => $params->{'is_public'}       || 0,
        'to'         => $params->{'to'}              || '',
        'cc'         => $params->{'cc'}              || '',
        'backends'   => $params->{'report_backends'} || [],
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
    my($c, $nr, $val, $start, $end, $job) = @_;
    my $options = _read_report_file($c, $nr);
    $options->{'var'}->{'is_running'} = $val   if defined $val;
    $options->{'var'}->{'start_time'} = $start if defined $start;
    $options->{'var'}->{'end_time'}   = $end   if defined $end;
    $options->{'var'}->{'job'}        = $job   if defined $job;
    $options->{'var'}->{'attachment'} = $Thruk::Utils::PDF::attachment if $Thruk::Utils::PDF::attachment;
    $options->{'var'}->{'ctype'}      = $Thruk::Utils::PDF::ctype      if $Thruk::Utils::PDF::ctype;
    _report_save($c, $nr, $options);
    return;
}

##########################################################

=head2 clean_report_tmp_files

  clean_report_tmp_files($c, $nr)

remove any tmp files from this report

=cut
sub clean_report_tmp_files {
    my($c, $nr) = @_;
    unlink $c->config->{'tmp_path'}.'/reports/'.$nr.'.dat'  if -e $c->config->{'tmp_path'}.'/reports/'.$nr.'.dat';
    unlink $c->config->{'tmp_path'}.'/reports/'.$nr.'.log'  if -e $c->config->{'tmp_path'}.'/reports/'.$nr.'.log';
    unlink $c->config->{'tmp_path'}.'/reports/'.$nr.'.html' if -e $c->config->{'tmp_path'}.'/reports/'.$nr.'.html';
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
        if(defined $f->[4] and $f->[2] ne '' and !$report->{'params'}->{$key}) {
            $report->{'params'}->{$key} = $f->[2];
        }

        # unavailable states may be empty when switching from hosts to services templates
        if($f->[1] eq 'hst_unavailable' or $f->[1] eq 'svc_unavailable') {
            my %default = map {$_ => 1} @{$f->[2]};
            my @used    = grep {$default{$_}} @{$report->{'params'}->{$key}};
            if(scalar @used == 0) {
                push @{$report->{'params'}->{$key}}, @{$f->[2]};
            }
        }
    }
    return;
}

##########################################################
sub _get_locale_name {
    my($c, $template) = @_;
    return Thruk::Utils::get_template_variable($c, 'reports/locale/'.$template, 'locale_name');
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
    delete $report->{'failed'};

    Thruk::Utils::write_data_file($file, $report);
    return $report;
}

##########################################################
sub _read_report_file {
    my($c, $nr, $rdata, $noauth, $simple) = @_;
    $Thruk::Utils::CLI::c = $c;

    unless($nr =~ m/^\d+$/mx) {
        Thruk::Utils::CLI::_error("not a valid report number");
        $c->stash->{errorMessage}       = "report does not exist";
        $c->stash->{errorDescription}   = "not a valid report number.";
        return $c->detach('/error/index/99');
    }
    my $file = $c->config->{'var_path'}.'/reports/'.$nr.'.rpt';
    unless(-f $file) {
        Thruk::Utils::CLI::_error("report does not exist: $!");
        $c->stash->{errorMessage}       = "report does not exist";
        $c->stash->{errorDescription}   = "please make sure this report exists.";
        return $c->detach('/error/index/99');
    }

    my $report = Thruk::Utils::read_data_file($file);
    $report->{'nr'} = $nr;
    $report = _get_new_report($c, $report);

    my $available_templates = $c->stash->{'available_templates'} || get_report_templates($c);
    if($report->{'template'} and !defined $available_templates->{$report->{'template'}}) {
        my($oldfile, $oldname) = _get_report_tt_name($report->{'template'});
        $report->{'template'} = $c->{'request'}->{'parameters'}->{'template'} || $c->config->{'Thruk::Plugin::Reports2'}->{'default_template'} || 'sla_host.tt';
        Thruk::Utils::set_message( $c, 'fail_message', 'Report Template \''.$oldname.'\' not available, using default: \''.$available_templates->{$report->{'template'}}->{'name'}.'\'' );
    }
    $c->stash->{'available_templates'} = $available_templates;

    # add defaults
    add_report_defaults($c, undef, $report) unless $simple;

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
    my $needs_save = 0;
    if($report->{'var'}->{'is_running'} and kill(0, $report->{'var'}->{'is_running'}) != 1) {
        $report->{'var'}->{'is_running'} = 0;
        $needs_save = 1;
    }
    if($report->{'var'}->{'is_running'} == -1 and $report->{'var'}->{'start_time'} < time() - 10) {
        $report->{'var'}->{'is_running'} = 0;
        $needs_save = 1;
    }
    if($report->{'var'}->{'end_time'} < $report->{'var'}->{'start_time'}) {
        $report->{'var'}->{'end_time'} = $report->{'var'}->{'start_time'};
        $needs_save = 1;
    }

    my $log = $c->config->{'tmp_path'}.'/reports/'.$nr.'.log';
    if(!$report->{'var'}->{'is_running'} and $report->{'var'}->{'job'}) {
        my $jobid = delete $report->{'var'}->{'job'};
        my($out,$err,$time, $dir,$stash,$rc) = Thruk::Utils::External::get_result($c, $jobid, 1);
        if($err) {
            # append job error to report logfile
            open(my $fh, '>>', $log);
            print $fh $err;
            Thruk::Utils::IO::close($fh, $log);
        }
        $needs_save = 1;
    }

    # failed?
    $report->{'failed'} = 0;
    if(-s $log) {
        $report->{'failed'} = 1;
        $report->{'error'}  = read_file($log);
        $report->{'var'}->{'is_running'} = 0;

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
        $needs_save = 1;
    }


    # preset values from data
    if(defined $rdata) {
        for my $key (keys %{$rdata}) {
            $report->{$key} = $rdata->{$key};
        }
    }

    _report_save($c, $nr, $report) if $needs_save;

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
    my($c, $report, $mail) = @_;
    Thruk::Utils::IO::mkdir($c->config->{'var_path'}.'/reports/',
                            $c->config->{'tmp_path'}.'/reports/');
    my $thruk_bin = $c->config->{'thruk_bin'};
    my $type      = 'report';
    if($mail) {
        $type = 'reportmail';
    }
    my $nice = '/usr/bin/nice';
    my $niceval = $c->config->{'Thruk::Plugin::Reports2'}->{'report_nice_level'} || $c->config->{'report_nice_level'} || 5;
    if(-e '/bin/nice') { $nice = '/bin/nice'; }
    if($niceval > 0) {
        $thruk_bin = $nice.' -n '.$niceval.' '.$thruk_bin;
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
sub _get_required_fields {
    my($c, $report) = @_;

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
        if(defined $f->[4] and $f->[2] eq '' and (!defined $report->{'params'}->{$key} or $report->{'params'}->{$key} =~ m/^\s*$/mx)) {
            push @errors, $f->[0].': required field';
        }

        # regular expressions
        if($f->[1] eq 'pattern' and !Thruk::Utils::is_valid_regular_expression($c, $report->{'params'}->{$key})) {
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
    my $htmlfile = $c->config->{'tmp_path'}.'/reports/'.$nr.'.html';

    my $htmlonly = 0;

    # skip pdf creator for ondemand html preview
    if($c->{'request'}->{'parameters'}->{'html'} and $c->{'request'}->{'parameters'}->{'refresh'}) {
        $htmlonly = 1;
    }

    unless($htmlonly) {
        $c->stash->{'param'}->{'js'} = 1;
        $reportdata = Thruk::Utils::Reports::Render::_replace_css_and_images($reportdata);
    }

    # write out result
    open(my $fh, '>', $htmlfile);
    binmode $fh;
    print $fh encode_utf8($reportdata);
    Thruk::Utils::IO::close($fh, $htmlfile);

    if($htmlonly) {
        `touch $attachment`;
        return;
    }

    my $wkhtmltopdf = $c->config->{'Thruk::Plugin::Reports2'}->{'wkhtmltopdf'} || 'wkhtmltopdf';
    my $cmd = $c->config->{plugin_path}.'/plugins-enabled/reports2/script/html2pdf.sh "'.$htmlfile.'" "'.$attachment.'.pdf" "'.$logfile.'" "'.$wkhtmltopdf.'"';
    `$cmd`;

    # try again to avoid occasionally qt errors
    if(!-e $attachment.'.pdf') {
        my $error = read_file($logfile);
        if($error =~ m/QPainter::begin/mx) {
            `$cmd`;
        }
        if(!-e $attachment.'.pdf') {
            die('report failed: '.$error);
        }
    }

    move($attachment.'.pdf', $attachment) or die('move '.$attachment.'.pdf to '.$attachment.' failed: '.$!);
    Thruk::Utils::IO::ensure_permissions('file', $attachment);
    return;
}

##########################################################

1;
