package Thruk::Utils::Panorama;

use strict;
use warnings;
use Thruk::Utils::Panorama::Scripted;
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

    SOFT_STATE       => 0,
    HARD_STATE       => 1,

    DASHBOARD_FILE_VERSION => 2,
};

use base 'Exporter';
our @EXPORT_OK = (qw/ACCESS_NONE ACCESS_READONLY ACCESS_READWRITE ACCESS_OWNER DASHBOARD_FILE_VERSION SOFT_STATE HARD_STATE/);

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
        my $dashboard = load_dashboard($c, $d->{'nr'}, 1);
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
    for my $file (glob($c->config->{'etc_path'}.'/panorama/*.tab')) {
        if($file =~ s/^.*\/(\d+)\.tab$//mx) {
            my $nr = $1;
            next if $nr == 0;
            my $d  = load_dashboard($c, $nr, 1);
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
        } else {
            $c->log->warn("panorama dashboard with unusual name skipped: ".$file);
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

    load_dashboard($c, $nr, [$meta_data_only])

return dashboard data.

=cut
sub load_dashboard {
    my($c, $nr, $meta_data_only) = @_;
    $nr       =~ s/^tabpan-tab_//gmx;
    my $file  = $c->config->{'etc_path'}.'/panorama/'.$nr.'.tab';

    # startpage can be overridden, only load original file if there is nonen in etc/
    if($nr == 0 && !-s $file) {
        $file = $c->config->{'plugin_path'}.'/plugins-available/panorama/0.tab';
    }

    return unless -s $file;
    my $dashboard;
    my $scripted = 0;
    if(-x $file) {
        # scripted dashboard
        $dashboard = Thruk::Utils::Panorama::Scripted::load_dashboard($c, $nr, $file, $meta_data_only);
        $scripted = 1;
    } else {
        # static dashboard
        $dashboard = Thruk::Utils::read_data_file($file);
        if(!defined $dashboard) {
            my $content = Thruk::Utils::IO::read($file);
            if($content =~ m/^\#\s*title:/mx) {
                $c->log->warn("non-executable scripted dashboard found in $file, forgot to chmod +x");
            }
        }
    }
    return unless $dashboard;

    my $permission = is_authorized_for_dashboard($c, $nr, $dashboard);
    return unless $permission >= ACCESS_READONLY;
    if($scripted || $permission == ACCESS_READONLY) {
        $dashboard->{'readonly'} = 1;
    } else {
        $dashboard->{'readonly'} = 0;
    }
    my @stat = stat($file);
    $dashboard->{'ts'}       = $stat[9] unless ($scripted && $dashboard->{'ts'});
    $dashboard->{'nr'}       = $nr;
    $dashboard->{'id'}       = 'tabpan-tab_'.$nr;
    $dashboard->{'file'}     = $file;
    $dashboard->{'scripted'} = $scripted;

    # assume scripted dashboards use always the latest syntax
    if(!$scripted) {
        # convert old public flag to group based permissions
        my $public = delete $dashboard->{'public'};
        $dashboard->{'tab'}->{'xdata'}->{'groups'} = [] unless defined $dashboard->{'tab'}->{'xdata'}->{'groups'};
        if($public) {
            push @{$dashboard->{'tab'}->{'xdata'}->{'groups'}}, { '*' => 'read-only' };
        }

        $dashboard->{'file_version'} = 1 unless defined $dashboard->{'file_version'};
        if($dashboard->{'file_version'} == 1) {
            # convert label x/y from old dashboard versions which had them mixed up
            for my $id (keys %{$dashboard}) {
                my $tab = $dashboard->{$id};
                if($id =~ m|^tabpan\-tab_|mx and defined $tab->{'xdata'} and defined $tab->{'xdata'}->{'label'} and defined $tab->{'xdata'}->{'label'}->{'offsetx'} and defined $tab->{'xdata'}->{'label'}->{'offsety'}) {
                    my $offsetx = $tab->{'xdata'}->{'label'}->{'offsetx'};
                    my $offsety = $tab->{'xdata'}->{'label'}->{'offsety'};
                    $tab->{'xdata'}->{'label'}->{'offsety'} = $offsetx;
                    $tab->{'xdata'}->{'label'}->{'offsetx'} = $offsety;
                }
            }
            $dashboard->{'file_version'} = 2;
        }
    }
    $dashboard->{'file_version'} = DASHBOARD_FILE_VERSION;

    # merge runtime data
    my $runtime = {};
    my $runtimefile  = $c->config->{'var_path'}.'/panorama/'.$nr.'.tab.runtime';
    if(-e $runtimefile) {
       $runtime = Thruk::Utils::read_data_file($runtimefile);
    }
    for my $tab (keys %{$runtime}) {
        next if !defined $dashboard->{$tab};
        for my $key (keys %{$runtime->{$tab}}) {
            $dashboard->{$tab}->{'xdata'}->{$key} = $runtime->{$tab}->{$key} unless($scripted && defined $dashboard->{$tab}->{'xdata'}->{$key});
        }
    }

    if(!defined $dashboard->{'tab'})            { $dashboard->{'tab'}            = {}; }
    if(!defined $dashboard->{'tab'}->{'xdata'}) { $dashboard->{'tab'}->{'xdata'} = _get_default_tab_xdata($c) }
    # set default state type
    $dashboard->{'tab'}->{'xdata'}->{'state_type'} = 'soft' unless defined $dashboard->{'tab'}->{'xdata'}->{'state_type'};
    $dashboard->{'tab'}->{'xdata'}->{'owner'}    = $dashboard->{'user'};
    $dashboard->{'tab'}->{'xdata'}->{'backends'} = Thruk::Utils::backends_hash_to_list($c, $dashboard->{'tab'}->{'xdata'}->{'backends'});

    $dashboard->{'objects'} = scalar grep(/^tabpan-tab_/mx, keys %{$dashboard});
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
    my $file = $c->config->{'etc_path'}.'/panorama/'.$nr.'.tab';

    # super user have permission for all reports
    return ACCESS_OWNER if $c->stash->{'is_admin'};

    # does that dashboard already exist?
    if(-s $file) {
        $dashboard = Thruk::Utils::Panorama::load_dashboard($c, $nr, 1) unless $dashboard;
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
    $dashboard = load_dashboard($c, $nr, 1) unless $dashboard;
    unlink($dashboard->{'file'});
    # and also all backups
    unlink(glob($c->config->{'var_path'}.'/panorama/'.$nr.'.tab.*'));
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
