package Thruk::Utils::CLI::Graph;

=head1 NAME

Thruk::Utils::CLI::Graph - Graph CLI module

=head1 DESCRIPTION

The graph command exports pnp/grafana graphs

=head1 SYNOPSIS

  Usage: thruk [globaloptions] graph <options>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<format>

    Output format, can be either 'png' or 'base64'. Default is png.

=item B<width>

    Width of the exported image in px. Default to 800.

=item B<height>

    Height of the exported image in px. Default to 300.

=item B<host>

    Hostname to export graph for

=item B<service>

    Service description to export graph for. If empty host graph will be exported.

=item B<start>

    Start timestamp used when collecting performance data. Defaults to yesterday.

=item B<end>

    End timestamp used when collecting performance data. Defaults to now.

=item B<source>

    Grafana panelId. Defaults to 1.

=item B<output>

    Write output to file, default is printing to stdout.

=back

=cut

use warnings;
use strict;
use Thruk::Utils::Log qw/:all/;
use Getopt::Long ();
use File::Slurp qw/read_file/;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions) = @_;
    $c->stats->profile(begin => "_cmd_graph($action)");
    my $now = time();
    if(!defined $c->stash->{'remote_user'}) {
        $c->stash->{'remote_user'} = 'cli';
    }

    # parse options
    my $opt = {};
    Getopt::Long::Configure('no_ignore_case');
    Getopt::Long::Configure('bundling');
    Getopt::Long::Configure('pass_through');
    Getopt::Long::GetOptionsFromArray($commandoptions,
       "s|start=s"          => \$opt->{'start'},
         "end=s"            => \$opt->{'end'},
         "format=s"         => \$opt->{'format'},
         "host=s"           => \$opt->{'host'},
         "service=s"        => \$opt->{'service'},
         "width=i"          => \$opt->{'width'},
         "height=i"         => \$opt->{'height'},
         "source=i"         => \$opt->{'source'},
         "o|output=s"       => \$opt->{'output'},
    ) or do {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    };
    return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__)) unless $opt->{'host'};

    my $start  = ($opt->{'start'} || $now-86400);
    my $end    = ($opt->{'end'}   || $now);
    # if no start / end given, round to nearest 10 seconds which makes caching more effective
    if(!$opt->{'start'} && !$opt->{'end'}) {
        $start = $start - $start % 10;
        $end   = $end   - $end   % 10;
    }
    my $format = $opt->{'format'} || 'png';
    my $width  = $opt->{'width'}  || 800;
    my $height = $opt->{'height'} || 300;
    if($format ne 'png' && $format ne 'base64') {
        return("ERROR: please use either 'png' or 'base64' format.", 1);
    }
    # use cached version?
    Thruk::Utils::IO::mkdir($c->config->{'tmp_path'}.'/graphs/');
    my $cache_file = $opt->{'host'}.'_'.($opt->{'service'} || '_HOST_');
    $cache_file =~ s|[^a-zA-Z_\-]|_|gmx;
    $cache_file = $cache_file.'-'.$start.'-'.$end.'-'.($opt->{'source'}||'').'-'.$width.'-'.$height.'.'.$format;
    $cache_file = $c->config->{'tmp_path'}.'/graphs/'.$cache_file;
    if(-e $cache_file) {
        _debug("cache hit from ".$cache_file);
        $c->stats->profile(end => "_cmd_graph($action)");
        return(scalar read_file($cache_file), 0);
    }

    # create new image
    my $img = Thruk::Utils::get_perf_image($c, {
            host    => $opt->{'host'},
            service => $opt->{'service'},
            start   => $start,
            end     => $end,
            width   => $width,
            height  => $height,
            source  => $opt->{'source'},
            follow  => 1,
    });
    if(!$img) {
        _info(sprintf("could not export any image, check if the %s %s%s has a valid graph url (action_url or notes_url).",
                ($opt->{'service'} && $opt->{'service'} ne '_HOST_') ? 'service' : 'host',
                $opt->{'host'},
                ($opt->{'service'} && $opt->{'service'} ne '_HOST_') ? ' - '.$opt->{'service'} : '',
        ));
        return("", 1);
    }
    if($format eq 'base64') {
        require MIME::Base64;
        $img = MIME::Base64::encode_base64($img);
    }
    elsif($format eq 'png') {
        $c->res->content_type('image/png');
    }
    Thruk::Utils::IO::write($cache_file, $img);
    _debug2("cached graph to ".$cache_file);

    # clean old cached files, threshold is 5minutes, since we mainly
    # want to cache files used from many seriel notifications
    for my $file (glob($c->config->{'tmp_path'}.'/graphs/*')) {
        my $mtime = (stat($file))[9];
        if($mtime < $now - 300) {
            _debug2("removed old cached file (mtime: ".scalar($mtime)."): ".$file);
            unlink($file);
        }
    }
    if($opt->{'output'} && $opt->{'output'} ne '-') {
        Thruk::Utils::IO::write($opt->{'output'}, $img);
        $img = sprintf("graph written to %s", $opt->{'output'});
    }
    $c->stats->profile(end => "_cmd_graph($action)");
    return($img, 0);
}

##############################################

=head1 EXAMPLES

Export pnp host graph for localhost in base64 format.

  %> thruk graph --host='localhost' --service='_HOST_' --width=900 --height=200 --format=base64

=cut

##############################################

1;
