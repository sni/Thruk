package Thruk::Utils::PDF;

=head1 NAME

Thruk::Utils::PDF - Utilities Collection for creating PDFs

=head1 DESCRIPTION

Utilities Collection for PDFs. All subs will be available in PDF templates.
Templates are Template::Toolkit templates and are responsible for the pdf
layout, the mail content and the required parameters for a report.

=cut

use warnings;
use strict;
use Carp;
use Data::Dumper;
use File::Temp qw/tempfile/;
use File::Slurp;
use MIME::Base64;
use Chart::Clicker;
use Chart::Clicker::Data::DataSet;
use Chart::Clicker::Data::Series;
use Chart::Clicker::Renderer::Pie;
use Chart::Clicker::Renderer::StackedBar;
use Chart::Clicker::Decoration::Legend::Tabular;
use Chart::Clicker::Data::Marker;
use Chart::Clicker::Data::Range;
use Graphics::Color::RGB;

$Thruk::Utils::PDF::c   = undef;
$Thruk::Utils::PDF::pdf = undef;

##########################################################

=head1 METHODS

=head2 init_pdf

  init_pdf($pdf)

set pdf object for later use

=cut
sub init_pdf {
    my($pdf) = @_;
    $Thruk::Utils::PDF::pdf = $pdf;
    return 1;
}

##########################################################

=head2 render_pie_chart

  render_pie_chart($type)

render a pie chart into tmpfile and return filename of the pdf

=cut
sub render_pie_chart {
    my($type) = @_;
    return(_render_svc_pie_chart()) if $type eq 'service';
    return(_render_hst_pie_chart()) if $type eq 'host';
    return;
}

##########################################################

=head2 render_bar_chart

  render_bar_chart()

render a bar chart into tmp file and return filename of the pdf

=cut
sub render_bar_chart {
    return(_generate_bar_chart());
}

##########################################################

=head2 path_to_template

  path_to_template($filename)

return absolute filename for a template

=cut
sub path_to_template {
    my($filename) = @_;
    my $c = $Thruk::Utils::PDF::c or die("not initialized!");
    our($path_to_template_cache);
    return $path_to_template_cache->{$filename} if defined $path_to_template_cache->{$filename};
    # search template paths
    for my $path (@{$c->config->{templates_paths}}, $c->config->{'View::TT'}->{'INCLUDE_PATH'}) {
        if(-e $path.'/'.$filename) {
            $path_to_template_cache->{$filename} = $path.'/'.$filename;
            return $path.'/'.$filename;
        }
    }
    return;
}

##########################################################

=head2 calculate_availability

  calculate_availability()

calculate availability from stash data

=cut
sub calculate_availability {
    my $c = $Thruk::Utils::PDF::c or die("not initialized!");
    Thruk::Utils::Avail::calculate_availability($c);
    return 1;
}

##########################################################

=head2 font

  font($size, $color)

set color with given size and color

=cut
sub font {
    my($size, $color) = @_;
    my $pdf = $Thruk::Utils::PDF::pdf or die("not initialized!");
    $pdf->prFontSize($size);
    _pdf_color($color);
    return 1;
}

##########################################################

=head2 outages

  outages($logs, $start, $end, $x, $y, $step1, $step2, $max)

print outages from log entries

