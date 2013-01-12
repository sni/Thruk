package Thruk::Utils::Reports::Render;

=head1 NAME

Thruk::Utils::Render - Report Rendering Utilities Collection

=head1 DESCRIPTION

Report Rendering Utilities Collection. All subs will be available in report
templates. Templates are Template::Toolkit templates and are responsible for
the report layout, the mail content and the required parameters for a report.

=cut

use warnings;
use strict;
use Carp;
use Data::Dumper;
use File::Temp qw/tempfile/;
use File::Slurp;
use MIME::Base64;

$Thruk::Utils::Reports::Render::c      = undef;
$Thruk::Utils::Reports::Render::locale = {};

##########################################################

=head1 METHODS

=head2 sort_by_key

  sort_by_key()

return sorted list of hashes

=cut

sub sort_by_key {
    my($list, $sort_field) = @_;

    my @sorted = sort { $a->{$sort_field} <=> $b->{$sort_field} } @{$list};
    return \@sorted;
  }


##########################################################

=head2 current_page

  current_page()

return and increase page number

=cut
sub current_page {
    my $page = shift;
    our $current_page;
    $current_page = 0 unless defined $current_page;
    $current_page++;
    $current_page = $page if defined $page;
    return $current_page;
}

##########################################################

=head2 calculate_availability

  calculate_availability()

calculate availability from stash data

=cut
sub calculate_availability {
    my $c = $Thruk::Utils::Reports::Render::c or die("not initialized!");
    Thruk::Utils::Avail::calculate_availability($c);
    return 1;
}

##########################################################

=head2 outages

  outages($logs, $start, $end, $x, $y, $step1, $step2, $max)

print outages from log entries

=cut
sub outages {
    my($logs, $start, $end) = @_;

    my $c   = $Thruk::Utils::Reports::Render::c or die("not initialized!");
    my $u   = $c->stash->{'unavailable_states'};

    # combine outages
    my @reduced_logs;
    my($combined, $last);
    my $downtime = 0;
    for my $l (@{$logs}) {
        $l->{'class'} = lc $l->{'class'};
        $downtime = $l->{'in_downtime'} if defined $l->{'in_downtime'};
        if(!defined $combined) {
            $combined = $l;
        }
        # combine classes if report should contain downtimes too
        if($downtime) {
            if(   (defined $u->{$l->{'class'}}  and !defined $u->{$l->{'class'}.'_downtime'})
               or (!defined $u->{$l->{'class'}} and defined $u->{$l->{'class'}.'_downtime'})
            ) {
                $combined->{'class'} = $combined->{'class'}.'_downtime';
            }
        }
        if($combined->{'class'} ne $l->{'class'}) {
            $combined->{'real_end'} = $l->{'start'};
            push @reduced_logs, $combined;
            undef $combined;
            $combined = $l;
        }
        $last = $l;
    }
    if(defined $last) {
        $combined->{'real_end'} = $last->{'end'};
        push @reduced_logs, $combined;
    }

    my $outages = [];
    for my $l (reverse @reduced_logs) {
        next if $end   < $l->{'start'};
        next if $start > $l->{'real_end'};
        $l->{'start'}    = $start if $start > $l->{'start'};
        $l->{'real_end'} = $end   if $end   < $l->{'real_end'};
        $l->{'duration'} = $l->{'real_end'} - $l->{'start'};
        if(defined $u->{$l->{'class'}}) {
            push @{$outages}, $l;
        }
    }

    return $outages;
}

##########################################################

=head2 set_unavailable_states

  set_unavailable_states($states)

set list of states which count as unavailable

=cut
sub set_unavailable_states {
    my($states) = @_;
    my $c = $Thruk::Utils::Reports::Render::c or die("not initialized!");
    $c->stash->{'unavailable_states'} = {};
    if(defined $states and $states ne '') {
        for my $s (@{$states}) {
            $c->stash->{'unavailable_states'}->{$s} = 1;
        }
    }
    return 1;
}

##########################################################

=head2 get_report_timeperiod

  get_report_timeperiod()

return report timeperiod in human readable form

=cut
sub get_report_timeperiod {
    my($start, $end, $format) = @_;
    return Thruk::Utils::format_date($start, $format).' - '.Thruk::Utils::format_date(($end - 1), $format);
}

