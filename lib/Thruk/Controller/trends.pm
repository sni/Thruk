package Thruk::Controller::trends;

use strict;
use warnings;
use GD;
use POSIX qw(strftime);
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::trends - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

use constant {
    MIN_TIMESTAMP_SPACING => 10,
};

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    # set defaults
    $c->stash->{title}            = 'Trends';
    $c->stash->{infoBoxTitle}     = 'Host and Service State Trends';
    $c->stash->{page}             = 'trends';
    $c->stash->{'no_auto_reload'} = 1;

    if(exists $c->{'request'}->{'parameters'}->{'createimage'}) {
        $c->stash->{gd_image} = $self->_create_image($c);
        $c->forward('Thruk::View::GD');
    } else {
        $c->stash->{'template'} = 'trends_step_1.tt';
    }

    return 1;
}

##########################################################
sub _create_image {
    my ( $self, $c ) = @_;

    my $smallimage = 0;
    $smallimage = 1 if exists $c->{'request'}->{'parameters'}->{'smallimage'};
    my $service = 0;
    $service = 1 if exists $c->{'request'}->{'parameters'}->{'service'};

    my $host_drawing_width          = 498;
    my $host_drawing_height         = 70;
    my $host_drawing_x_offset       = 116;
    my $host_drawing_y_offset       = 55;

    my $svc_drawing_width           = 498;
    my $svc_drawing_height          = 90;
    my $svc_drawing_x_offset        = 116;
    my $svc_drawing_y_offset        = 55;

    my $small_host_drawing_width    = 500;
    my $small_host_drawing_height   = 20;
    my $small_host_drawing_x_offset = 0;
    my $small_host_drawing_y_offset = 0;

    my $small_svc_drawing_width     = 500;
    my $small_svc_drawing_height    = 20;
    my $small_svc_drawing_x_offset  = 0;
    my $small_svc_drawing_y_offset  = 0;

    # calculate availability data
    $c->{'request'}->{'parameters'}->{'full_log_entries'} = 1;
    Thruk::Utils::calculate_availability($c);

    my($im, $width, $height,$drawing_width,$drawing_height,$drawing_x_offset,$drawing_y_offset);
    if($smallimage) {
        $im = GD::Image->new(500, 20);
        if($service) {
            $drawing_width      = $small_svc_drawing_width;
            $drawing_height     = $small_svc_drawing_height;
            $drawing_x_offset   = $small_svc_drawing_x_offset;
            $drawing_y_offset   = $small_svc_drawing_y_offset;
        }
        else {
            $drawing_width      = $small_host_drawing_width;
            $drawing_height     = $small_host_drawing_height;
            $drawing_x_offset   = $small_host_drawing_x_offset;
            $drawing_y_offset   = $small_host_drawing_y_offset;
        }
    } else {
        if($service) {
            $im = GD::Image->newFromPng($c->config->{'image_path'}."/trendssvc.png");
            $drawing_width      = $svc_drawing_width;
            $drawing_height     = $svc_drawing_height;
            $drawing_x_offset   = $svc_drawing_x_offset;
            $drawing_y_offset   = $svc_drawing_y_offset;
        }
        else {
            $im = GD::Image->newFromPng($c->config->{'image_path'}."/trendshost.png");
            $drawing_width      = $host_drawing_width;
            $drawing_height     = $host_drawing_height;
            $drawing_x_offset   = $host_drawing_x_offset;
            $drawing_y_offset   = $host_drawing_y_offset;
        }
    }

    # allocate colors used for drawing
    $self->{'colors'} = {
        'white'     => $im->colorAllocate(255,255,255),
        'black'     => $im->colorAllocate(0,0,0),
        'red'       => $im->colorAllocate(255,0,0),
        'darkred'   => $im->colorAllocate(128,0,0),
        'green'     => $im->colorAllocate(0,210,0),
        'darkgreen' => $im->colorAllocate(0,128,0),
        'yellow'    => $im->colorAllocate(176,178,20),
        'orange'    => $im->colorAllocate(255,100,25),
    };

    # set transparency index
    $im->transparent($self->{'colors'}->{'white'});

    # make sure the graphic is interlaced
    $im->interlaced('true');

    # draw service / host states
    $self->_draw_states($c, $im, $self->{'colors'}, $c->stash->{'logs'}, $c->stash->{'start'}, $c->stash->{'end'}, $smallimage, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset);

    # draw timestamps and dashed vertical lines
    $self->_draw_timestamps($c, $im, $self->{'colors'}->{'black'}, $c->stash->{'logs'}, $c->stash->{'start'}, $c->stash->{'end'}, $smallimage, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset);

    unless($smallimage) {
        # draw horizontal grid lines
        $self->_draw_horizontal_grid_lines($c, $im, $self->{'colors'}->{'black'}, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset, $c->{'request'}->{'parameters'}->{'service'});

        # draw total times / percentages
        $self->_draw_time_breakdowns($c, $im, $self->{'colors'}, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset, $c->{'request'}->{'parameters'}->{'host'}, $c->{'request'}->{'parameters'}->{'service'} );

        # draw text
        $self->_draw_text($c, $im, $self->{'colors'}->{'black'}, $c->stash->{'start'}, $c->stash->{'end'}, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset, $c->{'request'}->{'parameters'}->{'host'}, $c->{'request'}->{'parameters'}->{'service'});
    }

    # draw a border
    $im->rectangle(0,0,$im->width-1,$im->height-1,$self->{'colors'}->{'black'});

    return $im;
}

