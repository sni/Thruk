package Thruk::Utils::CLI::Url;

=head1 NAME

Thruk::Utils::CLI::Url - Url CLI module

=head1 DESCRIPTION

The url command displays any thruk url on stdout and can be used to create
command line reports.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] url <url> [options]

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<-i / --all-inclusive>

    includes all css, javascript and images in the resulting html page

=back

=cut

use warnings;
use strict;
use Thruk::Utils::Log qw/:all/;
use Getopt::Long ();

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions) = @_;
    $c->stats->profile(begin => "_cmd_url($action)");

    # parse options
    my $opt = {};
    Getopt::Long::Configure('no_ignore_case');
    Getopt::Long::Configure('bundling');
    Getopt::Long::Configure('pass_through');
    Getopt::Long::GetOptionsFromArray($commandoptions,
       "i|all-inclusive"    => \$opt->{'all_inclusive'},
    ) or do {
        $c->stats->profile(end => "_cmd_url($action)");
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    };

    if($opt->{'all_inclusive'} && !$c->config->{'use_feature_reports'}) {
        return({output => "all-inclusive options requires the reports plugin to be enabled", rc => 1});
    }

    my $url = shift @{$commandoptions};
    if(!$url) {
        $c->stats->profile(end => "_cmd_url($action)");
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    if($url =~ m|^\w+\.cgi|gmx) {
        my $product = $c->config->{'product_prefix'} || 'thruk';
        $url = '/'.$product.'/cgi-bin/'.$url;
    }
    my @res = Thruk::Utils::CLI::request_url($c, $url);

    # All Inclusive?
    if($res[0] == 200 && $res[1]->{'result'} && $opt->{'all_inclusive'}) {
        require Thruk::Utils::Reports::Render;
        $res[1]->{'result'} = Thruk::Utils::Reports::Render::html_all_inclusive($c, $url, $res[1]->{'result'}, 1);
    }

    my $content_type;
    if($res[1] && $res[1]->{'headers'}) {
        $content_type = $res[1]->{'headers'}->{'content-type'};
    }

    $c->stats->profile(end => "_cmd_url($action)");
    my $rc = $res[0] >= 400 ? 1 : 0;
    return({output => $res[2], rc => $rc, 'content_type' => $content_type}) if $res[2];
    if($res[1]->{'result'} =~ m/\Q<div class='infoMessage'>Your command request was successfully submitted to the Backend for processing.\E/gmx) {
        return({output => "Command request successfully submitted to the Backend for processing\n", rc => $rc});
    }
    return({output => $res[1]->{'result'}, rc => $rc, 'content_type' => $content_type});
}

##############################################

=head1 EXAMPLES

Export the event log as excel file:

  %> thruk -A thrukadmin -a 'url=/thruk/cgi-bin/showlog.cgi?view_mode=xls' > eventlog.xls

Urls can be shortened.
Export all services into an excel file:

  %> thruk 'status.cgi?view_mode=xls&host=all' > allservices.xls

Export service availability data into a csv file:

  %> thruk -A thrukadmin -a 'url=avail.cgi?host=all&timeperiod=last7days&csvoutput=1' > all_host_availability.csv

Reschedule next check for host localhost now:

  %> thruk 'cmd.cgi?cmd_mod=2&cmd_typ=96&host=localhost&start_time=now'

=cut

##############################################

1;