##########################################################

=head2 get_events

  get_events()

set events by pattern from eventlog

=cut
sub get_events {
    my $c             = $Thruk::Utils::Reports::Render::c or die("not initialized!");
    my($start,$end)   = Thruk::Utils::get_start_end_for_timeperiod_from_param($c);
    my $pattern          = $c->{'request'}->{'parameters'}->{'pattern'};
    my $exclude_pattern  = $c->{'request'}->{'parameters'}->{'exclude_pattern'};
    die('no pattern') unless defined $pattern;

    my @filter;
    push @filter, { time => { '>=' => $start }};
    push @filter, { time => { '<=' => $end }};

    if($pattern !~ m/^\s*$/mx) {
        die("invalid pattern: ".$pattern) unless(Thruk::Utils::is_valid_regular_expression($c, $pattern));
        push @filter, { message => { '~~' => $pattern }};
    }
    if(defined $exclude_pattern and $exclude_pattern !~ m/^\s*$/mx) {
        die("invalid pattern: ".$exclude_pattern) unless Thruk::Utils::is_valid_regular_expression($c, $exclude_pattern);
        push @filter, { message => { '!~~' => $exclude_pattern }};
    }

    my $event_types = $c->{'request'}->{'parameters'}->{'event_types'};
    # event type filter set?
    if(defined $event_types and @{$event_types} > 0) {
        my @evt_filter;
        my $typeshash = Thruk::Utils::array2hash($event_types);
        my $hst_states = 'both';
        my $svc_states = 'both';
        for my $state (qw/hard soft both/) {
            for my $typ (qw/host service/) {
                if(defined $typeshash->{$typ.'_state_'.$state}) {
                    $hst_states = $state if $typ eq 'host';
                    $svc_states = $state if $typ eq 'service';
                    delete $typeshash->{$typ.'_state_'.$state};
                }
            }
        }

        # host states
        my $hst_softlogfilter;
        if($hst_states eq 'hard') {
            $hst_softlogfilter = { options => { '~' => ';HARD;' }};
        } elsif($hst_states eq 'soft') {
            $hst_softlogfilter = { options => { '~' => ';SOFT;' }};
        }
        for my $state (qw/up down unreachable/) {
            if(defined $typeshash->{'host_'.$state}) {
                my $stateid = 0;
                $stateid = 1 if $state eq 'down';
                $stateid = 2 if $state eq 'unreachable';
                push @evt_filter, { '-and' => [ { type => 'HOST ALERT' }, { state => $stateid }, $hst_softlogfilter ] };
                delete $typeshash->{'host_'.$state};
            }
        }

        # service states
        my $svc_softlogfilter;
        if($svc_states eq 'hard') {
            $svc_softlogfilter = { options => { '~' => ';HARD;' }};
        } elsif($svc_states eq 'soft') {
            $svc_softlogfilter = { options => { '~' => ';SOFT;' }};
        }
        for my $state (qw/ok warning unknown critical/) {
            if(defined $typeshash->{'service_'.$state}) {
                my $stateid = 0;
                $stateid = 1 if $state eq 'warning';
                $stateid = 2 if $state eq 'critical';
                $stateid = 3 if $state eq 'unknown';
                push @evt_filter, { '-and' => [ { type => 'SERVICE ALERT' }, { state => $stateid }, $svc_softlogfilter ]};
                delete $typeshash->{'service_'.$state};
            }
        }

        # host notifications
        if(defined $typeshash->{'notification_host'}) {
            push @evt_filter, { '-and' => [ { type => 'HOST NOTIFICATION' } ] };
            delete $typeshash->{'notification_host'};
        }

        # service notifications
        if(defined $typeshash->{'notification_service'}) {
            push @evt_filter, { '-and' => [ { type => 'SERVICE NOTIFICATION' } ] };
            delete $typeshash->{'notification_service'};
        }

        # combine filter
        my $or_filter = Thruk::Utils::combine_filter('-or', \@evt_filter);
        push @filter, $or_filter;

        # unknown filter left?
        if(scalar keys %{$typeshash} > 0) {
            die("filter left: ".Dumper($typeshash));
        }
    }

    my $total_filter = Thruk::Utils::combine_filter('-and', \@filter);
    $c->{'db'}->renew_logcache($c, 1);
    my $logs = $c->{'db'}->get_logs(filter => [$total_filter], sort => {'DESC' => 'time'});

    if($c->{'request'}->{'parameters'}->{'reverse'}) {
        @{$logs} = reverse @{$logs};
    }

    $c->stash->{'start'} = $start;
    $c->stash->{'end'}   = $end;
    $c->stash->{'logs'}  = $logs;

    return 1;
}

