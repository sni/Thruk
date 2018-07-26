package Thruk::Utils::CLI::Report;

=head1 NAME

Thruk::Utils::CLI::Report - Report CLI module

=head1 DESCRIPTION

The report command creates reports from the command line.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] report [mail] [nr]

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=back

=cut

use warnings;
use strict;
use File::Slurp qw/read_file/;
use Thruk::Utils::IO;
use Thruk::Utils::External;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions, $data, $src, $global_options) = @_;
    $c->stats->profile(begin => "_cmd_report()");

    my $mail = 0;
    if(scalar @{$commandoptions} >= 1 && $commandoptions->[0] eq 'mail') {
        $mail = 1;
        shift @{$commandoptions};
    }

    if(scalar @{$commandoptions} == 0) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    eval {
        require Thruk::Utils::Reports;
    };
    if($@) {
        return("reports plugin is not enabled.\n", 1);
    }

    # queue all supplied reports
    my @numbers = split(/\s*\|\s*/mx, $commandoptions->[0]);
    my $queued  = 0;
    for my $nr (@numbers) {
        my $mail_queue = 0;
        my $report = Thruk::Utils::Reports::get_report($c, $nr, 1);
        if(defined $report->{'is_running'} && $report->{'is_running'} > 0) {
            next;
        }
        if($ENV{'THRUK_CRON'}) {
            if($report->{'to'} || $report->{'cc'}) {
                $mail_queue = 1;
            }
            if(Thruk::Utils::Reports::queue_report($c, $nr, $mail_queue)) {
                $queued++;
            }
        }
    }

    my($output, $rc) = ("", 0);
    if($ENV{'THRUK_CRON'}) {
        # start with first report from list, others will be processed serially via check_for_waiting_reports()
        my $nr = shift @numbers;
        ($output, $rc) = _cmd_report($c, $nr, $mail);
    } else {
        # do all reports serially
        for my $nr (@numbers) {
            my($o, $r) = _cmd_report($c, $nr, $mail);
            $output .= $o;
            $rc     += $r;
        }
    }

    Thruk::Utils::Reports::check_for_waiting_reports($c);

    $c->stats->profile(end => "_cmd_report()");
    return($output, $rc);
}

##############################################
sub _cmd_report {
    my($c, $nr, $mail) = @_;

    my $report = Thruk::Utils::Reports::get_report($c, $nr, 1);
    if($ENV{'THRUK_CRON'}) {
        if(defined $report->{'is_running'} && $report->{'is_running'} > 0) {
            return("report is already running\n", 0);
        }
        if($report->{'to'} || $report->{'cc'}) {
            $mail = 1;
        }
    }

    # create fake job when run from cron to save profile
    if(!$ENV{'THRUK_JOB_ID'}) {
        my($id,$dir) = Thruk::Utils::External::_init_external($c);
        ## no critic
        $SIG{CHLD} = 'DEFAULT';
        Thruk::Utils::External::_do_parent_stuff($c, $dir, $$, $id, { allow => 'all', background => 1});
        $ENV{'THRUK_JOB_ID'}       = $id;
        $ENV{'THRUK_JOB_DIR'}      = $dir;
        ## use critic
        Thruk::Utils::IO::write($dir.'/stdout', "fake job create\n");
    }

    if(!$ENV{'THRUK_CRON'} && $mail) {
        my $sent = Thruk::Utils::Reports::report_send($c, $nr);
        if($sent && $sent eq "-2") {
            return("report is running on another node already\n", 0);
        } elsif($sent && $sent eq "2") {
            return("mail not sent, threshold not reached\n", 0);
        } elsif($sent) {
            return("mail sent successfully\n", 0);
        }
        return("cannot send mail\n", 1);
    }

    my $report_file = Thruk::Utils::Reports::generate_report($c, $nr);
    if(defined $report_file and $report_file eq '-2') {
        return("report is running on another node already\n", 0);
    } elsif(defined $report_file and -f $report_file) {
        return(scalar read_file($report_file), 0);
    }
    my $logfile = $c->config->{'var_path'}.'/reports/'.$nr.'.log';
    my $errors  = read_file($logfile);
    return("generating report failed:\n".$errors, 1);
}

##############################################

=head1 EXAMPLES

Generate report with number 1

  %> thruk report 1

Generate report with number 1 and send it by mail

  %> thruk report mail 1

Other reports are available via the url export of normal thruk pages

  %> thruk -A thrukadmin -a 'url=/thruk/cgi-bin/showlog.cgi?view_mode=xls' > eventlog.xls

  See 'thruk url help' for more examples.

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