=cut
sub outages {
    my($logs, $start, $end, $x, $y, $step1, $step2, $max) = @_;

    my $c   = $Thruk::Utils::PDF::c   or die("not initialized!");
    my $pdf = $Thruk::Utils::PDF::pdf or die("not initialized!");
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

    my $found    = 0;
    for my $l (reverse @reduced_logs) {
        next if $end   < $l->{'start'};
        next if $start > $l->{'real_end'};
        $l->{'start'}    = $start if $start > $l->{'start'} ;
        $l->{'real_end'} = $end   if $end   < $l->{'real_end'} ;
        if(defined $u->{$l->{'class'}}) {
            $found++;
            my $txt = '';
            $txt .= Thruk::Utils::format_date($l->{'start'}, $c->{'stash'}->{'datetime_format'});
            $txt .= " - ".Thruk::Utils::format_date($l->{'real_end'}, $c->{'stash'}->{'datetime_format'});
            $pdf->prText($x,$y, $txt);
            $txt = "(".Thruk::Utils::Filter::duration($l->{'real_end'}-$l->{'start'}).")";
            $pdf->prText($x+400,$y, $txt);
            $y = $y - $step1;
            $pdf->prText($x,$y, '  -> '.$l->{'plugin_output'});
            $y = $y - $step2;
            last if defined $max and $found >= $max;
        }
    }

    # no logs at all?
    if($found == 0) {
        $pdf->prText($x,$y, 'no outages during this timeperiod');
        return 1;
    }

    return 1;
}

##########################################################

=head2 set_unavailable_states

  set_unavailable_states($states)

set list of states which count as unavailable

=cut
sub set_unavailable_states {
    my($states) = @_;
    my $c = $Thruk::Utils::PDF::c or die("not initialized!");
    $c->stash->{'unavailable_states'} = {};
    if(defined $states and $states ne '') {
        for my $s (@{$states}) {
            $c->stash->{'unavailable_states'}->{$s} = 1;
        }
    }
    return 1;
}


##########################################################

=head2 fill_availability_table

  fill_availability_table($x, $y, $c1, $c2)

set list of states which count as unavailable

=cut
sub fill_availability_table {
    my($x, $y, $c1, $c2) = @_;
    $c1 = 'dark grey' unless defined $c1;
    $c2 = 'red'       unless defined $c2;
    my $c   = $Thruk::Utils::PDF::c   or die("not initialized!");
    my $pdf = $Thruk::Utils::PDF::pdf or die("not initialized!");
    my $sla = $c->stash->{'param'}->{'sla'};
    my $a   = $Thruk::Utils::PDF::availabilitys->{'values'};
    my $l   = $Thruk::Utils::PDF::availabilitys->{'lables'};

    # only the last 12 values can be displayed
    my $z = 0;
    if(@{$a->{'AVAILABLE'}} > 12) { $z = @{$a->{'AVAILABLE'}} - 12; }
    for(;$z < @{$a->{'AVAILABLE'}}; $z++) {
        next if $l->[$z] eq '';
        my $val = $a->{'AVAILABLE'}->[$z];
        _pdf_color($c1);
        $pdf->prText($x,$y, $l->[$z]);
        if($a->{'UNDETERMINED'}->[$z] < 100) {
            _pdf_color($c2) if $val < $sla;
            $pdf->prText($x-10,$y-13, $val."%");
        }
        $x = $x+45;
    }

    return 1;
}

##########################################################

=head2 get_events

  get_events()

set events by pattern from eventlog

=cut
sub get_events {
    my $c             = $Thruk::Utils::PDF::c or die("not initialized!");
    my($start,$end)   = Thruk::Utils::get_start_end_for_timeperiod_from_param($c);
    $c->stash->{'start'} = $start;
    $c->stash->{'end'}   = $end;
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
    my $logs = $c->{'db'}->get_logs(filter => [$total_filter], sort => {'DESC' => 'time'});
    $c->stash->{'logs'} = $logs;
    return 1;
}

##########################################################

=head2 get_url

  get_url()

save content from url