##########################################################
sub _draw_timestamps {
    my ( $self, $c, $im, $color, $logs, $start, $end, $smallimage, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset) = @_;

    my $report_duration = $end - $start;

    $self->_draw_timestamp($c, $im, $color, 0, $start, $smallimage, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset);

    my $last_timestamp = 0;

    for my $log ( @{$logs} ) {
        # inside report period?
        next unless $log->{'end'} > $start;
        next unless $log->{'end'} < $end;

        my $x = int(($log->{'end'} - $start) / $report_duration * $drawing_width);

        # draw start timestamp if possible
        if(( $x > $last_timestamp + MIN_TIMESTAMP_SPACING ) and ( $x < $drawing_width - 1 - MIN_TIMESTAMP_SPACING )){
            $self->_draw_timestamp($c, $im, $color, $x, $log->{'end'}, $smallimage, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset);
            $last_timestamp = $x;
        }
    }

    $self->_draw_timestamp($c, $im, $color, $drawing_width, $end, $smallimage, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset);

    return 1;
}

##########################################################
sub _draw_timestamp {
    my ( $self, $c, $im, $color, $x, $timestamp, $smallimage, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset) = @_;

    my($font_width,$font_height) = (gdSmallFont->width,gdSmallFont->height);

    my $string       = strftime($c->config->{'datetime_format_trends'}, localtime($timestamp));
    my $string_width = $font_width * length($string);

    unless($smallimage) {
        $im->stringUp(gdSmallFont, $x+$drawing_x_offset-($font_height/2), $drawing_y_offset+$drawing_height+$string_width+5, $string, $color);
    }

    # draw a dashed vertical line at this point
    if($x > 0 and $x < ($drawing_width-1)) {
        $self->_draw_dashed_line($im, $x+$drawing_x_offset, $drawing_y_offset, $x+$drawing_x_offset, $drawing_y_offset+$drawing_height, $color);
    }

    return 1;
}

##########################################################
sub _draw_dashed_line {
    my($self, $im, $x1, $y1, $x2, $y2, $color) = @_;

    my $style = [ $color, $color, gdTransparent, gdTransparent, $color, $color, gdTransparent, gdTransparent, $color, $color, gdTransparent, gdTransparent ];

    # sets current style to a dashed line
    $im->setStyle(@{$style});

    # draws a line (dashed)
    $im->line($x1,$y1,$x2,$y2,gdStyled);

    return 1;
}


