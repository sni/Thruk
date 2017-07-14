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
    my $nr = $commandoptions->[0];

    my $output;
    eval {
        require Thruk::Utils::Reports;
    };
    if($@) {
        return("reports plugin is not enabled.\n", 1);
    }
    my $logfile = $c->config->{'var_path'}.'/reports/'.$nr.'.log';
    # set waiting flag for queued reports, so the show up nicely in the gui
    Thruk::Utils::Reports::process_queue_file($c);
    if($mail) {
        if(Thruk::Utils::Reports::queue_report_if_busy($c, $nr, 1)) {
            $output = "report queued successfully\n";
        }
        elsif(Thruk::Utils::Reports::report_send($c, $nr)) {
            $output = "mail send successfully\n";
        } else {
            return("cannot send mail\n", 1)
        }
    } else {
        if(Thruk::Utils::Reports::queue_report_if_busy($c, $nr)) {
            $output = "report queued successfully\n";
        } else {
            my $report_file = Thruk::Utils::Reports::generate_report($c, $nr);
            if(defined $report_file and -f $report_file) {
                $output = read_file($report_file);
            } else {
                my $errors = read_file($logfile);
                return("generating report failed:\n".$errors, 1);
            }
        }
    }

    $c->stats->profile(end => "_cmd_report()");
    return($output, 0);
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
