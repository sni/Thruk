package Thruk::Controller::trends;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::trends - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use constant {
    IMAGE_MAP_MODE        => 1,
    IMAGE_MODE            => 2,
};

=head1 METHODS

=head2 index

=cut

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    require Thruk::Utils::Trends;
    Thruk::Utils::Trends->import();

    my $trends_helper = new Thruk::Utils::Trends;

    # set defaults
    $c->stash->{title}            = 'Trends';
    $c->stash->{infoBoxTitle}     = 'Host and Service State Trends';
    $c->stash->{page}             = 'trends';
    $c->stash->{'no_auto_reload'} = 1;

    Thruk::Utils::ssi_include($c);

    if(exists $c->{'request'}->{'parameters'}->{'createimage'}) {
        if(exists $c->{'request'}->{'parameters'}->{'job_id'}) {
            my $dir = $c->config->{'var_path'}."/jobs/".$c->{'request'}->{'parameters'}->{'job_id'};
            $c->stash->{gd_image} = Thruk::Utils::Trends::_get_image($dir."/graph.png");
        } else {
            $c->stash->{gd_image} = Thruk::Utils::Trends::_create_image($c, IMAGE_MODE);
        }
        $c->forward('Thruk::View::GD');
    }
    elsif($trends_helper->_show_step_2($c)) {
        # show step 2
    }
    elsif($trends_helper->_show_step_3($c)) {
        # show step 3
    }
    elsif($trends_helper->_show_report($c)) {
        # show report
    }
    else {
        $c->stash->{'template'} = 'trends_step_1.tt';
    }

    return 1;
}


=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