=cut
sub get_url {
    my $c = $Thruk::Utils::PDF::c or die("not initialized!");

    my $url = $c->stash->{'param'}->{'url'};
    if($url =~ m|^\w+\.cgi|gmx) {
        $url = '/thruk/cgi-bin/'.$url;
    }
    if(defined $c->stash->{'param'}->{'theme'}) {
        $url = $url.'&theme='.$c->stash->{'param'}->{'theme'};
    }
    if(defined $c->stash->{'param'}->{'minimal'} and $c->stash->{'param'}->{'minimal'} eq 'yes') {
        $url = $url.'&minimal=1';
    }
    if(defined $c->stash->{'param'}->{'nav'} and $c->stash->{'param'}->{'nav'} eq 'no') {
        $url = $url.'&nav=0';
    }

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
            $result->{'result'} = _replace_css_and_images($result->{'result'});
            $result->{'result'} = _replace_links($result->{'result'}, $url, $c->config->{'report_base_url'});
        }
        my $attachment = $c->stash->{'attachment'};
        open(my $fh, '>', $attachment);
        binmode $fh;
        print $fh $result->{'result'};
        Thruk::Utils::IO::close($fh, $attachment);

    }
    return 1;
}

##########################################################

=head2 print_event_totals

  print_event_totals()

count host / service totals from events

=cut
sub print_event_totals {
    my($x, $y, $step) = @_;
    my $c   = $Thruk::Utils::PDF::c or die("not initialized!");
    my $pdf = $Thruk::Utils::PDF::pdf or die("not initialized!");
    confess("no logs, forgot to run get_events()?") unless defined $c->stash->{'logs'};
    my $totals = {
        'ok'            => 0,
        'warning'       => 0,
        'unknown'       => 0,
        'critical'      => 0,
        'up'            => 0,
        'down'          => 0,
        'unreachable'   => 0,
    };

    for my $l (@{$c->stash->{'logs'}}) {
        if($l->{'service_description'}) {
            if($l->{'state'} == 0) {
                $totals->{'ok'}++;
            }
            elsif($l->{'state'} == 1) {
                $totals->{'warning'}++;
            }
            elsif($l->{'state'} == 2) {
                $totals->{'critical'}++;
            }
            elsif($l->{'state'} == 3) {
                $totals->{'unknown'}++;
            }
        }
        elsif($l->{'host_name'}) {
            if($l->{'state'} == 0) {
                $totals->{'up'}++;
            }
            elsif($l->{'state'} == 1) {
                $totals->{'down'}++;
            }
            elsif($l->{'state'} == 2) {
                $totals->{'unreachable'}++;
            }
        }
    }

    $pdf->prText( $x, $y, $totals->{'up'}, 'right');
    $y = $y - $step;
    $pdf->prText( $x, $y, $totals->{'down'}, 'right');
    $y = $y - $step;
    $pdf->prText( $x, $y, $totals->{'unreachable'}, 'right');
    $y = $y - $step * 3;
    $pdf->prText( $x, $y, $totals->{'ok'}, 'right');
    $y = $y - $step;
    $pdf->prText( $x, $y, $totals->{'warning'}, 'right');
    $y = $y - $step;
    $pdf->prText( $x, $y, $totals->{'unknown'}, 'right');
    $y = $y - $step;
    $pdf->prText( $x, $y, $totals->{'critical'}, 'right');

    return 1;
}

##########################################################

=head2 log_icon

  log_icon(x, y, icon, file)

set icon for logfiles

=cut
sub log_icon {
    my($x, $y, $icon, $pdf_file) = @_;

    my $c = $Thruk::Utils::PDF::c or die("not initialized!");
    my $pdf = $Thruk::Utils::PDF::pdf or die("not initialized!");

    $pdf->prImage( { 'file'    => $pdf_file,
                     'page'    => _icon_to_number($icon),
                     'imageNo' => 1,
                     'x'       => $x,
                     'y'       => $y,
                   });
    return 1;
}

##########################################################

=head2 page_footer

  page_footer(x, y, page, [ size, [ color ]])

print page footer

=cut
sub page_footer {
    my($x, $y, $page, $size, $color) = @_;
    my $pdf = $Thruk::Utils::PDF::pdf or die("not initialized!");
    $size = 10 unless defined $size;
    $color = 'white' unless defined $color;
    font($size, $color);
    $pdf->prText($x,$y, $page, 'right');
    return 1;
}

