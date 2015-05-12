package Thruk::Utils::Trends;

use strict;
use warnings;
use GD;
use POSIX qw(strftime);
use Thruk::Utils::Avail;

=head1 NAME

Thruk::Utils::Trends - Utils for graphing trends

=head1 DESCRIPTION

Utils for trends page

=cut

use constant {
    MIN_TIMESTAMP_SPACING => 10,

    IMAGE_MAP_MODE        => 1,
    IMAGE_MODE            => 2,
};

=head1 METHODS

=head2 new

create new trends helper

=cut

##########################################################
sub new {
    my( $class ) = @_;
    my $self     = {};
    bless $self, $class;
    return $self;
}

##########################################################
sub _show_step_2 {
    my ( $self, $c ) = @_;

    my $input = $c->req->parameters->{'input'};

    return unless defined $input;

    my $data;
    if($input eq 'gethost') {
        $data = $c->{'db'}->get_host_names(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts') ]);
    }
    elsif($input eq 'getservice') {
        my $services = $c->{'db'}->get_services(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'services')], columns => [qw/host_name description/]);
        for my $service (@{$services}) {
            $data->{$service->{'host_name'}.";".$service->{'description'}} = 1;
        }
        my @sorted = sort keys %{$data};
        $data = \@sorted;
    }
    else {
        return;
    }

    $c->stash->{input}       = $input;
    $c->stash->{data}       = $data;
    $c->stash->{template}   = 'trends_step_2.tt';

    return 1;
}


##########################################################
sub _show_step_3 {
    my ( $self, $c ) = @_;

    my $input = $c->req->parameters->{'input'};

    return unless defined $input;
    return unless $input eq 'getoptions';

    my $host    = $c->req->parameters->{'host'};
    my $service = $c->req->parameters->{'service'};

    if(!defined $host and !defined $service) {
        return;
    }

    if(defined $service and CORE::index($service, ';') > 0) {
        ($host,$service) = split/;/mx, $service;
    }

    $c->stash->{host}        = $host    || '';
    $c->stash->{service}     = $service || '';
    $c->stash->{timeperiods} = $c->{'db'}->get_timeperiods(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'timeperiods')], remove_duplicates => 1);

    $c->stash->{template}   = 'trends_step_3.tt';

    return 1;
}


##########################################################
sub _show_report {
    my ( $self, $c ) = @_;

    my $host       = $c->req->parameters->{'host'}       || '';
    my $service    = $c->req->parameters->{'service'}    || '';

    $c->stash->{host}    = $host;
    $c->stash->{service} = $service;

    return unless $host or $service;

    return Thruk::Utils::External::perl($c, { expr => 'Thruk::Utils::Trends::_do_report($c)', message => 'please stand by while your report is being generated...' });
}


##########################################################
sub _do_report {
    my ( $c ) = @_;

    my $start_time = time();

    # calculate availability data
    $c->req->parameters->{'full_log_entries'} = 1;
    Thruk::Utils::Avail::calculate_availability($c);

    # create the image map
    my $image_map = Thruk::Utils::Trends::_create_image($c, IMAGE_MAP_MODE);

    if(defined $c->stash->{job_id}) {
        # store resulting image in file, forked reports cannot handle detaches
        my $gd_image = Thruk::Utils::Trends::_create_image($c, IMAGE_MODE);
        my $dir = $c->config->{'var_path'}."/jobs/".$c->stash->{job_id};
        open(my $fh, '>', $dir."/graph.png");
        binmode($fh);
        print $fh $gd_image->png;
        Thruk::Utils::IO::close($fh, $dir."/graph.png");
    }

    unless(exists $c->req->parameters->{'nomap'}) {
        $c->stash->{image_map} = $image_map;
        $c->stash->{nomap}     = $c->req->parameters->{'nomap'};
    }
    $c->stash->{nomap}     = '' unless defined $c->stash->{nomap};
    $c->stash->{image_map} = '' unless defined $c->stash->{image_map};

    # finished
    $c->stash->{time_token} = time() - $start_time;

    $c->stash->{image_width}  = '900';
    $c->stash->{image_height} = '300';
    if($c->stash->{service} ne '') {
        $c->stash->{image_height} = '320';
    }

    $c->stash->{template}   = 'trends_report.tt';

    return 1;
}


