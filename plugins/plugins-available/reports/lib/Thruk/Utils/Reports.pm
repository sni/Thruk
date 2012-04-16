package Thruk::Utils::Reports;

=head1 NAME

Thruk::Utils::Reports - Utilities Collection for Reporting

=head1 DESCRIPTION

Utilities Collection for Reporting

=cut

use warnings;
use strict;
use Carp;
use Data::Dumper;
use File::Temp qw/tempfile/;
use Chart::Clicker;
use Chart::Clicker::Data::DataSet;
use Chart::Clicker::Data::Series;
use Chart::Clicker::Renderer::Pie;
use Chart::Clicker::Renderer::StackedBar;
use Chart::Clicker::Decoration::Legend::Tabular;
use Chart::Clicker::Data::Marker;
use Chart::Clicker::Data::Range;
use Graphics::Color::RGB;
use File::Slurp;

##########################################################

=head1 METHODS

=head2 show_report

  show_report($c, $nr)

show a report

=cut
sub show_report {
    my($c, $nr, $options) = @_;

    my $report = _read_report_file($c, $nr);

    if(!defined $report) {
        Thruk::Utils::set_message( $c, 'fail_message', 'no such report' );
        return $c->response->redirect('reports.cgi');
    }

    my $pdf_file                = generate_report($c, $nr, $report);
    $c->stash->{'pdf_template'} = 'passthrough_pdf.tt';
    $c->stash->{'pdf_file'}     = $pdf_file;
    $c->stash->{'pdf_filename'} = 'report.pdf'; # downloaded filename
    $c->forward('View::PDF::Reuse');
    return;
}

##########################################################

=head2 generate_report

  generate_report($nr, $options)

generate a new report

=cut
sub generate_report {
    my($c, $nr, $options) = @_;
    $options = _read_report_file($c, $nr) unless defined $options;

    # set some defaults
    _set_unavailable_states($c, [qw/DOWN UNREACHABLE CRITICAL UNKNOWN/]);
    $c->{'request'}->{'parameters'}->{'show_log_entries'}           = 1;
    $c->{'request'}->{'parameters'}->{'assumeinitialstates'}        = 'yes';
    $c->{'request'}->{'parameters'}->{'initialassumedhoststate'}    = 3; # UP
    $c->{'request'}->{'parameters'}->{'initialassumedservicestate'} = 6; # OK

    $c->stash->{'param'} = $options->{'params'};
    for my $p (keys %{$options->{'params'}}) {
        $c->{'request'}->{'parameters'}->{$p} = $options->{'params'}->{$p};
    }

    if(!defined $options->{'template'} or !_path_to_template($c, 'pdf/'.$options->{'template'})) {
        confess('template pdf/'.$options->{'template'}.' does not exist');
    }

    # set some render helper
    $c->stash->{'path_to_template'}       = \&_path_to_template;
    $c->stash->{'set_unavailable_states'} = \&_set_unavailable_states;
    $c->stash->{'calculate_availability'} = \&_calculate_availability;
    $c->stash->{'render_pie_chart'}       = \&_render_pie_chart;
    $c->stash->{'render_bar_chart'}       = \&_render_bar_chart;
    $c->stash->{'font'}                   = \&_font;
    $c->stash->{'outages'}                = \&_outages;

    # prepare pdf
    $c->stash->{'pdf_template'} = 'pdf/'.$options->{'template'};
    $c->stash->{'block'} = 'prepare';
    $c->view("PDF::Reuse")->render_pdf($c);

    # render pdf
    $c->stash->{'block'} = 'render';
    my $pdf_data = $c->view("PDF::Reuse")->render_pdf($c);

    # write out pdf
    mkdir($c->config->{'tmp_path'}.'/reports');
    my $pdf_file = $c->config->{'tmp_path'}.'/reports/'.$nr.'.pdf';
    open(my $fh, '>', $pdf_file);
    binmode $fh;
    print $fh $pdf_data;
    close($fh);

    return $pdf_file;
}

##########################################################

=head2 render_pie_chart

  render_pie_chart($c, $options)

render a pie chart and return filename of the pdf