##########################################################
# INTERNAL SUBS
##########################################################
sub _icon_to_number {
    my($icon) = @_;
    our($icon_to_number_cache);
    return $icon_to_number_cache->{$icon} if defined $icon_to_number_cache->{$icon};

    my $ico = $icon;
    $ico =~ s/^.*\///mx;
    my $number = 1;
    my $tr_table = {
        'info.png'         => 1,
        'recovery.png'     => 2,
        'warning.png'      => 3,
        'unknown.png'      => 4,
        'critical.png'     => 5,
        'command.png'      => 6,
        'downtime.gif'     => 7,
        'flapping.gif'     => 8,
        'serviceevent.gif' => 9,
        'hostevent.gif'    => 10,
        'logrotate.png'    => 11,
        'notify.gif'       => 12,
        'passiveonly.gif'  => 13,
        'start.gif'        => 14,
        'stop.gif'         => 15,
        'restart.gif'      => 16,
    };
    $number = $tr_table->{$ico} if defined $tr_table->{$ico};
    $icon_to_number_cache->{$icon} = $number;
    return $number;
}

##########################################################
sub _render_bar_chart {
    my($options) = @_;
    my $c = $Thruk::Utils::PDF::c or die("not initialized!");

    # cannot render single bars
    if(scalar keys %{$options->{'values'}} == 1) {
        my $col = _get_colors();
        $options->{'values'}->{''} = {
            'name'   => '',
            'values' => [
                { name => 'PLACEHOLDER',   value => 0, color => $col->{'placeholder'} },
                { name => 'UNDETERMINED',  value => 0, color => $col->{'undetermined'} },
                { name => 'AVAILABLE',     value => 0, color => $col->{'ok'} },
                { name => 'NOT AVAILABLE', value => 0, color => $col->{'critical'} },
            ],
        }
    }
    my $cc = Chart::Clicker->new('format' => 'pdf', width => 550, height => 400);
    my @lables = ();
    my $colors = {};
    my $available = {};
    for my $name (sort keys %{$options->{'values'}}) {
        push @lables, _date_to_tick_name($name);
        my $total = 0;
        for my $item (@{$options->{'values'}->{$name}->{'values'}}) {
            $colors->{$item->{'name'}} = $item->{'color'};
            $total += $item->{'value'};
        }
        $options->{'values'}->{$name}->{'total'} = $total;
    }

    my $percs = {};
    for my $name (sort keys %{$options->{'values'}}) {
        for my $item (@{$options->{'values'}->{$name}->{'values'}}) {
            my $total = $options->{'values'}->{$name}->{'total'};
            my $perc  = '00.00';
            $perc     = sprintf("%06.3f", $item->{'value'}*100/$total) if $total > 0;
            push @{$percs->{$item->{'name'}}}, $perc;
        }
    }
    my $number_of_bars = (scalar @{$percs->{'AVAILABLE'}});
    my(@series, @colors);
    for my $name ('PLACEHOLDER', 'AVAILABLE', 'NOT AVAILABLE') {
        push @colors, $colors->{$name};
        push @series, Chart::Clicker::Data::Series->new(
            name    => $name eq 'PLACEHOLDER' ? '' : $name,
            keys    => [ 1..$number_of_bars ],
            values  => $percs->{$name},
        );
    }
    $available->{'values'} = $percs;
    $available->{'lables'} = \@lables;
    $Thruk::Utils::PDF::availabilitys = $available;

    my $ds = Chart::Clicker::Data::DataSet->new(series => \@series );
    $cc->add_to_datasets($ds);
    $cc->color_allocator->colors(\@colors);

    my $def = $cc->get_context('default');
    my $area = Chart::Clicker::Renderer::StackedBar->new(opacity => 0.8);
    $def->renderer($area);
    $def->range_axis->range->max(100);
    $def->range_axis->range->min(90);
    $def->range_axis->tick_values([90..100]);
    $def->range_axis->format('%d');

    my $lables = _reduce_lables(\@lables);
    $def->domain_axis->tick_values([1..(scalar @{$lables})]);
    $def->domain_axis->tick_labels($lables);

    $def->domain_axis->fudge_amount(0.05); # adds border at the top
    $def->range_axis->fudge_amount(0.01);

    # add red line for sla
    $def->add_marker(
        Chart::Clicker::Data::Marker->new(
                            value => $c->stash->{'param'}->{'sla'},
                            color => Graphics::Color::RGB->new(red => 1, green => 0, blue => 0),
        )
    );

    my($fh, $filename) = tempfile("chart_bar.pdf.XXXXX", DIR => $c->config->{'tmp_path'});
    $cc->write_output($filename);
    push @{$c->stash->{'tmp_files_to_delete'}}, $filename;
    return $filename;
}