##########################################################
sub _create_image {
    my ( $c, $mode ) = @_;

    my $smallimage = 0;
    $smallimage = 1 if exists $c->req->parameters->{'smallimage'};
    my $service = 0;
    $service = 1 if exists $c->req->parameters->{'service'};

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

    unless(defined $c->stash->{'logs'}) {
        $c->req->parameters->{'full_log_entries'} = 1;
        Thruk::Utils::Avail::calculate_availability($c);
    }

    my($im, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset);
    if($smallimage) {
        unless($mode == IMAGE_MAP_MODE) {
            $im = GD::Image->new(500, 20);
        }
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
            unless($mode == IMAGE_MAP_MODE) {
                $im = GD::Image->newFromPng($c->config->{'image_path'}."/trendssvc.png");
            }
            $drawing_width      = $svc_drawing_width;
            $drawing_height     = $svc_drawing_height;
            $drawing_x_offset   = $svc_drawing_x_offset;
            $drawing_y_offset   = $svc_drawing_y_offset;
        }
        else {
            unless($mode == IMAGE_MAP_MODE) {
                $im = GD::Image->newFromPng($c->config->{'image_path'}."/trendshost.png");
            }
            $drawing_width      = $host_drawing_width;
            $drawing_height     = $host_drawing_height;
            $drawing_x_offset   = $host_drawing_x_offset;
            $drawing_y_offset   = $host_drawing_y_offset;
        }
    }

    # allocate colors used for drawing
    my $colors;
    unless($mode == IMAGE_MAP_MODE) {
        $colors = {
            'white'     => $im->colorAllocate(255,255,255),
            'black'     => $im->colorAllocate(0,0,0),
            'red'       => $im->colorAllocate(255,0,0),
            'darkred'   => $im->colorAllocate(128,0,0),
            'green'     => $im->colorAllocate(0,210,0),
            'darkgreen' => $im->colorAllocate(0,128,0),
            'yellow'    => $im->colorAllocate(176,178,20),
            'orange'    => $im->colorAllocate(255,100,25),

            'red_t'       => $im->colorAllocateAlpha(255,0,0,115),
            'darkred_t'   => $im->colorAllocateAlpha(128,0,0,115),
            'green_t'     => $im->colorAllocateAlpha(0,210,0,115),
            'darkgreen_t' => $im->colorAllocateAlpha(0,128,0,115),
            'yellow_t'    => $im->colorAllocateAlpha(176,178,20,115),
            'orange_t'    => $im->colorAllocateAlpha(255,100,25,115),
        };

        # set transparency index
        $im->transparent($colors->{'white'});

        # make sure the graphic is interlaced
        # 2014-06-16: interlaced png are broken on centos 7, resulting in
        # libpng warning: Interlace handling should be turned on when using png_read_image
        #$im->interlaced('true');
    }

    # draw service / host states
    my $image_map = _draw_states($c, $im, $mode, $colors, $c->stash->{'logs'}, $c->stash->{'start'}, $c->stash->{'end'}, $smallimage, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset, $c->stash->{'zoom'});

    if($mode == IMAGE_MAP_MODE) {
        return $image_map;
    }
    else {
        # draw timestamps and dashed vertical lines
        _draw_timestamps($c, $im, $colors->{'black'}, $c->stash->{'logs'}, $c->stash->{'start'}, $c->stash->{'end'}, $smallimage, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset);

        unless($smallimage) {
            # draw horizontal grid lines
            _draw_horizontal_grid_lines($im, $colors->{'black'}, $drawing_width, $drawing_x_offset, $drawing_y_offset, $c->req->parameters->{'service'});

            # draw total times / percentages
            _draw_time_breakdowns($c, $im, $colors, $drawing_width, $drawing_x_offset, $drawing_y_offset, $c->req->parameters->{'host'}, $c->req->parameters->{'service'} );

            # draw text
            _draw_text($c, $im, $colors->{'black'}, $c->stash->{'start'}, $c->stash->{'end'}, $drawing_width, $drawing_x_offset, $c->req->parameters->{'host'}, $c->req->parameters->{'service'});
        }

        # draw a border
        $im->rectangle(0,0,$im->width-1,$im->height-1,$colors->{'black'});

        return $im;
    }
}