=cut
sub render_pie_chart {
    my($c, $options) = @_;
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
    return $filename;
}

##########################################################

=head2 render_bar_chart

  render_bar_chart($c, $options)

render a bar chart and return filename of the pdf

=cut
sub render_bar_chart {
    my($c, $options) = @_;
    my $cc = Chart::Clicker->new('format' => 'pdf', width => 550, height => 400);
    my(@series, @colors);
    my $total = 0;
    for my $item (@{$options->{'values'}}) {
        $total += $item->{'value'};
    }
    my @months = qw/Apr May Jun Jul Aug Sep Oct Nov Dec Jan Feb Mar/;
    my $percs = {};
    for my $m (@months) { $percs->{$m} = 0 }
    for my $item (@{$options->{'values'}}) {
        my $perc = sprintf("%05.2f", $item->{'value'}*100/$total);
        push @colors, $item ->{'color'};
        push @series, Chart::Clicker::Data::Series->new(
            name    => $item->{'name'},
            keys    => [ 1..12 ],
            values  => [ 0, 0, 0, 0, 0, 0, 0 ,0 ,0, 0, 0, $perc ],
        );
        $percs->{'Mar'} = $perc if $item->{'name'} eq 'AVAILABLE';
    }
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
    $def->domain_axis->tick_values([1..12]);
    $def->domain_axis->tick_labels(\@months);
    $def->domain_axis->format('%d');

    $def->domain_axis->fudge_amount(0.05); # adds border at the top
    $def->range_axis->fudge_amount(0.01);

    # add red line for sla
    $def->add_marker(
        Chart::Clicker::Data::Marker->new(
                            value => $c->stash->{'param'}->{'sla'},
                            color => Graphics::Color::RGB->new(red => 1, green => 0, blue => 0),
        )
    );

    #$cc->title->text($c->stash->{'param'}->{'host'}.' - '.$c->stash->{'param'}->{'service'});

    my($fh, $filename) = tempfile("chart_pie.pdf.XXXXX", DIR => $c->config->{'tmp_path'});
    $cc->write_output($filename);
    return $filename;
}

##########################################################
sub _read_report_file {
    my($c, $nr) = @_;
    return unless $nr =~ m/^\d+$/mx;
    my $file = $c->config->{'var_path'}.'/reports/'.$nr.'.txt';
    return unless -f $file;
    my $data = read_file($file);
    my $VAR1;
    ## no critic
    eval($data);
    ## use critic
    return $VAR1;
}

##########################################################
sub _render_bar_chart {
    my($c, $type) = @_;
    return(_render_svc_bar_chart($c)) if $type eq 'service';
    return(_render_hst_bar_chart($c)) if $type eq 'host';
    return;
}

##########################################################
sub _render_svc_bar_chart {
    my($c) = @_;

    my $col            = _get_colors();
    my $host           = $c->{'request'}->{'parameters'}->{'host'};
    my $service        = $c->{'request'}->{'parameters'}->{'service'};
    my $avail          = $c->stash->{'avail_data'}->{'services'}->{$host}->{$service};
    return unless defined $avail;

    my($time_avail, $time_unavail) = (0,0);
    for my $s (qw/OK WARNING CRITICAL UNKNOWN UNDETERMINED/) {
        my $time = 0;
        if($s eq 'OK')           { $time += $avail->{'time_ok'} + $avail->{'scheduled_time_warning'} + $avail->{'scheduled_time_critical'} + $avail->{'scheduled_time_unknown'} }
        if($s eq 'WARNING')      { $time += $avail->{'time_warning'}  - $avail->{'scheduled_time_warning'} }
        if($s eq 'CRITICAL')     { $time += $avail->{'time_critical'} - $avail->{'scheduled_time_critical'} }
        if($s eq 'UNKNOWN')      { $time += $avail->{'time_unknown'}  - $avail->{'scheduled_time_unknown'} }
        if($s eq 'UNDETERMINED') { $time += $avail->{'time_indeterminate_notrunning'} + $avail->{'time_indeterminate_nodata'} + $avail->{'time_indeterminate_outside_timeperiod'} }

        if(defined $c->stash->{'unavailable_states'}->{$s}) {
            $time_unavail += $time;
        } else {
            $time_avail += $time;
        }
    }

    my $undetermined   = $avail->{'time_indeterminate_notrunning'} + $avail->{'time_indeterminate_nodata'} + $avail->{'time_indeterminate_outside_timeperiod'};
    my $time_ok        = $avail->{'time_ok'} + $avail->{'scheduled_time_critical'} + $avail->{'scheduled_time_unknown'} + $avail->{'scheduled_time_warning'}  + $avail->{'scheduled_time_ok'};
    my $bar = {
        values => [
            { name => 'AVAILABLE',     value => $time_avail,   color => $col->{'ok'} },
            { name => 'NOT AVAILABLE', value => $time_unavail, color => $col->{'critical'} },
        ],
    };
    my $bar_file = render_bar_chart($c, $bar);
    return $bar_file;
}

