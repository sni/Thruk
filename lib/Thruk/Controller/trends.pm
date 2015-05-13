package Thruk::Controller::trends;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::trends - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=cut

use constant {
    IMAGE_MAP_MODE        => 1,
    IMAGE_MODE            => 2,
};

=head1 METHODS

=head2 index

=cut

##########################################################
sub index {
    my ( $c ) = @_;

    Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_DEFAULTS);

    require Thruk::Utils::Trends;
    Thruk::Utils::Trends->import();

    my $trends_helper = new Thruk::Utils::Trends;

    # set defaults
    $c->stash->{title}            = 'Trends';
    $c->stash->{infoBoxTitle}     = 'Host and Service State Trends';
    $c->stash->{page}             = 'trends';
    $c->stash->{'no_auto_reload'} = 1;

    Thruk::Utils::ssi_include($c);

    if(exists $c->req->parameters->{'createimage'}) {
        if(exists $c->req->parameters->{'job_id'}) {
            my $dir = $c->config->{'var_path'}."/jobs/".$c->req->parameters->{'job_id'};
            $c->stash->{gd_image} = Thruk::Utils::Trends::_get_image($dir."/graph.png");
        } else {
            $c->stash->{gd_image} = Thruk::Utils::Trends::_create_image($c, IMAGE_MODE);
        }
        return($c->render_gd());
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

1;