##########################################################
sub _draw_timestamps {
    my ( $c, $im, $color, $logs, $start, $end, $smallimage, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset) = @_;

    my $report_duration = $end - $start;

    _draw_timestamp($c, $im, $color, 0, $start, $smallimage, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset);

    my $last_timestamp = 0;

    for my $log ( @{$logs} ) {
        # inside report period?
        next unless $log->{'end'} > $start;
        next unless $log->{'end'} < $end;

        my $x = int(($log->{'end'} - $start) / $report_duration * $drawing_width);

        # draw start timestamp if possible
        if(( $x > $last_timestamp + MIN_TIMESTAMP_SPACING ) and ( $x < $drawing_width - 1 - MIN_TIMESTAMP_SPACING )){
            _draw_timestamp($c, $im, $color, $x, $log->{'end'}, $smallimage, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset);
            $last_timestamp = $x;
        }
    }

    _draw_timestamp($c, $im, $color, $drawing_width, $end, $smallimage, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset);

    return 1;
}

##########################################################
sub _draw_timestamp {
    my ( $c, $im, $color, $x, $timestamp, $smallimage, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset) = @_;

    my($font_width,$font_height) = (gdSmallFont->width,gdSmallFont->height);

    my $string       = strftime($c->config->{'datetime_format_trends'}, localtime($timestamp));
    my $string_width = $font_width * length($string);

    unless($smallimage) {
        $im->stringUp(gdSmallFont, $x+$drawing_x_offset-($font_height/2), $drawing_y_offset+$drawing_height+$string_width+5, $string, $color);
    }

    # draw a dashed vertical line at this point
    if($x > 0 and $x < ($drawing_width-1)) {
        _draw_dashed_line($im, $x+$drawing_x_offset, $drawing_y_offset, $x+$drawing_x_offset, $drawing_y_offset+$drawing_height, $color);
    }

    return 1;
}

##########################################################
sub _draw_dashed_line {
    my($im, $x1, $y1, $x2, $y2, $color) = @_;

    my $style = [ $color, $color, gdTransparent, gdTransparent, $color, $color, gdTransparent, gdTransparent, $color, $color, gdTransparent, gdTransparent ];

    # sets current style to a dashed line
    $im->setStyle(@{$style});

    # draws a line (dashed)
    $im->line($x1,$y1,$x2,$y2,gdStyled);

    return 1;
}