##########################################################
sub _render_pie_chart {
    my($c, $type) = @_;
    return(_render_svc_pie_chart($c)) if $type eq 'service';
    return(_render_hst_pie_chart($c)) if $type eq 'host';
    return;
}

##########################################################
sub _render_svc_pie_chart {
    my($c) = @_;

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
    my $pie_file = render_pie_chart($c, $pie);
    return $pie_file;
}

##########################################################
sub _render_hst_pie_chart {
    my($c) = @_;

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
    my $pie_file = render_pie_chart($c, $pie);
    return $pie_file;
}

##########################################################
sub _path_to_template {
    my($c, $filename) = @_;

    # search template paths
    for my $path (@{$c->config->{templates_paths}}, $c->config->{'View::TT'}->{'INCLUDE_PATH'}) {
        if(-e $path.'/'.$filename) {
            return $path.'/'.$filename;
        }
    }
    return;
}

##########################################################
sub _calculate_availability {
    my($c) = @_;
    Thruk::Utils::Avail::calculate_availability($c);
    return 1;
}

##########################################################
sub _font {
    my($pdf, $size, $color) = @_;
    my $colors = {
        'white'      => '1.00 1.00 1.00 rg',
        'black'      => '0.00 0.00 0.00 rg',
        'dark grey'  => '0.35 0.35 0.35 rg',
        'light blue' => '0.33 0.56 0.80 rg',
    };
    $color = $colors->{$color} if defined $color;
    $pdf->prFontSize($size);
    $pdf->prAdd($color);
    return 1;
}

##########################################################
sub _outages {
    my($c, $pdf, $logs, $start, $end, $x, $y, $step1, $step2) = @_;

    # combine outages
    my @reduced_logs;
    my($combined, $last);
    for my $l (@{$logs}) {
        if(!defined $combined) {
            $combined = $l;
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
    my $found = 0;
    for my $l (@reduced_logs) {
        next if $end   < $l->{'start'};
        next if $start > $l->{'real_end'};
        $l->{'start'}    = $start if $start > $l->{'start'} ;
        $l->{'real_end'} = $end   if $end   < $l->{'real_end'} ;
        if(defined $c->stash->{'unavailable_states'}->{$l->{'class'}}) {
            $found++;
            my $txt = ''; # $l->{'class'}.': ';
            $txt .= Thruk::Utils::format_date($l->{'start'}, $c->{'stash'}->{'datetime_format'});
            $txt .= " - ".Thruk::Utils::format_date($l->{'real_end'}, $c->{'stash'}->{'datetime_format'});
            $txt .= " (".Thruk::Utils::Filter::duration($l->{'real_end'}-$l->{'start'}).")";
            $pdf->prText($x,$y, $txt);
            $y = $y - $step1;
            $pdf->prText($x,$y, '  -> '.$l->{'plugin_output'});
            $y = $y - $step2;
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
    };
    return $colors;
}

##########################################################
sub _set_unavailable_states {
    my($c, $states) = @_;
    $c->stash->{'unavailable_states'} = {};
    for my $s (@{$states}) {
        $c->stash->{'unavailable_states'}->{$s} = 1;
    }
    return 1;
}
##########################################################

1;
