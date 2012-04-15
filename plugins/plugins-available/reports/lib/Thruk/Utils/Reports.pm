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
use Chart::Clicker::Decoration::Legend::Tabular;
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

    $c->stash->{'param'} = $options->{'params'};
    for my $p (keys %{$options->{'params'}}) {
        $c->{'request'}->{'parameters'}->{$p} = $options->{'params'}->{$p};
    }

    if(!defined $options->{'template'} or !_path_to_template($c, 'pdf/'.$options->{'template'})) {
        confess('template pdf/'.$options->{'template'}.' does not exist');
    }

    # set some render helper
    $c->stash->{'path_to_template'}       = \&_path_to_template;
    $c->stash->{'calculate_availability'} = \&_calculate_availability;
    $c->stash->{'render_pie_chart'}       = \&_render_pie_chart;
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
sub _render_pie_chart {
    my($c, $type) = @_;
    return(_render_svc_pie_chart($c)) if $type eq 'service';
    return(_render_hst_pie_chart($c)) if $type eq 'host';
    return;
}

##########################################################
sub _render_svc_pie_chart {
    my($c) = @_;

    my $c_ok           = Graphics::Color::RGB->new(red => 0,    green => 0.72, blue => 0.18, alpha => 1);
    my $c_warning      = Graphics::Color::RGB->new(red => 1,    green => 0.87, blue => 0,    alpha => 1);
    my $c_critical     = Graphics::Color::RGB->new(red => 1,    green => 0.36, blue => 0.20, alpha => 1);
    my $c_unknown      = Graphics::Color::RGB->new(red => 1,    green => 0.62, blue => 0,    alpha => 1);
    my $c_undetermined = Graphics::Color::RGB->new(red => 0.36, green => 0.36, blue => 0.36, alpha => 1);
    my $host           = $c->{'request'}->{'parameters'}->{'host'};
    my $service        = $c->{'request'}->{'parameters'}->{'service'};
    my $avail          = $c->stash->{'avail_data'}->{'services'}->{$host}->{$service};
    return unless defined $avail;
    my $undetermined   = $avail->{'time_indeterminate_notrunning'} + $avail->{'time_indeterminate_nodata'} + $avail->{'time_indeterminate_outside_timeperiod'};
    my $time_ok        = $avail->{'time_ok'} + $avail->{'scheduled_time_critical'} + $avail->{'scheduled_time_unknown'} + $avail->{'scheduled_time_warning'}  + $avail->{'scheduled_time_ok'};
    my $pie = {
        values => [
            { name => 'OK',           value => $time_ok,                  color => $c_ok },
            { name => 'WARNING',      value => $avail->{'time_warning'},  color => $c_warning },
            { name => 'CRITICAL',     value => $avail->{'time_critical'}, color => $c_critical },
            { name => 'UNKNOWN',      value => $avail->{'time_unknown'},  color => $c_unknown },
            { name => 'UNDETERMINED', value => $undetermined,             color => $c_undetermined },
        ],
    };
    my $pie_file = render_pie_chart($c, $pie);
    return $pie_file;
}

##########################################################
sub _render_hst_pie_chart {
    my($c) = @_;

    my $c_up           = Graphics::Color::RGB->new(red => 0,    green => 0.72, blue => 0.18, alpha => 1);
    my $c_down         = Graphics::Color::RGB->new(red => 1,    green => 0.36, blue => 0.20, alpha => 1);
    my $c_unreachable  = Graphics::Color::RGB->new(red => 1,    green => 0.48, blue => 0.35, alpha => 1);
    my $c_undetermined = Graphics::Color::RGB->new(red => 0.36, green => 0.36, blue => 0.36, alpha => 1);
    my $host           = $c->{'request'}->{'parameters'}->{'host'};
    my $avail          = $c->stash->{'avail_data'}->{'hosts'}->{$host};
    return unless defined $avail;
    my $undetermined   = $avail->{'time_indeterminate_notrunning'} + $avail->{'time_indeterminate_nodata'} + $avail->{'time_indeterminate_outside_timeperiod'};
    my $time_up        = $avail->{'time_up'} + $avail->{'scheduled_time_down'} + $avail->{'scheduled_time_unreachable'} + $avail->{'scheduled_time_up'};
    my $pie = {
        values => [
            { name => 'UP',           value => $time_up,                     color => $c_up },
            { name => 'DOWN',         value => $avail->{'time_down'},        color => $c_down },
            { name => 'UNREACHABLE',  value => $avail->{'time_unreachable'}, color => $c_unreachable },
            { name => 'UNDETERMINED', value => $undetermined,                color => $c_undetermined },
        ],
    };
    my $pie_file = render_pie_chart($c, $pie);
    return $pie_file;
}

##########################################################
sub _path_to_template {
    my($c, $filename) = @_;

    # search template paths
    for my $path (reverse @{$c->config->{templates_paths}}, $c->config->{'View::TT'}->{'INCLUDE_PATH'}) {
        if(-e $path.'/'.$filename) {
            return $path.'/'.$filename;
        }
    }
    return;
}

##########################################################
sub _calculate_availability {
    my($c) = @_;
    $c->{'request'}->{'parameters'}->{'show_log_entries'} = 1;
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
    my($c, $pdf, $logs, $start, $end, $classes) = @_;
    my $class = {};
    if(defined $classes) {
        for my $c (@{$classes}) {
            $class->{$c} = 1;
        }
    }

    # combine outages
    my @reduced_logs;
    my($latest, $lastlog);
    for my $l (@{$logs}) {
        if(!defined $latest) {
            $latest = $l;
        }
        if($latest->{'class'} ne $l->{'class'}) {
            $latest->{'real_end'} = $l->{'start'};
            push @reduced_logs, $latest;
            undef $latest;
        }
        $lastlog = $l;
    }
    $latest->{'real_end'} = $lastlog->{'end'};
    push @reduced_logs, $latest;

    # no logs at all?
    return 1 if scalar @reduced_logs == 0;

    my $x = 50;
    my $y = 590;
    for my $l (@reduced_logs) {
        next if $end   < $l->{'start'};
        next if $start > $l->{'real_end'};
        $l->{'start'}    = $start if $start > $l->{'start'} ;
        $l->{'real_end'} = $end   if $end   < $l->{'real_end'} ;
        if(defined $classes and defined $class->{$l->{'class'}}) {
            my $txt = $l->{'class'};
            $txt .= ": ".Thruk::Utils::format_date($l->{'start'}, $c->{'stash'}->{'datetime_format'});
            $txt .= " - ".Thruk::Utils::format_date($l->{'real_end'}, $c->{'stash'}->{'datetime_format'});
            $txt .= " (".Thruk::Utils::Filter::duration($l->{'real_end'}-$l->{'start'}).")";
            $pdf->prText($x,$y, $txt);
            $y = $y - 17;
            $pdf->prText($x,$y, "  -> ".$l->{'plugin_output'});
            $y = $y - 20;
        }
    }
    return 1;
}

##########################################################

1;