##########################################################
sub _draw_states {
    my ( $c, $im, $mode, $colors, $logs, $start, $end, $smallimage, $drawing_width, $drawing_height, $drawing_x_offset, $drawing_y_offset,$zoom) = @_;

    my $report_duration = $end - $start;

    my $in_timeperiod = 1;
    my($last_color, $last_hight, $last_state, $last_plugin_output, $image_map);
    for my $log ( @{$logs} ) {
        next unless defined $log->{'class'};

        # host/service state?
        my($color,$height, $state, $plugin_output);
        $state         = ucfirst $log->{'class'};
        $plugin_output = $log->{'plugin_output'};
        if(   $log->{'class'} eq 'UP')            { $color = $colors->{'green'};    $height = 60; }
        elsif($log->{'class'} eq 'DOWN')          { $color = $colors->{'red'};      $height = 40; }
        elsif($log->{'class'} eq 'UNREACHABLE')   { $color = $colors->{'darkred'};  $height = 20; }
        elsif($log->{'class'} eq 'OK')            { $color = $colors->{'green'};    $height = 80; }
        elsif($log->{'class'} eq 'WARNING')       { $color = $colors->{'yellow'};   $height = 60; }
        elsif($log->{'class'} eq 'UNKNOWN')       { $color = $colors->{'orange'};   $height = 40; }
        elsif($log->{'class'} eq 'CRITICAL')      { $color = $colors->{'red'};      $height = 20; }
        elsif($log->{'class'} eq 'INDETERMINATE') { $color = $last_color;           $height = $last_hight; $state = $last_state; $plugin_output = $last_plugin_output; }

        # set color according to timeperiods
        if($log->{'type'} eq 'TIMEPERIOD START') {
            $in_timeperiod = 1;
        }
        elsif($log->{'type'} eq 'TIMEPERIOD STOP') {
            $in_timeperiod = 0;
        }
        if($in_timeperiod == 0 and defined $color) {
            if(    $color == $colors->{'green'})   { $color = $colors->{'green_t'}; }
            elsif( $color == $colors->{'red'})     { $color = $colors->{'red_t'}; }
            elsif( $color == $colors->{'darkred'}) { $color = $colors->{'darkred_t'}; }
            elsif( $color == $colors->{'yellow'})  { $color = $colors->{'yellow_t'}; }
            elsif( $color == $colors->{'orange'})  { $color = $colors->{'orange_t'}; }
        }
        if($in_timeperiod == 1 and defined $color) {
            if(    $color == $colors->{'green_t'})   { $color = $colors->{'green'}; }
            elsif( $color == $colors->{'red_t'})     { $color = $colors->{'red'}; }
            elsif( $color == $colors->{'darkred_t'}) { $color = $colors->{'darkred'}; }
            elsif( $color == $colors->{'yellow_t'})  { $color = $colors->{'yellow'}; }
            elsif( $color == $colors->{'orange_t'})  { $color = $colors->{'orange'}; }
        }

        next unless defined $height;
        $last_color         = $color;
        $last_hight         = $height;
        $last_state         = $state;
        $last_plugin_output = $plugin_output;

        # inside report period?
        next if $log->{'end'}   <= $start;
        next if $log->{'start'} > $end;

        # small image is fully painted
        if($smallimage) { $height = $drawing_height; }

        my $x1 = $drawing_x_offset + int(($log->{'start'} - $start) / $report_duration * $drawing_width);
        my $y1 = $drawing_y_offset + $drawing_height - $height;

        my $x2 = $drawing_x_offset + int(($log->{'end'} - $start) / $report_duration * $drawing_width);
        my $y2 = $drawing_y_offset + $drawing_height;

        if($x1 < $drawing_x_offset) { $x1 = $drawing_x_offset; }
        if($x2 < $drawing_x_offset) { $x2 = $drawing_x_offset; }

        if($mode == IMAGE_MAP_MODE) {
            my $t1         = $log->{'start'};
            my $t2         = $log->{'end'};
            my $next_start = $t1;
            my $next_end   = $t2;
            $zoom          = 1 unless defined $zoom;

            # determine next start and end time range with zoom factor
            if($zoom > 0){
                $next_start = $t1 - int((($end - $start) / 2) / $zoom);
                $next_end   = $t2 + int((($end - $start) / 2) / $zoom);
            } else {
                $next_start = $t1 - int((($end - $start) / 2) * $zoom);
                $next_end   = $t2 + int((($end - $start) / 2) * $zoom);
            }
            $t1 = $next_start;
            $t2 = $next_end;
            if($t2 > time()) { $t2 = time(); }

            push @{$image_map}, {
                "x1"                 => $x1,
                "y1"                 => $drawing_y_offset,

                "x2"                 => $x2,
                "y2"                 => $y2,

                "state"              => $state,

                "start_human"        => strftime($c->config->{'datetime_format_trends'}, localtime($log->{'start'})),
                "end_human"          => strftime($c->config->{'datetime_format_trends'}, localtime($log->{'end'})),
                "start"              => $log->{'start'},
                "end"                => $log->{'end'},
                "plugin_output"      => $log->{'plugin_output'},

                "t1"                 => $t1,
                "t2"                 => $t2,

                "real_plugin_output" => $plugin_output,

                "duration"           => Thruk::Utils::Filter::duration($log->{'end'} - $log->{'start'}),
            };
        }
        else {
            $im->filledRectangle($x1,$y1,$x2,$y2,$color);
        }
    }

    if($mode == IMAGE_MAP_MODE) {
        return $image_map;
    }
    return 1;
}


##########################################################
sub _draw_text {
    my ($c, $im, $color, $start, $end, $drawing_width, $drawing_x_offset, $host, $service ) = @_;

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

    my $ttf = '/usr/share/fonts/truetype/ttf-dejavu/DejaVuSans.ttf';
    if(-e $ttf) {
        # truetype fonts are the only way to support utf8
        $im->stringFT($color,$ttf,10,0,($drawing_width/2)-($string_width/2)+$drawing_x_offset,$font_height+2,
              $title,
              { charmap  => 'Unicode'});
    } else {
        $im->string(gdSmallFont,($drawing_width/2)-($string_width/2)+$drawing_x_offset,$font_height, $title, $color);
    }

    # report start/end date
    my $from_to = strftime($c->config->{'datetime_format_trends'}, localtime($start))." to ".strftime($c->config->{'datetime_format_trends'}, localtime($end));
    $string_width  = length($from_to) * $font_width;
    $im->string(gdSmallFont,($drawing_width/2)-($string_width/2)+$drawing_x_offset,($font_height*2)+5,$from_to,$color);

    return 1;
}