##########################################################
sub _draw_states {
    my ( $self, $c, $im, $colors, $logs, $start, $end, $smallimage, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset) = @_;

    my $report_duration = $end - $start;

    my($last_color,$last_hight);
    for my $log ( @{$logs} ) {
        next unless defined $log->{'class'};

        # host/service state?
        my($color,$height);
        if(   $log->{'class'} eq 'UP')            { $color = $colors->{'green'};    $height = 60;          }
        elsif($log->{'class'} eq 'DOWN')          { $color = $colors->{'red'};      $height = 40;          }
        elsif($log->{'class'} eq 'UNREACHABLE')   { $color = $colors->{'darkred'};  $height = 20;          }
        elsif($log->{'class'} eq 'OK')            { $color = $colors->{'green'};    $height = 80;          }
        elsif($log->{'class'} eq 'WARNING')       { $color = $colors->{'yellow'};   $height = 60;          }
        elsif($log->{'class'} eq 'UNKNOWN')       { $color = $colors->{'orange'};   $height = 40;          }
        elsif($log->{'class'} eq 'CRITICAL')      { $color = $colors->{'red'};      $height = 20;          }
        elsif($log->{'class'} eq 'INDETERMINATE') { $color = $last_color;           $height = $last_hight; }

        next unless defined $color;
        $last_color = $color;
        $last_hight = $height;

        # inside report period?
        next if $log->{'end'}   <= $start;
        next if $log->{'start'} > $end;

        # small image is fully painted
        if($smallimage) { $height = $drawing_height; }

        my $x1 = $drawing_x_offset + int(($log->{'start'} - $start) / $report_duration * $drawing_width);
        my $y1 = $drawing_y_offset + $drawing_height - $height;

        my $x2 = $drawing_x_offset + int(($log->{'end'} - $start) / $report_duration * $drawing_width);
        my $y2 = $drawing_y_offset + $drawing_height;

        $im->filledRectangle($x1,$y1,$x2,$y2,$color);
    }

    return 1;
}


##########################################################
sub _draw_text {
    my ($self, $c, $im, $color, $start, $end, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset, $host, $service ) = @_;

    my($font_width,$font_height) = (gdSmallFont->width,gdSmallFont->height);

    # print out the title
    my $title;
    if(defined $service) {
        $title = "State History For Service '".$service."' On Host '".$host."'";
    }
    else {
        $title = "State History For Host '".$host."'";
    }
    my $string_width  = length($title) * $font_width;
    $im->string(gdSmallFont,($drawing_width/2)-($string_width/2)+$drawing_x_offset,$font_height, $title, $color);

    # report start/end date
    my $from_to = strftime($c->config->{'datetime_format_trends'}, localtime($start))." to ".strftime($c->config->{'datetime_format_trends'}, localtime($end));
    $string_width  = length($from_to) * $font_width;
    $im->string(gdSmallFont,($drawing_width/2)-($string_width/2)+$drawing_x_offset,($font_height*2)+5,$from_to,$color);

    return 1;
}

##########################################################
sub _draw_horizontal_grid_lines {
    my ($self, $c, $im, $color, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset, $service ) = @_;

    $self->_draw_dashed_line($im, $drawing_x_offset,$drawing_y_offset+10,$drawing_x_offset+$drawing_width,$drawing_y_offset+10,$color);
    $self->_draw_dashed_line($im, $drawing_x_offset,$drawing_y_offset+30,$drawing_x_offset+$drawing_width,$drawing_y_offset+30,$color);
    $self->_draw_dashed_line($im, $drawing_x_offset,$drawing_y_offset+50,$drawing_x_offset+$drawing_width,$drawing_y_offset+50,$color);
    if(defined $service) {
        $self->_draw_dashed_line($im, $drawing_x_offset,$drawing_y_offset+70,$drawing_x_offset+$drawing_width,$drawing_y_offset+70,$color);
    }

    return 1;
}

