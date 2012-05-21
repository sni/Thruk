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
    for my $s (@{$states}) {
        $c->stash->{'unavailable_states'}->{$s} = 1;
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

    # only the last 12 values can be displayed
    my $z = 0;
    if(@{$Thruk::Utils::PDF::availabilitys->{'values'}} > 12) { $z = @{$Thruk::Utils::PDF::availabilitys->{'values'}} - 12; }
    for(;$z < @{$Thruk::Utils::PDF::availabilitys->{'values'}}; $z++) {
        my $val = $Thruk::Utils::PDF::availabilitys->{'values'}->[$z];
        _pdf_color($c1);
        $pdf->prText($x,$y,    $Thruk::Utils::PDF::availabilitys->{'lables'}->[$z]);
        _pdf_color($c2) if $val < $sla;
        $pdf->prText($x-10,$y-13, $val."%");
        $x = $x+45;
    }

    return 1;
}

##########################################################
sub _render_bar_chart {
    my($options) = @_;
    my $c = $Thruk::Utils::PDF::c or die("not initialized!");

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
    for my $name ('AVAILABLE', 'NOT AVAILABLE') {
        push @colors, $colors->{$name};
        push @series, Chart::Clicker::Data::Series->new(
            name    => $name,
            keys    => [ 1..$number_of_bars ],
            values  => $percs->{$name},
        );
    }
    $available->{'values'} = $percs->{'AVAILABLE'};
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
    if(defined $service) {
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
            $time->{'undetermined'} += $t->{'time_indeterminate_notrunning'};
            $time->{'undetermined'} += $t->{'time_indeterminate_nodata'};
            $time->{'undetermined'} += $t->{'time_indeterminate_outside_timeperiod'};
        }

        $bar->{'values'}->{$name} = {
            name => $name,
            values => [
                { name => 'AVAILABLE',     value => $time->{'available'},   color => $col->{'ok'} },
                { name => 'NOT AVAILABLE', value => $time->{'unavailable'}, color => $col->{'critical'} },
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
    };
    return $colors;
}

##########################################################
# convert date to tick name
sub _date_to_tick_name {
    my $date = shift;
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

1;
