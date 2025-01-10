package Thruk::Utils::Panorama;

use warnings;
use strict;
use Cpanel::JSON::XS;
use Exporter 'import';
use File::Copy qw/move/;

use Thruk::Backend::Manager ();
use Thruk::Utils ();
use Thruk::Utils::Log qw/:all/;
use Thruk::Utils::Panorama::Scripted ();

=head1 NAME

Thruk::Utils::Panorama - Thruk Utils for Panorama Dashboard

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

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

##########################################################
my @runtime_keys = qw/state stateHist stateDetails
                      currentPage pageSize totalCount
                    /;

our @EXPORT_OK = (qw/ACCESS_NONE ACCESS_READONLY ACCESS_READWRITE ACCESS_OWNER DASHBOARD_FILE_VERSION SOFT_STATE HARD_STATE/);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

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
        if($file =~ s/^.*\/([a-zA-Z_\-\d]+)\.tab$//mx) {
            my $nr = $1;
            next if $nr eq "0";
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
                    name        => $d->{'tab'}->{'xdata'}->{'title'} // '',
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

    $nr   =~ s/^pantab_//gmx;
    $file = $c->config->{'etc_path'}.'/panorama/'.$nr.'.tab' unless $file;

    # only numbers and letters allowed
    return if $nr !~ m/^\-?[a-zA-Z_\-\d]+$/gmx;

    # startpage can be overridden, only load original file if there is none in etc/
    if($nr eq "0" && !Thruk::Utils::IO::file_not_empty($file)) {
        $file = $c->config->{'plugin_path'}.'/plugins-enabled/panorama/0.tab';
    }

    set_is_admin($c);

    return unless Thruk::Utils::IO::file_not_empty($file);
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
                _warn(sprintf("non-executable scripted dashboard found in %s, forgot to: chmod +x %s", $file, $file));
                return;
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
    $dashboard->{'id'}       = 'pantab_'.$nr unless $nr =~ m/^\-\d+\$/mx;
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
    my $runtimefile  = get_runtime_file($c, $nr);
    my $runtime = Thruk::Utils::read_data_file($runtimefile, $c) // {};
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
    $dashboard->{'tab'}->{'xdata'}->{'file'}     = $nr.".tab";

    for my $key (keys %{$dashboard}) {
        if($key =~ m/_panlet_(\d+)$/mx) {
            my $newkey = "panlet_".$1;
            $dashboard->{$newkey} = delete $dashboard->{$key};
        }
    }

    # check for maintenance mode
    my $maintfile  = get_maint_file($c, $nr);
    if(Thruk::Utils::IO::file_exists($maintfile)) {
        my $maintenance = Thruk::Utils::IO::json_lock_retrieve($maintfile);
        $dashboard->{'maintenance'} = $maintenance->{'maintenance'};
    }

    $dashboard->{'objects'} = scalar grep(/^panlet_/mx, keys %{$dashboard});
    return $dashboard;
}

##########################################################

=head2 save_dashboard

    save_dashboard($c, $dashboard, [$extra_settings])

save dashboard to disk

returns $dashboard or undef on errors

=cut
sub save_dashboard {
    my($c, $dashboard, $extra_settings) = @_;

    my $nr   = delete $dashboard->{'id'};
    $nr      =~ s/^pantab_//gmx;
    my $file = $c->config->{'etc_path'}.'/panorama/'.$nr.'.tab';

    my $existing = $nr eq 'new' ? $dashboard : load_dashboard($c, $nr, 1);
    return unless is_authorized_for_dashboard($c, $nr, $existing) >= ACCESS_READWRITE;

    # do not overwrite scripted dashboards
    return if $nr eq "0"; # may be non-numeric too
    return if $dashboard->{'scripted'};
    return if -x $file;

    if($nr eq 'new') {
        # find next free number
        $nr = $c->config->{'Thruk::Plugin::Panorama'}->{'new_files_start_at'} || 1;
        $file = $c->config->{'etc_path'}.'/panorama/'.$nr.'.tab';
        while(Thruk::Utils::IO::file_exists($file)) {
            $nr++;
            $file = $c->config->{'etc_path'}.'/panorama/'.$nr.'.tab';
        }
    }

    # preserve some settings
    if($existing) {
        $dashboard->{'user'} = $existing->{'user'} || $c->stash->{'remote_user'};
    }

    if($extra_settings) {
        for my $key (keys %{$extra_settings}) {
            $dashboard->{$key} = $extra_settings->{$key};
        }
    }

    delete $dashboard->{'version'}; # leftover from imported dashboard
    delete $dashboard->{'nr'};
    delete $dashboard->{'id'};
    delete $dashboard->{'file'};
    delete $dashboard->{'locked'};
    delete $dashboard->{'tab'}->{'xdata'}->{'owner'};
    delete $dashboard->{'tab'}->{'xdata'}->{''};
    my $newfile = delete $dashboard->{'tab'}->{'xdata'}->{'file'};
    delete $dashboard->{'tab'}->{'readonly'};
    delete $dashboard->{'tab'}->{'user'};
    delete $dashboard->{'tab'}->{'ts'};
    delete $dashboard->{'tab'}->{'public'};
    delete $dashboard->{'tab'}->{'scripted'};

    # set file version
    $dashboard->{'file_version'} = DASHBOARD_FILE_VERSION;

    if($dashboard->{'tab'}->{'xdata'}->{'backends'}) {
        $dashboard->{'tab'}->{'xdata'}->{'backends'} = Thruk::Utils::backends_list_to_hash($c, $dashboard->{'tab'}->{'xdata'}->{'backends'});
    }

    for my $key (sort keys %{$dashboard}) {
        my $newkey = $key;
        $newkey =~ s/^.*_(panlet_\d+)$/$1/gmx;
        $dashboard->{$newkey} = delete $dashboard->{$key};
    }

    # save runtime data in extra file
    save_runtime_file($c, $dashboard, undef, $nr);

    Thruk::Utils::write_data_file($file, $dashboard, 1);
    Thruk::Utils::backup_data_file($c->config->{'etc_path'}.'/panorama/'.$nr.'.tab', $c->config->{'var_path'}.'/panorama/'.$nr.'.tab', 'a', 5, 600);
    $dashboard->{'nr'} = $nr;
    $dashboard->{'id'} = 'pantab_'.$nr;
    $dashboard->{'ts'} = [stat($file)]->[9];

    my $filename = $nr.'.tab';
    if($newfile && $newfile ne $filename) {
        $dashboard = move_dashboard($c, $dashboard, $filename, $newfile);
    }

    return $dashboard;
}