##########################################################

=head2 get_url

  get_url()

save content from url

=cut
sub get_url {
    my $c = $Thruk::Utils::Reports::Render::c or die("not initialized!");

    my $url = $c->stash->{'param'}->{'url'};
    if($url =~ m|^\w+\.cgi|gmx) {
        $url = '/thruk/cgi-bin/'.$url;
    }
    if(defined $c->stash->{'param'}->{'theme'}) {
        $url = $url.'&theme='.$c->stash->{'param'}->{'theme'};
    }
    if(defined $c->stash->{'param'}->{'minimal'} and lc($c->stash->{'param'}->{'minimal'}) eq 'yes') {
        $url = $url.'&minimal=1';
    }
    if(defined $c->stash->{'param'}->{'nav'} and lc($c->stash->{'param'}->{'nav'}) eq 'no') {
        $url = $url.'&nav=0';
    }
    if($url !~ m/\?/mx) { $url =~ s/\&/?/mx; }

    my @res = Thruk::Utils::CLI::_request_url($c, $url);
    my $result = $res[1];
    if(defined $result and defined $result->{'headers'}) {
        $Thruk::Utils::PDF::ctype = $result->{'headers'}->{'Content-Type'};
        $Thruk::Utils::PDF::ctype =~ s/;.*$//mx;
        if(defined $result->{'headers'}->{'Content-Disposition'}) {
            my $file = $result->{'headers'}->{'Content-Disposition'};
            if($file =~ m/filename="(.*)"/mx) {
                $Thruk::Utils::PDF::attachment = $1;
            }
        } else {
            my $ext = 'dat';
            if($Thruk::Utils::PDF::ctype eq 'text/html') {
                $ext = 'html';
            } elsif($Thruk::Utils::PDF::ctype =~ m|image/(.*)$|mx) {
                $ext = $1;
            }
            if($url =~ m|^/thruk/cgi\-bin/([^\.]+)\.cgi|mx) {
                $Thruk::Utils::PDF::attachment = $1.'.'.$ext;
            }
        }
        if($Thruk::Utils::PDF::ctype eq 'text/html') {
            my $report_base_url = $c->config->{'Thruk::Plugin::Reports2'}->{'report_base_url'} || $c->config->{'report_base_url'};
            $result->{'result'} = _replace_css_and_images($result->{'result'});
            $result->{'result'} = _replace_links($result->{'result'}, $url, $report_base_url);

            if(!defined $c->stash->{'param'}->{'js'} or $c->stash->{'param'}->{'js'} eq 'no') {
                $result->{'result'} =~ s/<script[^>]*>.*?<\/script>//gsmxi;
            }
        }
        my $attachment = $c->stash->{'attachment'};
        open(my $fh, '>', $attachment);
        binmode $fh;
        print $fh $result->{'result'};
        Thruk::Utils::IO::close($fh, $attachment);
    }
    return $result->{'result'};
}

##########################################################

=head2 count_event_totals

  count_event_totals()

count host / service totals from events

=cut
sub count_event_totals {
    my($logs) = @_;
    my $totals = {
        'host' => {
            'up'            => 0,
            'down'          => 0,
            'unreachable'   => 0,
        },
        'service' => {
            'ok'            => 0,
            'warning'       => 0,
            'unknown'       => 0,
            'critical'      => 0,
        },
    };

    for my $l (@{$logs}) {
        if($l->{'service_description'}) {
            $l->{'state'} == 0 && $totals->{'service'}->{'ok'}++;
            $l->{'state'} == 1 && $totals->{'service'}->{'warning'}++;
            $l->{'state'} == 2 && $totals->{'service'}->{'critical'}++;
            $l->{'state'} == 3 && $totals->{'service'}->{'unknown'}++;
        }
        elsif($l->{'host_name'}) {
            $l->{'state'} == 0 && $totals->{'host'}->{'up'}++;
            $l->{'state'} == 1 && $totals->{'host'}->{'down'}++;
            $l->{'state'} == 2 && $totals->{'host'}->{'unreachable'}++;
        }
    }

    return $totals;
}

