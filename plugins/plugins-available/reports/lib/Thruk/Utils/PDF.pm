package Thruk::Utils::PDF;

=head1 NAME

Thruk::Utils::PDF - Utilities Collection for creating PDFs

=head1 DESCRIPTION

Utilities Collection for PDFs. All non private subs will be available in PDF templates

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

  render_bar_chart($type)

render a bar chart into tmp file and return filename of the pdf

=cut
sub render_bar_chart {
    my($type) = @_;
    return(_render_svc_bar_chart()) if $type eq 'service';
    return(_render_hst_bar_chart()) if $type eq 'host';
    return;
}

##########################################################

=head2 path_to_template

  path_to_template($filename)

return absolute filename for a template

=cut
sub path_to_template {
    my($filename) = @_;
    my $c = $Thruk::Utils::PDF::c or die("not initialized!");
    # search template paths
    for my $path (@{$c->config->{templates_paths}}, $c->config->{'View::TT'}->{'INCLUDE_PATH'}) {
        if(-e $path.'/'.$filename) {
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

=head2 outages

  outages($logs, $start, $end, $x, $y, $step1, $step2, $max)

print outages from log entries

=cut
sub outages {
    my($logs, $start, $end, $x, $y, $step1, $step2, $max) = @_;

    my $c   = $Thruk::Utils::PDF::c   or die("not initialized!");
    my $pdf = $Thruk::Utils::PDF::pdf or die("not initialized!");

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
    for my $l (reverse @reduced_logs) {
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
    for my $s (@{$states}) {
        $c->stash->{'unavailable_states'}->{$s} = 1;
    }
    return 1;
}

##########################################################
sub _render_bar_chart {
    my($options) = @_;
    my $c = $Thruk::Utils::PDF::c or die("not initialized!");

    my $cc = Chart::Clicker->new('format' => 'pdf', width => 550, height => 400);
    my @months = ();
    my $colors = {};
    for my $name (sort keys %{$options->{'values'}}) {
        push @months, _date_to_tick_name($name);
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
            $perc     = sprintf("%05.2f", $item->{'value'}*100/$total) if $total > 0;
            push @{$percs->{$item->{'name'}}}, $perc;
        }
    }

    my(@series, @colors);
    for my $name ('AVAILABLE', 'NOT AVAILABLE') {
        push @colors, $colors->{$name};
        push @series, Chart::Clicker::Data::Series->new(
            name    => $name,
            keys    => [ 1..12 ],
            values  => $percs->{$name},
        );
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

    my($fh, $filename) = tempfile("chart_pie.pdf.XXXXX", DIR => $c->config->{'tmp_path'});
    $cc->write_output($filename);
    return $filename;
}

##########################################################
sub _render_svc_bar_chart {
    my $c = $Thruk::Utils::PDF::c or die("not initialized!");

    my $col            = _get_colors();
    my $host           = $c->{'request'}->{'parameters'}->{'host'};
    my $service        = $c->{'request'}->{'parameters'}->{'service'};
    confess("No host in parameters:\n".    Dumper($c->{'request'}->{'parameters'})) unless defined $host;
    confess("No services in parameters:\n".Dumper($c->{'request'}->{'parameters'})) unless defined $service;
    my $avail          = $c->stash->{'avail_data'}->{'services'}->{$host}->{$service};
    return unless defined $avail;

    my $bar = { values => {} };
    for my $name (sort keys %{$avail->{'breakdown'}}) {
        my $t = $avail->{'breakdown'}->{$name};
        my($time_avail, $time_unavail) = (0,0);
        for my $s (qw/OK WARNING CRITICAL UNKNOWN UNDETERMINED/) {
            my $time = 0;
            if($s eq 'OK')           { $time += $t->{'time_ok'} + $t->{'scheduled_time_warning'} + $t->{'scheduled_time_critical'} + $t->{'scheduled_time_unknown'} }
            if($s eq 'WARNING')      { $time += $t->{'time_warning'}  - $t->{'scheduled_time_warning'} }
            if($s eq 'CRITICAL')     { $time += $t->{'time_critical'} - $t->{'scheduled_time_critical'} }
            if($s eq 'UNKNOWN')      { $time += $t->{'time_unknown'}  - $t->{'scheduled_time_unknown'} }
            if($s eq 'UNDETERMINED') { $time += $t->{'time_indeterminate_notrunning'} + $t->{'time_indeterminate_nodata'} + $t->{'time_indeterminate_outside_timeperiod'} }

            if(defined $c->stash->{'unavailable_states'}->{$s}) {
                $time_unavail += $time;
            } else {
                $time_avail += $time;
            }
        }

        my $undetermined   = $t->{'time_indeterminate_notrunning'} + $t->{'time_indeterminate_nodata'} + $t->{'time_indeterminate_outside_timeperiod'};
        my $time_ok        = $t->{'time_ok'} + $t->{'scheduled_time_critical'} + $t->{'scheduled_time_unknown'} + $t->{'scheduled_time_warning'}  + $t->{'scheduled_time_ok'};

        $bar->{'values'}->{$name} = {
            name => $name,
            values => [
                { name => 'AVAILABLE',     value => $time_avail,   color => $col->{'ok'} },
                { name => 'NOT AVAILABLE', value => $time_unavail, color => $col->{'critical'} },
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
    return $filename;
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
# convert date to tick name
sub _date_to_tick_name {
    my $date = shift;
    if($date =~ m/^\d{4}\-(\d{2})$/mx) {
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
        return $names->{$1} if defined $names->{$1};
        return $1;
    }
    return $date;
}

##########################################################

1;