##########################################################

=head2 extract_runtime_data

    extract_runtime_data($dashboard)

returns runtime data for given dashboard

=cut
sub extract_runtime_data {
    my($dashboard) = @_;
    my $runtime = {};
    for my $tab (keys %{$dashboard}) {
        next unless ref $dashboard->{$tab} eq 'HASH';
        delete $dashboard->{$tab}->{""};
        for my $key (@runtime_keys) {
            if(defined $dashboard->{$tab}->{'xdata'} && defined $dashboard->{$tab}->{'xdata'}->{$key}) {
                $runtime->{$tab}->{$key} = delete $dashboard->{$tab}->{'xdata'}->{$key};
            }
        }
    }
    return($runtime);
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
    if(Thruk::Utils::IO::file_not_empty($file)) {
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
            if($name eq '*') {
                $access = $lvl if $lvl > $access;
                next;
            }
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

=head2 move_dashboard

    move_dashboard($c, $dashboard, $filename, $newfile)

rename dashboard file and return new dashboard data

=cut
sub move_dashboard {
    my($c, $dashboard, $filename, $newfile) = @_;

    if($newfile !~ m/^[a-zA-Z0-9_\-]+\.tab$/gmx) {
        Thruk::Utils::set_message($c, 'fail_message', 'Renaming dashboard failed, invalid filename.');
        return($dashboard);
    }

    my $newnr = $newfile;
       $newnr =~ s/\.tab//gmx;
    my $oldnr = $dashboard->{'id'};
       $oldnr =~ s/^pantab_//gmx;

    if(Thruk::Utils::IO::file_exists($c->config->{'etc_path'}.'/panorama/'.$newfile)) {
        Thruk::Utils::set_message($c, 'fail_message', 'Renaming dashboard failed, '.$newfile.' does already exist.');
        return($dashboard);
    }
    for my $folder ($c->config->{'etc_path'}.'/panorama', $c->config->{'var_path'}.'/panorama') {
        for my $file (glob($folder.'/'.$oldnr.'.*')) {
            my $movedfile = $file;
            $movedfile =~ s/^.*\///gmx;
            $movedfile =~ s/^\Q$oldnr\E/\Q$newnr\E/gmx;
            move($file, $folder.'/'.$movedfile);
        }
    }
    Thruk::Utils::set_message($c, 'success_message', 'Renamed dashboard to: '.$newfile);
    return(load_dashboard($c, $newnr));
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

=head2 save_runtime_file

    save_runtime_file($c, $dashboard, [$merge_states])

return nothing

=cut
sub save_runtime_file {
    my($c, $dashboard, $merge_states, $nr) = @_;
    $nr = $dashboard->{'nr'} unless defined $nr;

    my $runtime = extract_runtime_data($dashboard);

    if($merge_states) {
        for my $id (keys %{$runtime}, keys %{$merge_states}) {
            my $saveid = $id;
            $saveid =~ s/^pantab_.*?_(panlet_\d+)$/$1/gmx;
            for my $key (@runtime_keys) {
                $runtime->{$saveid}->{$key} = $merge_states->{$id}->{$key} if defined $merge_states->{$id}->{$key};
            }
        }
    }

    my $runtime_file = get_runtime_file($c, $nr);
    Thruk::Utils::write_data_file($runtime_file, $runtime, 1);
    Thruk::Utils::IO::touch($runtime_file); # update timestamp because thats what we use for last_used

    return;
}

##########################################################

1;
