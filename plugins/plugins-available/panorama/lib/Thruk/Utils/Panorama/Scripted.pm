package Thruk::Utils::Panorama::Scripted;

=head1 NAME

Thruk::Utils::Panorama::Scripted - Scripted Panorama Dashboards

=head1 DESCRIPTION

Scripted Panorama Dashboards

=cut

use strict;
use warnings;
use Carp qw/confess/;
use File::Slurp qw/read_file/;
use JSON::XS qw/decode_json encode_json/;

##############################################
=head1 METHODS

=head2 load_dashboard

  load_dashboard($c, $nr, $file, [$meta_data_only])

read dynamic dashboard

=cut
sub load_dashboard {
    my($c, $nr, $file, $meta_data_only) = @_;

    $c->stats->profile(begin => "Utils::Panorama::Scripted::load_dashboard($file)");

    my $dashboard = {};
    my($code, $data) = split(/__DATA__/mx, join("", read_file($file)), 2);

    # set meta data
    my $meta = { nr => $nr, groups => '[]', title => 'Dashboard', user => '' };
    if($code =~ m/^\#\s*title:\s*(.*?)$/mx) {
        $meta->{'title'} = $1;
    }
    if($code =~ m/^\#\s*groups:\s*(.*?)$/mx) {
        $meta->{'groups'} = decode_json($1);
    }
    if($code =~ m/^\#\s*user:\s*(.*?)$/mx) {
        $meta->{'user'} = $1;
    }
    _merge_meta($dashboard, $meta);

    if($meta_data_only) {
        $c->stats->profile(end => "Utils::Panorama::Scripted::load_dashboard($file)");
        return($dashboard);
    }

    $Thruk::Utils::Panorama::Scripted::c    = $c;
    $Thruk::Utils::Panorama::Scripted::nr   = $nr;
    $Thruk::Utils::Panorama::Scripted::data = $data || '{}';
    $Thruk::Utils::Panorama::Scripted::meta = $meta;

    ## no critic
    eval("#line 1 $file\n".$code);
    ## use critic
    if($@) {
        $c->log->error("error while loading dynamic dashboard from ".$file.": ".$@);
        return;
    }

    _merge_meta($dashboard, $meta);
    $dashboard = _cleanup_dashboard($dashboard, $nr);

    # cleanup
    $Thruk::Utils::Panorama::Scripted::c    = undef;
    $Thruk::Utils::Panorama::Scripted::nr   = undef;
    $Thruk::Utils::Panorama::Scripted::data = undef;
    $Thruk::Utils::Panorama::Scripted::meta = undef;

    $c->stats->profile(end => "Utils::Panorama::Scripted::load_dashboard($file)");

    return($dashboard);
}

##############################################
sub _cleanup_dashboard {
    my($dashboard, $nr) = @_;
    if($dashboard && ref $dashboard eq 'HASH') {
        for my $key (keys %{$dashboard}) {
            if($key =~ m/^panlet_(\d+)$/mx) {
                my $newkey = "tabpan-tab_".$nr."_panlet_".$1;
                $dashboard->{$newkey} = delete $dashboard->{$key};
            }
        }
    }
    return($dashboard);
}
##############################################
sub _merge_meta {
    my($dashboard, $meta) = @_;
    $dashboard->{'tab'}->{'xdata'}->{'title'}  = $meta->{'title'}  unless defined $dashboard->{'tab'}->{'xdata'}->{'title'};
    $dashboard->{'tab'}->{'xdata'}->{'groups'} = $meta->{'groups'} unless defined $dashboard->{'tab'}->{'xdata'}->{'groups'};
    $dashboard->{'user'}                       = $meta->{'user'}   unless defined $dashboard->{'user'};
    $dashboard->{'nr'}                         = $meta->{'nr'};
    return($dashboard);
}

##############################################

=head2 load_data

  load_data()

read data part

=cut
sub load_data {
    my $json = JSON::XS->new->utf8;
    $json->relaxed();
    my $dashboard = $json->decode($Thruk::Utils::Panorama::Scripted::data);
    _merge_meta($dashboard, $Thruk::Utils::Panorama::Scripted::meta);
    return($dashboard);
}

1;

__END__

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
