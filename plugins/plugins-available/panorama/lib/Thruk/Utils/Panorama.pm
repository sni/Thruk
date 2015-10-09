package Thruk::Utils::Panorama;

use strict;
use warnings;
use JSON::XS;

=head1 NAME

Thruk::Utils::Panorama - Thruk Utils for Panorama Dashboard

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

BEGIN {
    #use Thruk::Timer qw/timing_breakpoint/;
}

##########################################################
use constant {
    ACCESS_NONE      => 0,
    ACCESS_READONLY  => 1,
    ACCESS_READWRITE => 2,
    ACCESS_OWNER     => 3,
};

use base 'Exporter';
our @EXPORT_OK = (qw/ACCESS_NONE ACCESS_READONLY ACCESS_READWRITE ACCESS_OWNER/);

##########################################################

=head2 get_static_panorama_files

    get_static_panorama_files($config)

return all static js files required for panorama

=cut
sub get_static_panorama_files {
    my($config) = @_;
    my @files;
    for my $file (sort glob($config->{'plugin_path'}.'/plugins-enabled/panorama/root/js/*.js')) {
        next if $file =~ m|track_timers|mx;
        next if $file =~ m|panorama_js_functions|mx;
        $file =~ s|^.*/root/js/|plugins/panorama/js/|gmx;
        push @files, $file;
    }
    unshift(@files, 'plugins/panorama/js/panorama_js_functions.js');
    return(\@files);
}

##########################################################

=head2 clean_old_dashboards

    clean_old_dashboards($c)

remove all dashboards older than 1 day

=cut
sub clean_old_dashboards {
    my($c) = @_;
    my $num = 0;
    my $dashboards = get_dashboard_list($c, 'all');
    for my $d (@{$dashboards}) {
        next unless $d->{'objects'} == 0;
        my $dashboard = load_dashboard($c, $d->{'nr'});
        my @stat      = stat($dashboard->{'file'});
        if(($stat[9] < time() - 86400 && $d->{'name'} eq 'Dashboard') || $stat[9] < time() - (86400 * 14)) {
            delete_dashboard($c, $d->{'nr'}, $dashboard);
            $num++;
        }
    }
    return($num);
}

##########################################################

=head2 get_dashboard_list

    get_dashboard_list($c, $type)

return list of dashboards. Type can be 'public', 'my' or 'all' where 'all' is
only available for admins.

=cut
sub get_dashboard_list {
    my($c, $type) = @_;

    # returns wrong list of public dashboards otherwise
    my $is_admin;
    if($type eq 'public') {
        $is_admin = delete $c->stash->{'is_admin'};
    }

    my $dashboards = [];
    for my $file (glob($c->{'panorama_var'}.'/*.tab')) {
        if($file =~ s/^.*\/(\d+)\.tab$//mx) {
            my $nr = $1;
            my $d  = load_dashboard($c, $nr);
            if($d) {
                if($type eq 'all') {
                    # all
                } elsif($type eq 'public') {
                    # public
                    next if $d->{'user'} eq $c->stash->{'remote_user'};
                } else {
                    # my
                    next if $d->{'user'} ne $c->stash->{'remote_user'};
                }
                my $groups_rw = [];
                my $groups_ro = [];
                for my $group (@{$d->{'tab'}->{'xdata'}->{'groups'}}) {
                    my $name = (keys %{$group})[0];
                    if($group->{$name} eq 'read-write') {
                        push(@{$groups_rw}, $name);
                    } else {
                        push(@{$groups_ro}, $name);
                    }
                }
                push @{$dashboards}, {
                    id          => $d->{'id'},
                    nr          => $d->{'nr'},
                    name        => $d->{'tab'}->{'xdata'}->{'title'},
                    user        => $d->{'user'},
                    groups_rw   => join(', ', @{$groups_rw}),
                    groups_ro   => join(', ', @{$groups_ro}),
                    readonly    => $d->{'readonly'} ? JSON::XS::true : JSON::XS::false,
                    description => $d->{'description'} || '',
                    objects     => $d->{'objects'},
                };
            }
        }
    }

    # restore admin flag
    if($type eq 'public') {
        $c->stash->{'is_admin'} = $is_admin;
    }

    $dashboards = Thruk::Backend::Manager::_sort({}, $dashboards, 'name');
    return $dashboards;
}

##########################################################

=head2 load_dashboard

    load_dashboard($c, $nr)

return dashboard data.

