package Thruk::Utils::Panorama;

use strict;
use warnings;
use Thruk::Utils;
use Thruk::Utils::Panorama::Scripted;
use Thruk::Utils::Log qw/:all/;
use Cpanel::JSON::XS;

=head1 NAME

Thruk::Utils::Panorama - Thruk Utils for Panorama Dashboard

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

#use Thruk::Timer qw/timing_breakpoint/;

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

return list of dashboards. Type can be 'public', 'my' or 'all'

=cut
sub get_dashboard_list {
    my($c, $type, $full) = @_;

    set_is_admin($c);

    # returns wrong list of public dashboards otherwise
    my $orig_is_admin;
    if($type eq 'public') {
        $orig_is_admin = $c->stash->{'is_admin'};
        $c->stash->{'is_admin'} = 0;
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
                if($full) {
                    push @{$dashboards}, $d;
                    next;
                }
                my $perm_grw = [];
                my $perm_gro = [];
                for my $group (@{$d->{'tab'}->{'xdata'}->{'groups'}}) {
                    my $name = (keys %{$group})[0];
                    if($group->{$name} eq 'read-write') {
                        push(@{$perm_grw}, $name);
                    } else {
                        push(@{$perm_gro}, $name);
                    }
                }
                my $perm_rw = "";
                my $perm_ro = "";
                if(scalar @{$perm_grw} > 0) {
                    $perm_rw .= "groups: ".join(", ", @{$perm_grw});
                }
                if(scalar @{$perm_gro} > 0) {
                    $perm_ro .= "groups: ".join(", ", @{$perm_gro});
                }

                my $perm_urw = [];
                my $perm_uro = [];
                for my $usr (@{$d->{'tab'}->{'xdata'}->{'users'}}) {
                    my $name = (keys %{$usr})[0];
                    if($usr->{$name} eq 'read-write') {
                        push(@{$perm_urw}, $name);
                    } else {
                        push(@{$perm_uro}, $name);
                    }
                }
                if(scalar @{$perm_urw} > 0) {
                    $perm_rw .= " - " if $perm_rw;
                    $perm_rw .= "users: ".join(", ", @{$perm_urw});
                }
                if(scalar @{$perm_uro} > 0) {
                    $perm_ro .= " - " if $perm_ro;
                    $perm_ro .= "users: ".join(", ", @{$perm_uro});
                }
                push @{$dashboards}, {
                    id          => $d->{'id'},
                    nr          => $d->{'nr'},
                    name        => $d->{'tab'}->{'xdata'}->{'title'},
                    user        => $d->{'user'},
                    perm_rw     => $perm_rw,
                    perm_ro     => $perm_ro,
                    readonly    => $d->{'readonly'} ? Cpanel::JSON::XS::true : Cpanel::JSON::XS::false,
                    description => $d->{'description'} || '',
                    objects     => $d->{'objects'},
                    ts          => $d->{'ts'},
                };
            }
        } else {
            _warn("panorama dashboard with unusual name skipped: ".$file);
        }
    }

    # restore admin flag
    if($type eq 'public') {
        $c->stash->{'is_admin'} = $orig_is_admin;
    }

    $dashboards = Thruk::Backend::Manager::sort_result({}, $dashboards, 'name');
    return $dashboards;
}

##########################################################

=head2 load_dashboard

    load_dashboard($c, $nr, [$meta_data_only])

return dashboard data.

