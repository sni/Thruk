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
use Cpanel::JSON::XS qw/decode_json encode_json/;
use Encode qw(decode_utf8);
use Thruk::Utils::IO;
use Thruk::Utils::Log qw/:all/;

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
    my($code, $data) = split(/__DATA__/mx, decode_utf8(join("", read_file($file)), 2));

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
    $meta->{'type'} = 'perl';
    if($code =~ m/^\#\!/mx && $code !~ m/^\#\!.*?perl/mx) {
        $meta->{'type'} = 'other';
    }
    _merge_meta($dashboard, $meta);

    if($meta_data_only) {
        $c->stats->profile(end => "Utils::Panorama::Scripted::load_dashboard($file)");
        return($dashboard);
    }

    local $ENV{DASHBOARD}          = $nr;
    local $ENV{DASHBOARD_FILE}     = $file;
    local $ENV{REMOTE_USER}        = $c->stash->{'remote_user'};
    local $ENV{REMOTE_USER_GROUPS} = join(';', @{$c->user->{'groups'}});

    if($meta->{'type'} eq 'perl') {
        $Thruk::Utils::Panorama::Scripted::c    = $c;
        $Thruk::Utils::Panorama::Scripted::nr   = $nr;
        $Thruk::Utils::Panorama::Scripted::data = $data || '{}';
        $Thruk::Utils::Panorama::Scripted::meta = $meta;

        ## no critic
        eval("#line 1 $file\n".$code);
        ## use critic
        if($@) {
            _error("error while loading dynamic dashboard from ".$file.": ".$@);
            return;
        }

        _merge_meta($dashboard, $meta);
        $dashboard = _cleanup_dashboard($dashboard, $nr);

        # cleanup
        $Thruk::Utils::Panorama::Scripted::c    = undef;
        $Thruk::Utils::Panorama::Scripted::nr   = undef;
        $Thruk::Utils::Panorama::Scripted::data = undef;
        $Thruk::Utils::Panorama::Scripted::meta = undef;
    } else {
        my($rc, $output) = Thruk::Utils::IO::cmd($c, $file);
        if($rc != 0) {
            my $err = "got rc $rc while executing dynamic dashboard from ".$file;
            _error($err);
            _error($output);
            return;
        }
        eval {
            my $json = Cpanel::JSON::XS->new->utf8;
            $json->relaxed();
            $dashboard = $json->decode($output);
        };
        if($@) {
            _error("error while parsing output from dynamic dashboard in ".$file.": ".$@);
            return;
        }
        _merge_meta($dashboard, $meta);
        $dashboard = _cleanup_dashboard($dashboard, $nr);
    }

    $c->stats->profile(end => "Utils::Panorama::Scripted::load_dashboard($file)");

    return($dashboard);
}

##############################################
sub _cleanup_dashboard {
    my($dashboard, $nr) = @_;
    if($dashboard && ref $dashboard eq 'HASH') {
        for my $key (keys %{$dashboard}) {
            if($key =~ m/^panlet_(\d+)$/mx) {
                my $newkey = "pantab_".$nr."_panlet_".$1;
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
    my $json = Cpanel::JSON::XS->new->utf8;
    $json->relaxed();
    my $dashboard = $json->decode($Thruk::Utils::Panorama::Scripted::data);
    _merge_meta($dashboard, $Thruk::Utils::Panorama::Scripted::meta);
    return($dashboard);
}

##############################################

=head2 get_screen_data

  get_screen_data()

return hints about users screen

=cut
sub get_screen_data {
    my $c = $Thruk::Request::c;
    my $screen = {};
    return $screen unless $c;
    if($c->cookie('thruk_screen')) {
        eval {
            $screen = decode_json($c->cookie('thruk_screen')->value);
        };
        if($screen->{'height'}) {
            $screen->{'height'} = $c->stash->{one_tab_only} ? $screen->{'height'} : ($screen->{'height'} - 25);
            $screen->{'offset_x'} = 0;
            $screen->{'offset_y'} = 25;
            $screen->{'gridsnap'} = 20;
            $screen->{'tabbar'}   = $c->stash->{one_tab_only} ? 0 : 1;
        }
    }
    return $screen;
}

1;