##########################################################
sub _draw_time_breakdowns {
    my ($self, $c, $im, $colors, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset, $host, $service ) = @_;

    my($font_width,$font_height) = (gdSmallFont->width,gdSmallFont->height);

    my $string;
    if(defined $service){

        my $avail_data = $c->stash->{'avail_data'}->{'services'}->{$host}->{$service};
        my $total_time =
              $avail_data->{'time_ok'}
            + $avail_data->{'time_warning'}
            + $avail_data->{'time_unknown'}
            + $avail_data->{'time_critical'}
            + $avail_data->{'time_indeterminate_nodata'}
            + $avail_data->{'time_indeterminate_notrunning'};

        $string = $self->_get_time_breakdown_string($total_time,$avail_data->{'time_ok'},"Ok");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+5,$string,$colors->{'darkgreen'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*2),$drawing_y_offset+5,"Ok",$colors->{'darkgreen'});

        $string = $self->_get_time_breakdown_string($total_time,$avail_data->{'time_warning'},"Warning");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+25,$string,$colors->{'yellow'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*7),$drawing_y_offset+25,"Warning",$colors->{'yellow'});

        $string = $self->_get_time_breakdown_string($total_time,$avail_data->{'time_unknown'},"Unknown");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+45,$string,$colors->{'orange'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*7),$drawing_y_offset+45,"Unknown",$colors->{'orange'});

        $string = $self->_get_time_breakdown_string($total_time,$avail_data->{'time_critical'},"Critical");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+65,$string,$colors->{'red'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*8),$drawing_y_offset+65,"Critical",$colors->{'red'});

        $string = $self->_get_time_breakdown_string($total_time,$avail_data->{'time_indeterminate_nodata'}+$avail_data->{'time_indeterminate_notrunning'},"Indeterminate");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+85,$string,$colors->{'black'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*13),$drawing_y_offset+85,"Indeterminate",$colors->{'black'});

    }
    else{

        my $avail_data = $c->stash->{'avail_data'}->{'hosts'}->{$host};
        my $total_time =
              $avail_data->{'time_up'}
            + $avail_data->{'time_down'}
            + $avail_data->{'time_unreachable'}
            + $avail_data->{'time_indeterminate_nodata'}
            + $avail_data->{'time_indeterminate_notrunning'};

        $string = $self->_get_time_breakdown_string($total_time,$avail_data->{'time_up'},"Up");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+5,$string,$colors->{'darkgreen'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*2),$drawing_y_offset+5,"Up",$colors->{'darkgreen'});

        $string = $self->_get_time_breakdown_string($total_time,$avail_data->{'time_down'},"Down");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+25,$string,$colors->{'red'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*4),$drawing_y_offset+25,"Down",$colors->{'red'});

        $string = $self->_get_time_breakdown_string($total_time,$avail_data->{'time_unreachable'},"Unreachable");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+45,$string,$colors->{'darkred'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*11),$drawing_y_offset+45,"Unreachable",$colors->{'darkred'});

        $string = $self->_get_time_breakdown_string($total_time,$avail_data->{'time_indeterminate_nodata'}+$avail_data->{'time_indeterminate_notrunning'},"Indeterminate");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+65,$string,$colors->{'black'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*13),$drawing_y_offset+65,"Indeterminate",$colors->{'black'});
    }

    return 1;
}

##########################################################
sub _get_time_breakdown_string {
    my($self,$total_time,$time, $type) = @_;

    my $duration     = Thruk::Utils::filter_duration($time);
    my $percent_time = ($time/$total_time)*100;
    return sprintf("%-13s: (%.3f%%) %s",$type,$percent_time,$duration);
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
