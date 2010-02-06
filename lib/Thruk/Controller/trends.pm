package Thruk::Controller::trends;

use strict;
use warnings;
use GD;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::trends - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

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

    # calculate availability data
    $c->{'request'}->{'parameters'}->{'full_log_entries'} = 1;
    Thruk::Utils::calculate_availability($c);

    my $width  = 500;
    my $height =  20;

    unless(exists $c->{'request'}->{'parameters'}->{'smallimage'}) {
        $width  = 600;
        $height = 300;
    }

    my $im = GD::Image->new($width, $height);


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


    #use Data::Dumper;
    #$c->log->debug(Dumper($c->stash->{'logs'}));

    # draw time breakdowns
    $im = $self->_draw_states($c, $im, $self->{'colors'}, $c->stash->{'logs'}, $c->stash->{'start'}, $c->stash->{'end'});

    # draw timestamps
    $im = $self->_draw_timestamps($c, $im, $self->{'colors'}->{'black'}, $c->stash->{'logs'}, $c->stash->{'start'}, $c->stash->{'end'});

    # draw a border
    $im->rectangle(0,0,$width-1,$height-1,$self->{'colors'}->{'black'});

    return $im;
}

##########################################################
sub _draw_timestamps {
    my ( $self, $c, $im, $color, $logs, $start, $end) = @_;

    my $width  = $im->width;
    my $height = $im->height;
    my $report_duration = $end - $start;

    for my $log ( @{$logs} ) {
        # inside report period?
        next unless $log->{'end'} > $start;
        next unless $log->{'end'} < $end;

        # proc start?
        next unless $log->{'type'} eq 'PROGRAM (RE)START';

        my $x1 = int(($log->{'end'} - $start) / $report_duration * $width);
        my $y1 = 0;

        my $x2 = $x1;
        my $y2 = $height;

        $im = $self->_draw_dashed_line($im, $x1, $y1, $x2, $y2, $color);
    }

    return $im;
}


##########################################################
sub _draw_dashed_line {
    my($self, $im, $x1, $y1, $x2, $y2, $color) = @_;

    my $style = [ $color, $color, gdTransparent, gdTransparent, $color, $color, gdTransparent, gdTransparent, $color, $color, gdTransparent, gdTransparent ];

    # sets current style to a dashed line
    $im->setStyle(@{$style});

    # draws a line (dashed)
    $im->line($x1,$y1,$x2,$y2,gdStyled);

    return $im;
}


##########################################################
sub _draw_states {
    my ( $self, $c, $im, $colors, $logs, $start, $end) = @_;

    my $width  = $im->width;
    my $height = $im->height;
    my $report_duration = $end - $start;

    my $last_color;
    for my $log ( @{$logs} ) {
        next unless defined $log->{'class'};


        # host/service state?
        my $color;
        if(   $log->{'class'} eq 'UP')            { $color = $colors->{'green'};   }
        elsif($log->{'class'} eq 'DOWN')          { $color = $colors->{'red'};     }
        elsif($log->{'class'} eq 'UNREACHABLE')   { $color = $colors->{'darkred'}; }
        elsif($log->{'class'} eq 'DOWN')          { $color = $colors->{'red'};     }
        elsif($log->{'class'} eq 'OK')            { $color = $colors->{'green'};   }
        elsif($log->{'class'} eq 'WARNING')       { $color = $colors->{'yellow'};  }
        elsif($log->{'class'} eq 'UNKNOWN')       { $color = $colors->{'orange'};  }
        elsif($log->{'class'} eq 'CRITICAL')      { $color = $colors->{'red'};     }
        elsif($log->{'class'} eq 'INDETERMINATE') { $color = $last_color;          }

        next unless defined $color;
        $last_color = $color;

        # inside report period?
        next if $log->{'end'}   <= $start;
        next if $log->{'start'} > $end;

        my $x1 = int(($log->{'start'} - $start) / $report_duration * $width);
        my $y1 = 0;

        my $x2 = int(($log->{'end'} - $start) / $report_duration * $width);
        my $y2 = $height;

        $im->filledRectangle($x1,$y1,$x2,$y2,$color);
    }

    return $im;
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