##########################################################
sub _generate_bar_chart {
    my $c = $Thruk::Utils::PDF::c or die("not initialized!");

    my $col            = _get_colors();
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
    my $bar = { values => {} };
    for my $name (sort keys %{$avail->{'breakdown'}}) {
        my $t = $avail->{'breakdown'}->{$name};
        my $time = {
            'available'    => 0,
            'unavailable'  => 0,
            'undetermined' => 0,
        };
        for my $s ( keys %{$t} ) {
            for my $state (qw/ok warning critical unknown up down unreachable/) {
                if($s eq 'time_'.$state) {
                    if(defined $u->{$state}) {
                        $time->{'unavailable'} += $t->{'time_'.$state};
                    } else {
                        $time->{'available'}   += $t->{'time_'.$state};
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

        # in case we have some data for this period, undetermined is available too
        if($time->{'undetermined'} > 0 and ($time->{'available'} > 0 or $time->{'unavailable'} > 0)) {
            $time->{'available'}   += $time->{'undetermined'};
            $time->{'undetermined'} = 0;
        }

        $bar->{'values'}->{$name} = {
            name => $name,
            values => [
                { name => 'PLACEHOLDER',   value => 0,                       color => $col->{'placeholder'} },
                { name => 'UNDETERMINED',  value => $time->{'undetermined'}, color => $col->{'undetermined'} },
                { name => 'AVAILABLE',     value => $time->{'available'},    color => $col->{'ok'} },
                { name => 'NOT AVAILABLE', value => $time->{'unavailable'},  color => $col->{'critical'} },
            ],
        };
    }

    my $bar_file = _render_bar_chart($bar);
    return $bar_file;
}


##########################################################
sub _render_svc_pie_chart {
    my $c              = $Thruk::Utils::PDF::c or die("not initialized!");
    my $col            = _get_colors();
    my $host           = $c->{'request'}->{'parameters'}->{'host'};
    my $service        = $c->{'request'}->{'parameters'}->{'service'};
    my $avail          = $c->stash->{'avail_data'}->{'services'}->{$host}->{$service};
    return unless defined $avail;
    my $undetermined   = $avail->{'time_indeterminate_notrunning'} + $avail->{'time_indeterminate_nodata'} + $avail->{'time_indeterminate_outside_timeperiod'};
    my $time_ok        = $avail->{'time_ok'} + $avail->{'scheduled_time_critical'} + $avail->{'scheduled_time_unknown'} + $avail->{'scheduled_time_warning'}  + $avail->{'scheduled_time_ok'};
    my $pie = {
        values => [
            { name => 'OK',           value => $time_ok,                  color => $col->{'ok'} },
            { name => 'WARNING',      value => $avail->{'time_warning'},  color => $col->{'warning'} },
            { name => 'CRITICAL',     value => $avail->{'time_critical'}, color => $col->{'critical'} },
            { name => 'UNKNOWN',      value => $avail->{'time_unknown'},  color => $col->{'unknown'} },
            { name => 'UNDETERMINED', value => $undetermined,             color => $col->{'undetermined'} },
        ],
    };
    my $pie_file = _render_pie_chart($pie);
    return $pie_file;
}

##########################################################
sub _render_hst_pie_chart {
    my $c              = $Thruk::Utils::PDF::c or die("not initialized!");
    my $col            = _get_colors();
    my $host           = $c->{'request'}->{'parameters'}->{'host'};
    my $avail          = $c->stash->{'avail_data'}->{'hosts'}->{$host};
    return unless defined $avail;
    my $undetermined   = $avail->{'time_indeterminate_notrunning'} + $avail->{'time_indeterminate_nodata'} + $avail->{'time_indeterminate_outside_timeperiod'};
    my $time_up        = $avail->{'time_up'} + $avail->{'scheduled_time_down'} + $avail->{'scheduled_time_unreachable'} + $avail->{'scheduled_time_up'};
    my $pie = {
        values => [
            { name => 'UP',           value => $time_up,                     color => $col->{'up'} },
            { name => 'DOWN',         value => $avail->{'time_down'},        color => $col->{'down'} },
            { name => 'UNREACHABLE',  value => $avail->{'time_unreachable'}, color => $col->{'unreachable'} },
            { name => 'UNDETERMINED', value => $undetermined,                color => $col->{'undetermined'} },
        ],
    };
    my $pie_file = _render_pie_chart($pie);
    return $pie_file;
}

##########################################################
sub _render_pie_chart {
    my($options) = @_;
    my $c = $Thruk::Utils::PDF::c or die("not initialized!");
    my $cc = Chart::Clicker->new('format' => 'pdf', width => 400, height => 450);

    my(@series, @colors, @legend);
    my $total = 0;
    for my $item (@{$options->{'values'}}) {
        $total += $item->{'value'};
    }
    for my $item (@{$options->{'values'}}) {
        if($item->{'value'} > 0) {
            push @series, Chart::Clicker::Data::Series->new(
                name    => $item->{'name'},
                keys    => [ 1..2 ],
                values  => [ $item->{'value'}, 0 ],
            );
            push @colors, $item ->{'color'};
            push @legend, [ sprintf("%06.3f", $item->{'value'}/$total*100).'%' ];
        }
    }
    my $ds = Chart::Clicker::Data::DataSet->new(series => \@series );
    $cc->add_to_datasets($ds);
    $cc->color_allocator->colors(\@colors);

    my $defctx = $cc->get_context('default');
    my $ren = Chart::Clicker::Renderer::Pie->new;
    $ren->border_color(Graphics::Color::RGB->new(red => 1, green => 1, blue => 1));
    $ren->brush->width(2); # border witdh
    $ren->gradient_color(Graphics::Color::RGB->new(red => 1, green => 1, blue => 1, alpha => .2));
    $defctx->renderer($ren);
    $defctx->domain_axis->hidden(1);
    $defctx->range_axis->hidden(1);
    $cc->plot->grid->visible(0);

    $cc->legend(Chart::Clicker::Decoration::Legend::Tabular->new(
        header => [ 'State', '% of Time' ],
        data   => \@legend,
    ));

    my($fh, $filename) = tempfile("chart_pie.pdf.XXXXX", DIR => $c->config->{'tmp_path'});
    $cc->write_output($filename);
    push @{$c->stash->{'tmp_files_to_delete'}}, $filename;
    return $filename;
}

##########################################################
sub _pdf_color {
    my $color = shift;
    my $pdf = $Thruk::Utils::PDF::pdf or die("not initialized!");
    my $colors = {
        'white'      => '1.00 1.00 1.00 rg',
        'black'      => '0.00 0.00 0.00 rg',
        'dark grey'  => '0.35 0.35 0.35 rg',
        'light blue' => '0.33 0.56 0.80 rg',
        'red'        => '1.00 0.00 0.00 rg',
    };
    $color = $colors->{$color} if defined $color;
    $pdf->prAdd($color);
    return 1;
}

##########################################################
sub _get_colors {
    my $colors = {
        'ok'           => Graphics::Color::RGB->new(red => 0,    green => 0.72, blue => 0.18, alpha => 1),
        'warning'      => Graphics::Color::RGB->new(red => 1,    green => 0.87, blue => 0,    alpha => 1),
        'critical'     => Graphics::Color::RGB->new(red => 1,    green => 0.36, blue => 0.20, alpha => 1),
        'unknown'      => Graphics::Color::RGB->new(red => 1,    green => 0.62, blue => 0,    alpha => 1),
        'undetermined' => Graphics::Color::RGB->new(red => 0.36, green => 0.36, blue => 0.36, alpha => 1),
        'up'           => Graphics::Color::RGB->new(red => 0,    green => 0.72, blue => 0.18, alpha => 1),
        'down'         => Graphics::Color::RGB->new(red => 1,    green => 0.36, blue => 0.20, alpha => 1),
        'unreachable'  => Graphics::Color::RGB->new(red => 1,    green => 0.48, blue => 0.35, alpha => 1),
        'placeholder'  => Graphics::Color::RGB->new(red => 0.9,  green => 0.9,  blue => 0.9,  alpha => 1),
    };
    return $colors;
}

##########################################################
# convert date to tick name
sub _date_to_tick_name {
    my $date = shift;
    return '' if $date eq '';
    my $names = {
        '01' => 'Jan',
        '02' => 'Feb',
        '03' => 'Mar',
        '04' => 'Apr',
        '05' => 'May',
        '06' => 'Jun',
        '07' => 'Jul',
        '08' => 'Aug',
        '09' => 'Sep',
        '10' => 'Oct',
        '11' => 'Nov',
        '12' => 'Dec',
    };
    if($date =~ m/^\d{4}\-(\d{2})$/mx) {
        return $names->{$1} if defined $names->{$1};
        return $1;
    }
    elsif($date =~ m/^\d{4}\-KW(\d+)$/mx) {
        return 'KW'.$1;
    }
    elsif($date =~ m/^\d{4}\-(\d{2})\-(\d{2})$/mx) {
        return $names->{$1}." ".$2 if defined $names->{$1};
    } else {
        die("unknown date: $date");
    }
    return $date;
}

##########################################################
sub _reduce_lables {
    my $lables = shift;
    my $size   = scalar @{$lables};
    my $newlables = [];
    if($size > 12) {
        my $show   = int($size / 12) + 1;
        for my $x (0..$size-1) {
            # remove every second except the last one
            if($x%$show == 0) {
                push @{$newlables}, $lables->[$x];
            } else {
                push @{$newlables}, '';
            }
        }
        return $newlables;
    }
    return $lables;
}

##########################################################
sub _replace_css_and_images {
    my $text = shift;
    my $c = $Thruk::Utils::PDF::c or die("not initialized!");
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
    if($url !~ m|^\w+://|mx and $url !~ m|^\#|mx) {
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

    my $c = $Thruk::Utils::PDF::c or die("not initialized!");

    # dynamic images
    if($url =~ m/^\w+\.cgi/mx) {
        if($url =~ m|^\w+\.cgi|gmx) {
            $url = '/thruk/cgi-bin/'.$url;
        }
        my @res = Thruk::Utils::CLI::_request_url($c, $url);
        my $result = $res[1];
        my $text = "data:image/png;base64,".encode_base64($result->{'result'}, '');
        return $a.$b.$text.$d.$e;
    }
    # static images
    elsif($url =~ m/\.(\w+)$/mx) {
        my $data = _read_static_content_file($url);
        my $text = "data:image/$1;base64,".encode_base64($data, '');
        return $a.$b.$text.$d.$e;
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
    my $c = $Thruk::Utils::PDF::c or die("not initialized!");
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
    my $c = $Thruk::Utils::PDF::c or die("not initialized!");
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
        $url =~ s|^plugins/||gmx;
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

=head1 EXAMPLES

See the shipped reports for some examples. Shipped reports are in the
'plugins/plugins-available/reports/templates/pdf' folder.

=head1 AUTHOR

Sven Nierlein, 2012, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
