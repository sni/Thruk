package Thruk::Controller::main;

use warnings;
use strict;
use POSIX ();

use Thruk::Constants qw/:add_defaults :peer_states/;
use Thruk::Utils ();
use Thruk::Utils::Auth ();
use Thruk::Utils::Status ();

=head1 NAME

Thruk::Controller::main - Langing Page Controller

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=head2 index

=cut

##########################################################

sub index {
    my($c) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::Constants::ADD_CACHED_DEFAULTS);

    my($hostfilter, $servicefilter) = Thruk::Utils::Status::do_filter($c);
    return 1 if $c->stash->{'has_error'};

    $c->stash->{'title'}         = 'Thruk';
    $c->stash->{'infoBoxTitle'}  = 'Landing Page';
    $c->stash->{'page'}          = 'main';
    $c->stash->{'template'}      = 'main.tt';

    ############################################################################
    # contact statistics
    $c->stash->{'contacts'} = scalar @{$c->db->get_contacts(columns => ['name'])};

    ############################################################################
    # host statistics
    my $host_stats = $c->db->get_host_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter]);
    $c->stash->{'host_stats'} = $host_stats;

    # service statistics
    my $service_stats = $c->db->get_service_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter]);
    $c->stash->{'service_stats'} = $service_stats;

    # for hostgroups
    my $hosts = $c->db->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter], columns => ['groups']);
    my $hostgroups = {};

    for my $host ( @{$hosts} ) {
        for my $group ( @{$host->{'groups'}} ) {
            $hostgroups->{$group}++;
        }
    }

    ############################################################################
    # hostgroups
    my $top5_hg = [];
    my @hashkeys_hg = sort { $hostgroups->{$b} <=> $hostgroups->{$a} } keys %{$hostgroups};
    splice(@hashkeys_hg, 5) if scalar(@hashkeys_hg) > 5;

    for my $key (@hashkeys_hg) {
        push(@{$top5_hg}, { 'name' => $key, 'value' => $hostgroups->{$key} } )
    }

    $c->stash->{'hostgroups'} = $top5_hg;

    ############################################################################
    # notifications
    my $start = time() - 90000; # last 25h
    my $notificationData = $c->db->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), { -or => [ { 'type' => "HOST NOTIFICATION" }, { 'type' => "SERVICE NOTIFICATION" }  ] } , { time => { '>=' => $start }}  ],
                                            limit  => 1000000, # not using a limit here, makes mysql not use an index
                            );

    my $notificationHash = {};
    my $time = $start;
    while ($time <= time()) {
        my $curDate = POSIX::strftime("%F %H:00", localtime($time));
        $notificationHash->{$curDate} = 0;
        $time += 3600;
    }

    for my $notification ( @{$notificationData} ) {
        my $date = POSIX::strftime("%F %H:00", localtime($notification->{'time'}));
        $notificationHash->{$date}++;
    }

    my $notifications = [["x"], ["Notifications"]];
    my @keys = sort keys %{$notificationHash};
    @keys = splice(@keys, 1);
    for my $key (@keys) {
        push(@{$notifications->[0]}, $key);
        push(@{$notifications->[1]}, $notificationHash->{$key});
    }
    $c->stash->{'notifications'} = $notifications;

    ############################################################################
    # host and service problems
    my $problemhosts    = $c->db->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter, 'last_hard_state_change' => { ">" => 0 }, 'state' => 1, 'has_been_checked' => 1, 'acknowledged' => 0, 'hard_state' => 1, 'scheduled_downtime_depth' => 0 ], columns => ['name','state','plugin_output','last_hard_state_change'], sort => { ASC => 'last_hard_state_change' },  limit => 5 );
    my $problemservices = $c->db->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter, 'last_hard_state_change' => { ">" => 0 }, 'state' => { "!=" => 0 }, 'has_been_checked' => 1, 'acknowledged' => 0, 'state_type' => 1, 'scheduled_downtime_depth' => 0 ], columns => ['host_name','description','state','plugin_output','last_hard_state_change'], sort => { ASC => 'last_hard_state_change' }, limit => 5 );
    $c->stash->{'problemhosts'} = $problemhosts;
    $c->stash->{'problemservices'} = $problemservices;

    ############################################################################
    # backend statistics
    my $backend_stats = {
        'available' => 0,
        'enabled'   => 0,
        'running'   => 0,
        'down'      => 0,
    };
    for my $pd (@{$c->stash->{'backends'}}){
        $backend_stats->{'available'}++;
        if($c->stash->{'backend_detail'}->{$pd}->{'running'}) {
            $backend_stats->{'running'}++;
            $backend_stats->{'enabled'}++;
        } elsif($c->stash->{'backend_detail'}->{$pd}->{'disabled'} == HIDDEN_USER) {
            $backend_stats->{'disabled'}++;
        } elsif($c->stash->{'backend_detail'}->{$pd}->{'disabled'} == UNREACHABLE) {
            $backend_stats->{'down'}++;
            $backend_stats->{'enabled'}++;
        }
    }
    my $backend_gauge_data = [];
    push @{$backend_gauge_data}, ["Up",      $backend_stats->{'running'}] if $backend_stats->{'running'};
    push @{$backend_gauge_data}, ["Down",    $backend_stats->{'down'}]    if $backend_stats->{'down'};
    push @{$backend_gauge_data}, ["Enabled", 0]                           if $backend_stats->{'enabled'} == 0;
    $c->stash->{'backend_gauge_data'} = $backend_gauge_data;
    $c->stash->{'backend_stats'}      = $backend_stats;

    ############################################################################
    # host by backend
    my $hosts_by_backend = [];
    my $hosts_by_backend_data = $c->db->get_host_stats_by_backend(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter]);
    for my $row (values %{$hosts_by_backend_data}) {
        push @{$hosts_by_backend}, [$row->{'peer_name'}, $row->{'total'} ];
    }
    @{$hosts_by_backend} = sort { $b->[1] <=> $a->[1] } @{$hosts_by_backend};
    $c->stash->{'hosts_by_backend'} = $hosts_by_backend;

    ############################################################################
    my $style = $c->req->parameters->{'style'} || 'main';
    if($style ne 'main' ) {
        return if Thruk::Utils::Status::redirect_view($c, $style);
    }
    $c->stash->{style}      = $style;
    $c->stash->{substyle}   = 'service';
    $c->stash->{page_title} = '';

    Thruk::Utils::ssi_include($c);

    return 1;
}

##########################################################

1;