##########################################################

=head2 get_availability_percents

  get_availability_percents()

return list of availability percent as json list

=cut
sub get_availability_percents {
    my $c = $Thruk::Utils::Reports::Render::c or die("not initialized!");

    my $host           = $c->{'request'}->{'parameters'}->{'host'};
    my $service        = $c->{'request'}->{'parameters'}->{'service'};
    confess("No host in parameters:\n".    Dumper($c->{'request'}->{'parameters'})) unless defined $host;
    my $avail;
    if($service) {
        $avail = $c->stash->{'avail_data'}->{'services'}->{$host}->{$service};
    } else {
        $avail = $c->stash->{'avail_data'}->{'hosts'}->{$host};
    }
    return unless defined $avail;

    my $u = $c->stash->{'unavailable_states'};
    my $values = {};
    for my $name (sort keys %{$avail->{'breakdown'}}) {
        my $t = $avail->{'breakdown'}->{$name};

        my($percent, $time) = _sum_availability($t, $u);
        $values->{$name} = [
            $t->{'timestamp'}*1000,
            $percent,
        ];
    }

    my $x = 1;
    my $json = {keys => [], values => [], tvalues => []};
    for my $key (sort keys %{$values}) {
        push @{$json->{'keys'}},    [$x, $key];
        push @{$json->{'values'}},  [$x, $values->{$key}->[1]+=0 ];
        push @{$json->{'tvalues'}}, [$values->{$key}->[0], $values->{$key}->[1]+=0 ];
        $x++;
    }

    my($percent, $time) = _sum_availability($avail, $u);
    $json->{'total'} = {
        'percent' => $percent,
        'time'    => $time,
    };
    return $json;
}


##########################################################

=head2 get_month_name

  get_month_name(date, monthNamesList)

return human readable month name

=cut
sub get_month_name {
    my($date, $months) = @_;
    $date =~ m/\d+\-(\d+)/mx;
    my $nr = $1 - 1;
    if($nr > 11) { $nr = $nr - 12; }
    return($months->[$nr]);
}

##########################################################

=head2 get_week_name

  get_week_name(date)

return human readable week name

=cut
sub get_week_name {
    my($date, $abbr) = @_;
    $date =~ m/\d+\-WK(\d+)/mx;
    return($abbr.$1);
}

##########################################################

=head2 get_day_name

  get_day_name(date)

return human readable day name

=cut
sub get_day_name {
    my($date, $months) = @_;
    $date =~ m/(\d+)\-(\d+)\-(\d+)/mx;
    return(get_month_name($1.'-'.$2, $months).' '.$3);
}


##########################################################

=head2 get_pnp_image

  get_pnp_image(hst, svc, start, end, width, height)

return base64 encoded pnp image if possible.
A string will be returned if no PNP graph can be exported.

=cut
sub get_pnp_image {
    my($hst, $svc, $start, $end, $width, $height) = @_;
    my $c        = $Thruk::Utils::Reports::Render::c or die("not initialized!");
    my $exporter = $c->config->{'Thruk::Plugin::Reports2'}->{'pnp_export'} || $c->config->{plugin_path}.'/plugins-enabled/reports2/script/pnp_export.sh';
    my $pnpurl   = "";

    if($svc) {
        my $svcdata = $c->{'db'}->get_services(filter => [{ host_name => $hst, description => $svc }]);
        $pnpurl     = Thruk::Utils::get_pnp_url($c, $svcdata->[0], 1);
    } else {
        my $hstdata = $c->{'db'}->get_hosts(filter => [{ name => $hst }]);
        $pnpurl     = Thruk::Utils::get_pnp_url($c, $hstdata->[0], 1);
        $svc = '_HOST_';
    }

    my($fh, $filename) = tempfile();
    my $cmd = $exporter.' "'.$hst.'" "'.$svc.'" "'.$width.'" "'.$height.'" "'.$start.'" "'.$end.'" "'.$pnpurl.'" "'.$filename.'"';
    `$cmd`;
    if(-s $filename) {
        my $imgdata  = read_file($filename);
        return 'data:image/png;base64,'.encode_base64($imgdata);
    }
    unlink($filename);
    return "";
}