=cut
sub load_dashboard {
    my($c, $nr, $meta_data_only, $file) = @_;
    $nr       =~ s/^pantab_//gmx;
    $file  = $c->config->{'etc_path'}.'/panorama/'.$nr.'.tab' unless $file;

    # only numbers allowed
    return if $nr !~ m/^\-?\d+$/gmx;

    # startpage can be overridden, only load original file if there is none in etc/
    if($nr == 0 && !-s $file) {
        $file = $c->config->{'plugin_path'}.'/plugins-enabled/panorama/0.tab';
    }

    set_is_admin($c);

    return unless -s $file;
    my $dashboard;
    my $scripted = 0;
    if(-x $file) {
        # scripted dashboard
        $dashboard = Thruk::Utils::Panorama::Scripted::load_dashboard($c, $nr, $file, $meta_data_only);
        $scripted = 1;
    } else {
        # static dashboard
        $dashboard = Thruk::Utils::read_data_file($file, $c);
        if(!defined $dashboard) {
            my $content = Thruk::Utils::IO::read($file);
            if($content =~ m/^\#\s*title:/mx) {
                _warn("non-executable scripted dashboard found in $file, forgot to chmod +x");
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
    $dashboard->{'id'}       = 'pantab_'.$nr unless $nr < 0;
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
                if($id =~ m%^tabpan\-tab_%mx and defined $tab->{'xdata'} and defined $tab->{'xdata'}->{'label'} and defined $tab->{'xdata'}->{'label'}->{'offsetx'} and defined $tab->{'xdata'}->{'label'}->{'offsety'}) {
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
    my $runtime      = {};
    my $runtimefile  = get_runtime_file($c, $nr);
    if(-s $runtimefile) {
        $runtime = Thruk::Utils::read_data_file($runtimefile, $c);
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

    for my $key (keys %{$dashboard}) {
        if($key =~ m/_panlet_(\d+)$/mx) {
            my $newkey = "panlet_".$1;
            $dashboard->{$newkey} = delete $dashboard->{$key};
        }
    }

    # check for maintenance mode
    my $maintfile  = get_maint_file($c, $nr);
    if(-e $maintfile) {
        my $maintenance = Thruk::Utils::IO::json_lock_retrieve($maintfile);
        $dashboard->{'maintenance'} = $maintenance->{'maintenance'};
    }

    $dashboard->{'objects'} = scalar grep(/^panlet_/mx, keys %{$dashboard});
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
    $nr =~ s/^pantab_//gmx;
    my $file = $c->config->{'etc_path'}.'/panorama/'.$nr.'.tab';

    # super user have permission for all reports
    return ACCESS_OWNER if $c->stash->{'is_admin'};

    # does that dashboard already exist?
    if(-s $file) {
        $dashboard = load_dashboard($c, $nr, 1) unless $dashboard;
        if($dashboard->{'user'} eq $c->stash->{'remote_user'}) {
            return ACCESS_READONLY if $c->stash->{'readonly'};
            return ACCESS_OWNER;
        }
        # access from contactgroups
        my $access = ACCESS_NONE;
        my $contactgroups = $c->user->{'groups'} || [];
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
        my $username = $c->user->{'username'};
        $dashboard->{'tab'}->{'xdata'}->{'users'} = [] unless defined $dashboard->{'tab'}->{'xdata'}->{'users'};
        for my $user (@{$dashboard->{'tab'}->{'xdata'}->{'users'}}) {
            my $name = (keys %{$user})[0];
            next unless $name eq $username;
            my $lvl  = $user->{$name} eq 'read-write' ? ACCESS_READWRITE : ACCESS_READONLY;
            $access = $lvl;
            last;
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

=head2 get_runtime_file

    get_runtime_file($c, $nr)

return runtime filename for given dashboard number and current user

=cut
sub get_runtime_file {
    my($c, $nr) = @_;
    my $user = '';
    if(!$c->stash->{'is_admin'}) {
        # save runtime data to user file
        $user = $c->stash->{'remote_user'};
        $user =~ s/[^a-zA-Z\d_\-]/_/gmx;
        $user = $user.'.';
    }
    return($c->config->{'var_path'}.'/panorama/'.$nr.'.tab.'.$user.'runtime');
}

##########################################################

=head2 get_maint_file

    get_maint_file($c, $nr)

return maintenance filename for given dashboard number

=cut
sub get_maint_file {
    my($c, $nr) = @_;
    return($c->config->{'var_path'}.'/panorama/'.$nr.'.tab.maint');
}

##########################################################

=head2 set_is_admin

    set_is_admin($c)

return nothing

=cut
sub set_is_admin {
    my($c) = @_;
    return if defined $c->stash->{'is_admin'};
    $c->stash->{'is_admin'} = 0;
    if($c->check_user_roles('admin')) {
        $c->stash->{'is_admin'} = 1;
    }
    return;
}
##########################################################

1;