=cut
sub load_dashboard {
    my($c, $nr) = @_;
    $nr       =~ s/^tabpan-tab_//gmx;
    my $file  = $c->{'panorama_var'}.'/'.$nr.'.tab';
    return unless -s $file;
    my $dashboard  = Thruk::Utils::read_data_file($file);
    $dashboard->{'objects'} = (scalar keys %{$dashboard}) -2;
    my $permission = is_authorized_for_dashboard($c, $nr, $dashboard);
    return unless $permission >= ACCESS_READONLY;
    if($permission == ACCESS_READONLY) {
        $dashboard->{'readonly'} = 1;
    } else {
        $dashboard->{'readonly'} = 0;
    }
    my @stat = stat($file);
    $dashboard->{'ts'}   = $stat[9];
    $dashboard->{'nr'}   = $nr;
    $dashboard->{'id'}   = 'tabpan-tab_'.$nr;
    $dashboard->{'file'} = $file;
    my $public = delete $dashboard->{'public'};
    $dashboard->{'tab'}->{'xdata'}->{'groups'} = [] unless defined $dashboard->{'tab'}->{'xdata'}->{'groups'};
    if($public) {
        push @{$dashboard->{'tab'}->{'xdata'}->{'groups'}}, { '*' => 'read-only' };
    }

    # merge runtime data
    my $runtime = {};
    if(-e $file.'.runtime') {
       $runtime = Thruk::Utils::read_data_file($file.'.runtime');
    }
    for my $tab (keys %{$runtime}) {
        next if !defined $dashboard->{$tab};
        for my $key (keys %{$runtime->{$tab}}) {
            $dashboard->{$tab}->{'xdata'}->{$key} = $runtime->{$tab}->{$key};
        }
    }

    if(!defined $dashboard->{'tab'})            { $dashboard->{'tab'}            = {}; }
    if(!defined $dashboard->{'tab'}->{'xdata'}) { $dashboard->{'tab'}->{'xdata'} = _get_default_tab_xdata($c) }
    $dashboard->{'tab'}->{'xdata'}->{'owner'} = $dashboard->{'user'};
    return $dashboard;
}

##########################################################

=head2 is_authorized_for_dashboard

    is_authorized_for_dashboard($c, $nr, [$dashboard])

check permissions for dashboard and optionally loads the dashboard.

returns:
    0        ACCESS_NONE       - no access
    1        ACCESS_READONLY   - public dashboard, readonly access
    2        ACCESS_READWRITE  - private dashboard, readwrite access
    3        ACCESS_OWNER      - private dashboard, owner/admin access

=cut
sub is_authorized_for_dashboard {
    my($c, $nr, $dashboard) = @_;
    $nr =~ s/^tabpan-tab_//gmx;
    my $file = $c->{'panorama_var'}.'/'.$nr.'.tab';

    # super user have permission for all reports
    return ACCESS_OWNER if $c->stash->{'is_admin'};

    # does that dashboard already exist?
    if(-s $file) {
        $dashboard = Thruk::Utils::Panorama::load_dashboard($c, $nr) unless $dashboard;
        if($dashboard->{'user'} eq $c->stash->{'remote_user'}) {
            return ACCESS_READONLY if $c->stash->{'readonly'};
            return ACCESS_OWNER;
        }
        # access from contactgroups
        my $contactgroups = [keys %{$c->cache->get->{'users'}->{$c->stash->{'remote_user'}}->{'contactgroups'}}];
        my $access = ACCESS_NONE;
        $dashboard->{'tab'}->{'xdata'}->{'groups'} = [] unless defined $dashboard->{'tab'}->{'xdata'}->{'groups'};
        for my $group (@{$dashboard->{'tab'}->{'xdata'}->{'groups'}}) {
            my $name = (keys %{$group})[0];
            my $lvl  = $group->{$name} eq 'read-write' ? ACCESS_READWRITE : ACCESS_READONLY;
            if($name eq '*') {
                $access = $lvl if $lvl > $access;
                next;
            }
            for my $test (@{$contactgroups}) {
                if($name eq $test) {
                    $access = $lvl if $lvl > $access;
                }
            }
        }
        return $access;
    }
    return ACCESS_READONLY if $c->stash->{'readonly'};
    return ACCESS_OWNER;
}

##########################################################

=head2 delete_dashboard

    delete_dashboard($c, $nr, [$dashboard])

return dashboard data.

=cut
sub delete_dashboard {
    my($c, $nr, $dashboard) = @_;
    $dashboard = load_dashboard($c, $nr) unless $dashboard;
    unlink($dashboard->{'file'});
    # and also all backups
    unlink(glob($dashboard->{'file'}.'.*'));
    return;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