##########################################################

=head2 dump

  dump(...)

dump variables to stderr

=cut
sub dump {
    print STDERR  Dumper(@_);
    return "";
}

##########################################################
# INTERNAL SUBS
##########################################################
sub _replace_css_and_images {
    my $text = shift;
    my $c = $Thruk::Utils::Reports::Render::c or die("not initialized!");
    $text =~ s/<link[^>]*href=("|')([^'"]*\.css)("|')[^>]*>/&_replace_css($2)/gemx;
    $text =~ s/<script[^>]*src=("|')([^'"]*\.js)("|')><\/script>/&_replace_js($2)/gemx;
    $text =~ s/(<img[^>]*src=)
               ("|')
               ([^'"]*)
               ("|')
               ([^>]*>)
              /&_replace_img($1,$2,$3,$4,$5)/gemx;
    $text =~ s/(<input[^>]*src=)
               ("|')
               ([^'"]*)
               ("|')
               ([^>]*>)
              /&_replace_img($1,$2,$3,$4,$5)/gemx;
    return $text;
}

##########################################################
sub _replace_links {
    my($text, $url, $baseurl) = @_;
    return $text unless defined $baseurl;
    $baseurl =~ s|/thruk/.*||gmx;
    $baseurl =~ s|/$||gmx;
    $baseurl .= '/thruk/cgi-bin/';
    $text =~ s/(<a[^>]*href=)
               ("|')
               ([^'"]*)
               ("|')
               ([^>]*>)
              /&_replace_link($baseurl,$1,$2,$3,$4,$5)/gemx;

    $text =~ s/(<form[^>]*action=)
               ("|')
               ([^'"]*)
               ("|')
               ([^>]*>)
              /&_replace_link($baseurl,$1,$2,$3,$4,$5)/gemx;

    return $text;
}

##########################################################
sub _replace_link {
    my($baseurl,$a,$b,$url,$d,$e) = @_;
    if(    $url !~ m|^\w+://|mx
       and $url !~ m|^\#|mx
       and $url !~ m|^mailto:|mx
      ) {
        # absolute url
        if($url =~ m/^\//mx) {
            $baseurl =~ s|/thruk/cgi\-bin/$||mx;
            $url = $baseurl.$url;
        }
        # relative url
        else {
            $url = $baseurl.$url;
        }
    }
    return $a.$b.$url.$d.$e;
}

##########################################################
sub _replace_img {
    my($a,$b,$url,$d,$e) = @_;
    return "" if $url eq '';
    # skip some images
    return "" if $url =~ m/waiting\.gif$/mx;

    our $image_cache;
    $image_cache = {} unless defined $image_cache;
    return $image_cache->{$url} if defined $image_cache->{$url};

    my $c = $Thruk::Utils::Reports::Render::c or die("not initialized!");

    # dynamic images
    if($url =~ m/^\w+\.cgi/mx) {
        if($url =~ m|^\w+\.cgi|gmx) {
            $url = '/thruk/cgi-bin/'.$url;
        }
        my @res = Thruk::Utils::CLI::_request_url($c, $url);
        my $result = $res[1];
        my $text = "data:image/png;base64,".encode_base64($result->{'result'}, '');
        $image_cache->{$url} = $a.$b.$text.$d.$e;
        return $image_cache->{$url};
    }
    # static images
    elsif($url =~ m/\.(\w+)$/mx) {
        my $data = _read_static_content_file($url);
        my $text = "data:image/$1;base64,".encode_base64($data, '');
        $image_cache->{$url} = $a.$b.$text.$d.$e;
        return $image_cache->{$url};
    }
    elsif($url =~ m/^data:/mx) {
        $image_cache->{$url} = $a.$b.$url.$d.$e;
        return $image_cache->{$url};
    }

    croak("unknown image url: ".$a.$b.$url.$d.$e);
    return "";
}

##########################################################
sub _replace_css {
    my $url = shift;
    my $css = _read_static_content_file($url);
    $css =~ s/(url\()
              ([^)]*)
              (\))
             /&_replace_css_img($url,$1,$2,$3)/gemx;
    my $text = "<style type='text/css'>\n<!--\n";
    $text .= $css;
    $text .= "\n-->\n</style>\n";
    return $text;
}

##########################################################
sub _replace_js {
    my $url = shift;
    my $c = $Thruk::Utils::Reports::Render::c or die("not initialized!");
    if(!defined $c->stash->{'param'}->{'js'} or $c->stash->{'param'}->{'js'} eq 'no') {
        return "";
    }
    my $text = "<script type='text/javascript'>\n<!--\n";
    $text .= _read_static_content_file($url);
    $text .= "\n-->\n</script>\n";
    return $text;
}

##############################################
sub _replace_css_img {
    my($css, $a,$file,$b) = @_;
    # static images
    if($file =~ m/\.(\w+)$/mx) {
        my $data = "data:image/$1;base64,";
        # get basename of css file
        $css =~ s|/[^/]*$||mx;
        $data .= encode_base64(_read_static_content_file($css.'/'.$file), '');
        return "$a$data$b";
    }
    return "";
}

##############################################
sub _read_static_content_file {
    my $url = shift;
    my $c = $Thruk::Utils::Reports::Render::c or die("not initialized!");
    $url =~ s|^.*/thruk/||gmx;
    while($url =~ m|[^/\.]+/\.\./|mx) {
        $url   =~ s|[^/\.]+/\.\./||mx;
    }
    my $file;
    if($url =~ m|^themes/|mx) {
        $url =~ s|^themes/||gmx;
        my $themes_dir = $c->config->{'themes_path'} || $c->config->{'project_root'}."/themes";
        $file = $themes_dir . '/themes-enabled/' . $url;
    }
    elsif($url =~ m|^plugins/|mx) {
        $url =~ s|^plugins/([^/]+)/|$1/root/|gmx;
        my $plugins_dir = $c->config->{'plugin_path'} || $c->config->{'project_root'}."/plugins";
        $file = $plugins_dir . '/plugins-enabled/' . $url;
    } else {
        $file = $c->config->{'project_root'}."/root/thruk/".$url;
    }
    return '' if $url eq '';
    if(-e $file) {
        return read_file($file);
    }
    croak("_read_static_content_file($url) $file: $!");
    return "";
}

##############################################
sub _sum_availability {
    my($t, $u) = @_;
    my $time = {
        'available'    => 0,
        'unavailable'  => 0,
        'undetermined' => 0,
    };
    for my $s ( keys %{$t} ) {
        for my $state (qw/ok warning critical unknown up down unreachable/) {
            if($s eq 'time_'.$state) {
                if(defined $u->{$state}) {
                    $time->{'unavailable'} += $t->{'time_'.$state} - $t->{'scheduled_time_'.$state};
                } else {
                    $time->{'available'}   += $t->{'time_'.$state} - $t->{'scheduled_time_'.$state};
                }
            }
            elsif($s eq 'scheduled_time_'.$state) {
                if(defined $u->{$state.'_downtime'}) {
                    $time->{'unavailable'} += $t->{'scheduled_time_'.$state};
                } else {
                    $time->{'available'}   += $t->{'scheduled_time_'.$state};
                }
            }
        }
        $time->{'undetermined'} += $t->{'time_indeterminate_notrunning'}         || 0;
        $time->{'undetermined'} += $t->{'time_indeterminate_nodata'}             || 0;
        $time->{'undetermined'} += $t->{'time_indeterminate_outside_timeperiod'} || 0;
    }

    my $percent = -1;
    if($time->{'available'} + $time->{'unavailable'} > 0) {
        $percent = $time->{'available'} / ($time->{'available'} + $time->{'unavailable'}) * 100;
    }
    return($percent, $time);
}

##############################################
sub _locale {
    my($fmt) = shift;
    my $tr  = $Thruk::Utils::Reports::Render::locale;
    $fmt = $tr->{$fmt} || $fmt;
    return sprintf($fmt, @_);
}

##############################################

=head1 EXAMPLES

See the shipped reports for some examples. Shipped reports are in the
'plugins/plugins-available/reports2/templates/reports' folder.

=head1 AUTHOR

Sven Nierlein, 2012, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