##########################################################
sub _draw_horizontal_grid_lines {
    my ($im, $color, $drawing_width, $drawing_x_offset, $drawing_y_offset, $service ) = @_;

    _draw_dashed_line($im, $drawing_x_offset,$drawing_y_offset+10,$drawing_x_offset+$drawing_width,$drawing_y_offset+10,$color);
    _draw_dashed_line($im, $drawing_x_offset,$drawing_y_offset+30,$drawing_x_offset+$drawing_width,$drawing_y_offset+30,$color);
    _draw_dashed_line($im, $drawing_x_offset,$drawing_y_offset+50,$drawing_x_offset+$drawing_width,$drawing_y_offset+50,$color);
    if(defined $service) {
        _draw_dashed_line($im, $drawing_x_offset,$drawing_y_offset+70,$drawing_x_offset+$drawing_width,$drawing_y_offset+70,$color);
    }

    return 1;
}

##########################################################
sub _draw_time_breakdowns {
    my ($c, $im, $colors, $drawing_width, $drawing_x_offset, $drawing_y_offset, $host, $service ) = @_;

    my $font_width = gdSmallFont->width;

    my $string;
    if(defined $service){

        my $avail_data = $c->stash->{'avail_data'}->{'services'}->{$host}->{$service};
        return unless defined $avail_data;
        my $total_time =
              $avail_data->{'time_ok'}
            + $avail_data->{'time_warning'}
            + $avail_data->{'time_unknown'}
            + $avail_data->{'time_critical'}
            + $avail_data->{'time_indeterminate_nodata'}
            + $avail_data->{'time_indeterminate_notrunning'};

        $string = _get_time_breakdown_string($total_time,$avail_data->{'time_ok'},"Ok");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+5,$string,$colors->{'darkgreen'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*2),$drawing_y_offset+5,"Ok",$colors->{'darkgreen'});

        $string = _get_time_breakdown_string($total_time,$avail_data->{'time_warning'},"Warning");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+25,$string,$colors->{'yellow'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*7),$drawing_y_offset+25,"Warning",$colors->{'yellow'});

        $string = _get_time_breakdown_string($total_time,$avail_data->{'time_unknown'},"Unknown");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+45,$string,$colors->{'orange'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*7),$drawing_y_offset+45,"Unknown",$colors->{'orange'});

        $string = _get_time_breakdown_string($total_time,$avail_data->{'time_critical'},"Critical");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+65,$string,$colors->{'red'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*8),$drawing_y_offset+65,"Critical",$colors->{'red'});

        $string = _get_time_breakdown_string($total_time,$avail_data->{'time_indeterminate_nodata'}+$avail_data->{'time_indeterminate_notrunning'},"Indeterminate");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+85,$string,$colors->{'black'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*13),$drawing_y_offset+85,"Indeterminate",$colors->{'black'});

    }
    else{

        my $avail_data = $c->stash->{'avail_data'}->{'hosts'}->{$host};
        return unless defined $avail_data;
        my $total_time =
              $avail_data->{'time_up'}
            + $avail_data->{'time_down'}
            + $avail_data->{'time_unreachable'}
            + $avail_data->{'time_indeterminate_nodata'}
            + $avail_data->{'time_indeterminate_notrunning'};

        $string = _get_time_breakdown_string($total_time,$avail_data->{'time_up'},"Up");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+5,$string,$colors->{'darkgreen'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*2),$drawing_y_offset+5,"Up",$colors->{'darkgreen'});

        $string = _get_time_breakdown_string($total_time,$avail_data->{'time_down'},"Down");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+25,$string,$colors->{'red'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*4),$drawing_y_offset+25,"Down",$colors->{'red'});

        $string = _get_time_breakdown_string($total_time,$avail_data->{'time_unreachable'},"Unreachable");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+45,$string,$colors->{'darkred'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*11),$drawing_y_offset+45,"Unreachable",$colors->{'darkred'});

        $string = _get_time_breakdown_string($total_time,$avail_data->{'time_indeterminate_nodata'}+$avail_data->{'time_indeterminate_notrunning'},"Indeterminate");
        $im->string(gdSmallFont,$drawing_x_offset+$drawing_width+20,$drawing_y_offset+65,$string,$colors->{'black'});
        $im->string(gdSmallFont,$drawing_x_offset-10-($font_width*13),$drawing_y_offset+65,"Indeterminate",$colors->{'black'});
    }

    return 1;
}

##########################################################
sub _get_time_breakdown_string {
    my($total_time,$time, $type) = @_;

    my $duration     = Thruk::Utils::Filter::duration($time);
    my $percent_time = 0;
    if($total_time > 0) {
        $percent_time = ($time/$total_time)*100;
    }
    return sprintf("%-13s: (%.3f%%) %s",$type,$percent_time,$duration);
}

##########################################################
sub _get_image {
    my $file = shift;
    my $im   = GD::Image->new($file);
    return $im;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
