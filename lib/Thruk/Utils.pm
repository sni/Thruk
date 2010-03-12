package Thruk::Utils;

=head1 NAME

Thruk::Utils - Utilities Collection for Thruk

=head1 DESCRIPTION

Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Config::General;
use Carp;
use Data::Dumper;
use Digest::MD5  qw(md5_hex);
use Date::Calc qw/Localtime Mktime Monday_of_Week Week_of_Year Today/;
use Data::Page;
use Monitoring::Livestatus::MULTI;


##############################################
=head1 METHODS

=cut

##############################################

=head2 get_auth_filter

  my $filter_string = get_auth_filter('hosts');

returns a filter which can be used for authorization

=cut
sub get_auth_filter {
    my $c    = shift;
    my $type = shift;

    return("") if $type eq 'status';

    # if authentication is completly disabled
    if($c->{'cgi_cfg'}->{'use_authentication'} == 0 and $c->{'cgi_cfg'}->{'use_ssl_authentication'} == 0) {
        return("");
    }

    # if the user has access to everthing
    if($c->check_user_roles('authorized_for_all_hosts') and $c->check_user_roles('authorized_for_all_services')) {
        return("");
    }

    # host authorization
    if($type eq 'hosts') {
        if($c->check_user_roles('authorized_for_all_hosts')) {
            return("");
        }
        return("Filter: contacts >= ".$c->user->get('username'));
    }

    # hostgroups authorization
    elsif($type eq 'hostgroups') {
        return("");
    }

    # service authorization
    elsif($type eq 'services') {
        if($c->check_user_roles('authorized_for_all_services')) {
            return("");
        }
        if(Thruk->config->{'use_strict_host_authorization'}) {
            return("Filter: contacts >= ".$c->user->get('username')."\n");
        } else {
            return("Filter: contacts >= ".$c->user->get('username')."\nFilter: host_contacts >= ".$c->user->get('username')."\nOr: 2");
        }
    }

    # servicegroups authorization
    elsif($type eq 'servicegroups') {
        return("");
    }

    # servicegroups authorization
    elsif($type eq 'timeperiods') {
        return("");
    }

    # comments / downtimes authorization
    elsif($type eq 'comments' or $type eq 'downtimes') {
        my @filter;
        if(!$c->check_user_roles('authorized_for_all_services')) {
            push @filter, "Filter: service_contacts >= ".$c->user->get('username')."\n";
        }
        if(!$c->check_user_roles('authorized_for_all_hosts')) {
            push @filter, "Filter: host_contacts >= ".$c->user->get('username')."\n";
        }
        if(scalar @filter == 0) {
            return("");
        }
        if(scalar @filter == 1) {
            return($filter[0]);
        }
        return(join("\n", @filter)."\nOr: ".scalar @filter);
    }

    # logfile authorization
    elsif($type eq 'log') {
        my @filter;
        if(!$c->check_user_roles('authorized_for_all_services')) {
            push @filter, "Filter: current_service_contacts >= ".$c->user->get('username')."\nFilter: current_service_description != \nAnd: 2";
        }
        if(!$c->check_user_roles('authorized_for_all_hosts')) {
            if(Thruk->config->{'use_strict_host_authorization'}) {
                # only allowed for the host itself, not the services
                push @filter, "Filter: current_host_contacts >= ".$c->user->get('username')."\nFilter: current_service_description = \nAnd: 2\n";
            } else {
                # allowed for all hosts and its services
                push @filter, "Filter: current_host_contacts >= ".$c->user->get('username')."\n";
            }
        }
        if(scalar @filter == 0) {
            return("");
        }
        if(scalar @filter == 1) {
            return($filter[0]);
        }
        return(join("\n", @filter)."\nOr: ".scalar @filter);
    }

    else {
        croak("type $type not supported");
    }

    croak("cannot authorize query");
    return;
}


##############################################

=head2 filter_duration

  my $string = filter_duration($seconds);

formats a duration into the
format: 0d 0h 29m 43s

=cut
sub filter_duration {
    my $duration = shift;
    my $withdays = shift;

    croak("undef duration in filter_duration(): ".$duration) unless defined $duration;
    $duration = $duration * -1 if $duration < 0;

    $withdays = 1 unless defined $withdays;

    croak("unknown withdays in filter_duration(): ".$withdays) if($withdays != 0 and $withdays != 1 and $withdays != 2);

    if($duration < 0) { $duration = time() + $duration; }

    my $days    = 0;
    my $hours   = 0;
    my $minutes = 0;
    my $seconds = 0;
    if($withdays == 1) {
        if($duration >= 86400) {
            $days     = int($duration/86400);
            $duration = $duration%86400;
        }
    }
    if($duration >= 3600) {
        $hours    = int($duration/3600);
        $duration = $duration%3600;
    }
    if($duration >= 60) {
        $minutes  = int($duration/60);
        $duration = $duration%60;
    }
    $seconds = $duration;

    if($withdays == 1) {
        return($days."d ".$hours."h ".$minutes."m ".$seconds."s");
    }
    if($withdays == 2) {
        return($minutes."min ".$seconds."sec");
    }
    return($hours."h ".$minutes."m ".$seconds."s");
}


##############################################

=head2 filter_nl2br

  my $string = filter_nl2br($string);

replace newlines with linebreaks

=cut
sub filter_nl2br {
    my $string = shift;
    $string =~ s/\n/<br\ \/>/gmx;
    $string =~ s/\r//gmx;
    $string =~ s/\\n/<br\ \/>/gmx;
    return $string;
}


##############################################

=head2 filter_sprintf

  my $string = sprintf($format, $list)

wrapper around the internal sprintf

=cut
sub filter_sprintf {
    my $format = shift;
    local $SIG{__WARN__} = sub { Carp::cluck(@_); };
    return sprintf $format, @_;
}


######################################

=head2 get_cgi_cfg

  my $conf = get_cgi_cfg($c);

parse and return the cgi.cg as hash ref

=cut
sub get_cgi_cfg {
    my $c = shift;

    $c->stats->profile(begin => "Utils::get_cgi_cfg()");

    # read only once per request
    our(%config, $cgi_config_already_read);

    return(\%config) if $cgi_config_already_read;

    my $file = $c->config->{'cgi_cfg'};

    if(!defined $file or $file eq '') {
        $c->config->{'cgi_cfg'} = 'undef';
        $c->log->error("cgi.cfg not set");
        $c->error("cgi.cfg not set");
        $c->detach('/error/index/4');
    }
    if(! -r $file) {
        $c->log->error("cgi.cfg not readable: ".$!);
        $c->error("cgi.cfg not readable: ".$!);
        $c->detach('/error/index/4');
    }

    $cgi_config_already_read = 1;
    my $conf = new Config::General($file);
    %config  = $conf->getall;

    $c->stats->profile(end => "Utils::get_cgi_cfg()");

    return(\%config);
}


######################################

=head2 get_livestatus

  my $conf = get_livestatus($c)

return the livestatus object

=cut
sub get_livestatus {
    my $c                 = shift;
    my $disabled_backends = shift;

    $c->stats->profile(begin => "Utils::get_livestatus()");

    our $livestatus;

    if(defined $livestatus) {
        $c->log->debug("got livestatus from cache");
        $livestatus->enable();
        if(defined $disabled_backends) {
            for my $key (keys %{$disabled_backends}) {
                if($disabled_backends->{$key} == 2) {
                    $c->log->debug("disabled livestatus backend: $key");
                    $livestatus->disable($key);
                }
            }
        }
        return($livestatus);
    }
    $c->log->debug("creating new livestatus");

    my $livestatus_config = Thruk::Utils::get_livestatus_conf($c);
    if(!defined $livestatus_config or !defined $livestatus_config->{'peer'} ) {
        $c->detach("/error/index/14");
    }

    if(defined $livestatus_config->{'verbose'} and $livestatus_config->{'verbose'}) {
        $livestatus_config->{'logger'} = $c->log
    }
    $livestatus = Monitoring::Livestatus::MULTI->new(%{$livestatus_config});

    if(defined $disabled_backends) {
        for my $key (keys %{$disabled_backends}) {
            if($disabled_backends->{$key} == 2) {
                $c->log->debug("disabled livestatus backend: $key");
                $livestatus->disable($key);
            }
        }
    }

    $c->stats->profile(end => "Utils::get_livestatus()");

    return($livestatus);
}


########################################

=head2 sort

  sort($c, $data, \@keys, $order)

sort a array of hashes by hash keys

=cut
sub sort {
    my $c     = shift;
    my $data  = shift;
    my $key   = shift;
    my $order = shift;
    my @sorted;

    if(!defined $key) { $c->error('missing options in sort()'); }

    $c->stats->profile(begin => "Utils::sort()") if defined $c;

    $order = "ASC" if !defined $order;

    return if !defined $data;
    return if scalar @{$data} == 0;

    my @keys;
    if(ref($key) eq 'ARRAY') {
        @keys = @{$key};
    } else {
        @keys = ($key);
    }

    my @compares;
    for my $key (@keys) {
        # sort numeric
        if(defined $data->[0]->{$key} and $data->[0]->{$key} =~ m/^\d+$/xm) {
            push @compares, '$a->{'.$key.'} <=> $b->{'.$key.'}';
        }
        # sort alphanumeric
        else {
            push @compares, '$a->{'.$key.'} cmp $b->{'.$key.'}';
        }
    }
    my $sortstring = join(' || ', @compares);
    $c->log->debug("ordering by: ".$sortstring) if defined $c;

    ## no critic
    no warnings; # sorting by undef values generates lots of errors
    if(uc $order eq 'ASC') {
        eval '@sorted = sort { '.$sortstring.' } @{$data};';
    } else {
        eval '@sorted = reverse sort { '.$sortstring.' } @{$data};';
    }
    use warnings;
    ## use critic

    $c->stats->profile(end => "Utils::sort()") if defined $c;

    return(\@sorted);
}


########################################

=head2 remove_duplicates

  remove_duplicates($c, $data)

removes duplicate entries from a array of hashes

=cut
sub remove_duplicates {
    my $c    = shift;
    my $data = shift;

    # only needed when using multiple backends
    return $data unless scalar @{$c->stash->{'backends'}} > 1;

    $c->stats->profile(begin => "Utils::remove_duplicates()");

    # calculate md5 sums
    my $uniq = {};
    for my $dat (@{$data}) {
        my $peer_key  = $dat->{'peer_key'};  delete $dat->{'peer_key'};
        my $peer_name = $dat->{'peer_name'}; delete $dat->{'peer_name'};
        my $peer_addr = $dat->{'peer_addr'}; delete $dat->{'peer_addr'};
        my $md5 = md5_hex(join(';', values %{$dat}));
        if(!defined $uniq->{$md5}) {
            $dat->{'peer_key'}  = $peer_key;
            $dat->{'peer_name'} = $peer_name;
            $dat->{'peer_addr'} = $peer_addr;

            $uniq->{$md5} = {
                              'data'      => $dat,
                              'peer_key'  => [ $peer_key ],
                              'peer_name' => [ $peer_name ],
                              'peer_addr' => [ $peer_addr ],
                            };
        } else {
            push @{$uniq->{$md5}->{'peer_key'}},  $peer_key;
            push @{$uniq->{$md5}->{'peer_name'}}, $peer_name;
            push @{$uniq->{$md5}->{'peer_addr'}}, $peer_addr;
        }
    }

    my $return = [];
    for my $data (values %{$uniq}) {
        $data->{'data'}->{'backend'} = {
            'peer_key'  => $data->{'peer_key'},
            'peer_name' => $data->{'peer_name'},
            'peer_addr' => $data->{'peer_addr'},
        };
        push @{$return}, $data->{'data'};

    }

    $c->stats->profile(end => "Utils::remove_duplicates()");
    return($return);
}


########################################

=head2 get_livestatus_conf

  get_livestatus_conf($c)

returns config for livestatus backends

=cut
sub get_livestatus_conf {
    my $c = shift;

    my $livestatus_config = Thruk->config->{'Monitoring::Livestatus'};

    if(defined $livestatus_config) {
        # with only on peer, we have to convert to an array
        if(defined $livestatus_config->{'peer'} and ref $livestatus_config->{'peer'} eq 'HASH') {
            my $peer = $livestatus_config->{'peer'};
            delete $livestatus_config->{'peer'};
            push @{$livestatus_config->{'peer'}}, $peer;
        }
    }

    $c->log->debug("livestatus config: ".Dumper($livestatus_config));

    return($livestatus_config);
}


############################################################

=head2 get_service_execution_stats_old

  my $stats = get_service_execution_stats_old($c);

Returns a hash with statistical data, calculation is obsolete
with newer livestatus versions

=cut
sub get_service_execution_stats_old {
    my $c = shift;

    $c->stats->profile(begin => "Utils::get_service_execution_stats_old()");

    my $now    = time();
    my $min1   = $now - 60;
    my $min5   = $now - 300;
    my $min15  = $now - 900;
    my $min60  = $now - 3600;

    my $check_stats;
    for my $type (qw{hosts services}) {
        $check_stats->{$type} = {
            'active_sum'                => 0,
            'active_1_min'              => 0,
            'active_5_min'              => 0,
            'active_15_min'             => 0,
            'active_60_min'             => 0,
            'active_all_min'            => 0,

            'active_1_min_perc'         => 0,
            'active_5_min_perc'         => 0,
            'active_15_min_perc'        => 0,
            'active_60_min_perc'        => 0,
            'active_all_min_perc'       => 0,

            'execution_time_min'        => undef,
            'execution_time_max'        => undef,
            'execution_time_avg'        => 0,
            'execution_time_sum'        => 0,

            'latency_min'               => undef,
            'latency_max'               => undef,
            'latency_avg'               => 0,
            'latency_sum'               => 0,

            'active_state_change_min'   => undef,
            'active_state_change_max'   => undef,
            'active_state_change_avg'   => 0,
            'active_state_change_sum'   => 0,

            'passive_sum'               => 0,
            'passive_1_min'             => 0,
            'passive_5_min'             => 0,
            'passive_15_min'            => 0,
            'passive_60_min'            => 0,
            'passive_all_min'           => 0,

            'passive_1_min_perc'        => 0,
            'passive_5_min_perc'        => 0,
            'passive_15_min_perc'       => 0,
            'passive_60_min_perc'       => 0,
            'passive_all_min_perc'      => 0,

            'passive_state_change_min'  => undef,
            'passive_state_change_max'  => undef,
            'passive_state_change_avg'  => 0,
            'passive_state_change_sum'  => 0,
        };

        my $tmp_data = $c->{'live'}->selectall_arrayref("GET $type\n".Thruk::Utils::get_auth_filter($c, $type)."\nColumns: execution_time has_been_checked last_check latency percent_state_change check_type", { Slice => 1, AddPeer => 1 });
        if($tmp_data) {
            for my $data (@{$tmp_data}) {
                my $minall = $c->stash->{'pi_detail'}->{$data->{'peer_key'}}->{'program_start'};

                if($data->{'check_type'} == 0) {
                    $check_stats->{$type}->{'active_sum'}++;
                } else {
                    $check_stats->{$type}->{'passive_sum'}++;
                }

                if($data->{'has_been_checked'}) {

                    # active checks
                    if($data->{'check_type'} == 0) {
                        if($data->{'last_check'} >= $min1)   { $check_stats->{$type}->{'active_1_min'}++;   }
                        if($data->{'last_check'} >= $min5)   { $check_stats->{$type}->{'active_5_min'}++;   }
                        if($data->{'last_check'} >= $min15)  { $check_stats->{$type}->{'active_15_min'}++;  }
                        if($data->{'last_check'} >= $min60)  { $check_stats->{$type}->{'active_60_min'}++;  }
                        if($data->{'last_check'} >= $minall) { $check_stats->{$type}->{'active_all_min'}++; }

                        # sum up all values to calculate averages later
                        $check_stats->{$type}->{'execution_time_sum'}       += $data->{'execution_time'};
                        $check_stats->{$type}->{'latency_sum'}              += $data->{'latency'};
                        $check_stats->{$type}->{'active_state_change_sum'}  += $data->{'percent_state_change'};

                        # check min/max values
                        if(!defined $check_stats->{$type}->{'execution_time_min'} or $check_stats->{$type}->{'execution_time_min'} > $data->{'execution_time'}) {
                            $check_stats->{$type}->{'execution_time_min'} = $data->{'execution_time'};
                        }
                        if(!defined $check_stats->{$type}->{'execution_time_max'} or $check_stats->{$type}->{'execution_time_max'} < $data->{'execution_time'}) {
                            $check_stats->{$type}->{'execution_time_max'} = $data->{'execution_time'};
                        }

                        if(!defined $check_stats->{$type}->{'latency_min'} or $check_stats->{$type}->{'latency_min'} > $data->{'latency'}) {
                            $check_stats->{$type}->{'latency_min'} = $data->{'latency'};
                        }
                        if(!defined $check_stats->{$type}->{'latency_max'} or $check_stats->{$type}->{'latency_max'} < $data->{'latency'}) {
                            $check_stats->{$type}->{'latency_max'} = $data->{'latency'};
                        }

                        if(!defined $check_stats->{$type}->{'active_state_change_min'} or $check_stats->{$type}->{'active_state_change_min'} > $data->{'percent_state_change'}) {
                            $check_stats->{$type}->{'active_state_change_min'} = $data->{'percent_state_change'};
                        }
                        if(!defined $check_stats->{$type}->{'active_state_change_max'} or $check_stats->{$type}->{'active_state_change_max'} < $data->{'percent_state_change'}) {
                            $check_stats->{$type}->{'active_state_change_max'} = $data->{'percent_state_change'};
                        }
                    }
                    # passive checks
                    else {
                        $check_stats->{$type}->{'passive_sum'}++;
                        if($data->{'last_check'} >= $min1)   { $check_stats->{$type}->{'passive_1_min'}++;   }
                        if($data->{'last_check'} >= $min5)   { $check_stats->{$type}->{'passive_5_min'}++;   }
                        if($data->{'last_check'} >= $min15)  { $check_stats->{$type}->{'passive_15_min'}++;  }
                        if($data->{'last_check'} >= $min60)  { $check_stats->{$type}->{'passive_60_min'}++;  }
                        if($data->{'last_check'} >= $minall) { $check_stats->{$type}->{'passive_all_min'}++; }

                        # sum up all values to calculate averages later
                        $check_stats->{$type}->{'passive_state_change_sum'} += $data->{'percent_state_change'};

                        # check min/max values
                        if(!defined $check_stats->{$type}->{'passive_state_change_min'} or $check_stats->{$type}->{'passive_state_change_min'} > $data->{'percent_state_change'}) {
                            $check_stats->{$type}->{'active_state_change_min'} = $data->{'percent_state_change'};
                        }
                        if(!defined $check_stats->{$type}->{'passive_state_change_max'} or $check_stats->{$type}->{'passive_state_change_max'} < $data->{'percent_state_change'}) {
                            $check_stats->{$type}->{'passive_state_change_max'} = $data->{'percent_state_change'};
                        }
                    }
                }
            }
        }

        # calculate averages
        if($check_stats->{$type}->{'active_sum'} > 0) {
            $check_stats->{$type}->{'execution_time_avg'}       = $check_stats->{$type}->{'execution_time_sum'}       / $check_stats->{$type}->{'active_sum'};
            $check_stats->{$type}->{'latency_avg'}              = $check_stats->{$type}->{'latency_sum'}              / $check_stats->{$type}->{'active_sum'};
            $check_stats->{$type}->{'active_state_change_avg'}  = $check_stats->{$type}->{'active_state_change_sum'}  / $check_stats->{$type}->{'active_sum'};
        } else {
            $check_stats->{$type}->{'execution_time_avg'}       = 0;
            $check_stats->{$type}->{'latency_avg'}              = 0;
            $check_stats->{$type}->{'active_state_change_avg'}  = 0;
        }
        if($check_stats->{$type}->{'passive_sum'} > 0) {
            $check_stats->{$type}->{'passive_state_change_avg'} = $check_stats->{$type}->{'passive_state_change_sum'} / $check_stats->{$type}->{'passive_sum'};
        } else {
            $check_stats->{$type}->{'passive_state_change_avg'} = 0;
        }

        # calculate percentages
        if($check_stats->{$type}->{'active_sum'} > 0) {
            $check_stats->{$type}->{'active_1_min_perc'}   = $check_stats->{$type}->{'active_1_min'}   / $check_stats->{$type}->{'active_sum'} * 100;
            $check_stats->{$type}->{'active_5_min_perc'}   = $check_stats->{$type}->{'active_5_min'}   / $check_stats->{$type}->{'active_sum'} * 100;
            $check_stats->{$type}->{'active_15_min_perc'}  = $check_stats->{$type}->{'active_15_min'}  / $check_stats->{$type}->{'active_sum'} * 100;
            $check_stats->{$type}->{'active_60_min_perc'}  = $check_stats->{$type}->{'active_60_min'}  / $check_stats->{$type}->{'active_sum'} * 100;
            $check_stats->{$type}->{'active_all_min_perc'} = $check_stats->{$type}->{'active_all_min'} / $check_stats->{$type}->{'active_sum'} * 100;
        }

        if($check_stats->{$type}->{'passive_sum'} > 0) {
            $check_stats->{$type}->{'passive_1_min_perc'}   = $check_stats->{$type}->{'passive_1_min'}   / $check_stats->{$type}->{'passive_sum'} * 100;
            $check_stats->{$type}->{'passive_5_min_perc'}   = $check_stats->{$type}->{'passive_5_min'}   / $check_stats->{$type}->{'passive_sum'} * 100;
            $check_stats->{$type}->{'passive_15_min_perc'}  = $check_stats->{$type}->{'passive_15_min'}  / $check_stats->{$type}->{'passive_sum'} * 100;
            $check_stats->{$type}->{'passive_60_min_perc'}  = $check_stats->{$type}->{'passive_60_min'}  / $check_stats->{$type}->{'passive_sum'} * 100;
            $check_stats->{$type}->{'passive_all_min_perc'} = $check_stats->{$type}->{'passive_all_min'} / $check_stats->{$type}->{'passive_sum'} * 100;
        }

        # set possible undefs to zero if still undef
        for my $key (qw{execution_time_min execution_time_max latency_min latency_max active_state_change_min
                          active_state_change_max passive_state_change_min passive_state_change_max}) {
            $check_stats->{$type}->{$key} = 0 unless defined $check_stats->{$type}->{$key};
        }
    }

    $c->stats->profile(end => "Utils::get_service_execution_stats_old()");

    return($check_stats);
}


############################################################

=head2 get_service_execution_stats

  my $stats = get_service_execution_stats($c);

Returns a hash with statistical data

=cut
sub get_service_execution_stats {
    my $c = shift;

    $c->stats->profile(begin => "Utils::get_service_execution_stats()");

    my $now    = time();
    my $min1   = $now - 60;
    my $min5   = $now - 300;
    my $min15  = $now - 900;
    my $min60  = $now - 3600;

    my $check_stats;
    for my $type (qw{hosts services}) {
        $check_stats->{$type} = {
            'execution_time_min'        => undef,
            'execution_time_max'        => undef,
            'execution_time_avg'        => 0,
            'execution_time_sum'        => 0,

            'latency_min'               => undef,
            'latency_max'               => undef,
            'latency_avg'               => 0,
            'latency_sum'               => 0,
        };

        my $query = "GET $type\n".Thruk::Utils::get_auth_filter($c, $type)."\n";
        $query .= "Filter: has_been_checked = 1\n";
        $query .= "Filter: check_type = 0\n";
        $query .= "Stats: sum has_been_checked as has_been_checked\n";
        $query .= "Stats: sum latency as latency_sum\n";
        $query .= "Stats: sum execution_time as execution_time_sum\n";
        $query .= "Stats: min latency as latency_min\n";
        $query .= "Stats: min execution_time as execution_time_min\n";
        $query .= "Stats: max latency as latency_max\n";
        $query .= "Stats: max execution_time as execution_time_max\n";

        my $data = $c->{'live'}->selectall_arrayref($query, { Slice => 1, AddPeer => 1});
        for my $backend_result (@{$data}) {
            $check_stats->{$type}->{'has_been_checked'}   += $backend_result->{'has_been_checked'};
            $check_stats->{$type}->{'execution_time_sum'} += $backend_result->{'execution_time_sum'};
            $check_stats->{$type}->{'latency_sum'}        += $backend_result->{'latency_sum'};
            if(!defined $check_stats->{$type}->{'execution_time_min'} or $check_stats->{$type}->{'execution_time_min'} > $backend_result->{'execution_time_min'}) { $check_stats->{$type}->{'execution_time_min'} = $backend_result->{'execution_time_min'}; }
            if(!defined $check_stats->{$type}->{'latency_min'} or $check_stats->{$type}->{'latency_min'} > $backend_result->{'latency_min'}) { $check_stats->{$type}->{'latency_min'} = $backend_result->{'latency_min'}; }
            if(!defined $check_stats->{$type}->{'latency_max'} or $check_stats->{$type}->{'execution_time_max'} < $backend_result->{'execution_time_max'}) { $check_stats->{$type}->{'execution_time_max'} = $backend_result->{'execution_time_max'}; }
            if(!defined $check_stats->{$type}->{'latency_max'} or $check_stats->{$type}->{'latency_max'} < $backend_result->{'latency_max'}) { $check_stats->{$type}->{'latency_max'} = $backend_result->{'latency_max'}; }
        }

        if(defined $check_stats->{$type}->{'has_been_checked'} and $check_stats->{$type}->{'has_been_checked'} > 0) {
            $check_stats->{$type}->{'execution_time_avg'} = $check_stats->{$type}->{'execution_time_sum'} / $check_stats->{$type}->{'has_been_checked'};
            $check_stats->{$type}->{'latency_avg'}        = $check_stats->{$type}->{'latency_sum'}        / $check_stats->{$type}->{'has_been_checked'};
        }

        # set possible undefs to zero if still undef
        for my $key (qw{execution_time_min execution_time_max latency_min latency_max }) {
            $check_stats->{$type}->{$key} = 0 unless defined $check_stats->{$type}->{$key};
        }
    }

    $c->stats->profile(end => "Utils::get_service_execution_stats()");

    return($check_stats);
}


########################################

=head2 get_hostcomments

  my $comments = get_hostcomments($c, $filter)

return all host comments for a given filter

=cut
sub get_hostcomments {
    my $c      = shift;
    my $filter = shift;

    $c->stats->profile(begin => "Utils::get_hostcomments()");

    $filter = '' unless defined $filter;
    my $hostcomments;
    my $comments    = $c->{'live'}->selectall_arrayref("GET comments\n".Thruk::Utils::get_auth_filter($c, 'comments')."\n$filter\nFilter: service_description =\nColumns: host_name id", { Slice => 1 });

    for my $comment (@{$comments}) {
        $hostcomments->{$comment->{'host_name'}}->{$comment->{'id'}} = $comment;
    }

    $c->stats->profile(end => "Utils::get_hostcomments()");

    return $hostcomments;
}


########################################

=head2 get_servicecomments

  my $comments = get_servicecomments($c, $filter);

returns all comments for a given filter

=cut
sub get_servicecomments {
    my $c      = shift;
    my $filter = shift;

    $c->stats->profile(begin => "Utils::get_servicecomments()");

    my $servicecomments;
    my $comments = $c->{'live'}->selectall_arrayref("GET comments\n".Thruk::Utils::get_auth_filter($c, 'comments')."\n$filter\nFilter: service_description !=\nColumns: host_name service_description id", { Slice => 1 });

    for my $comment (@{$comments}) {
        $servicecomments->{$comment->{'host_name'}}->{$comment->{'service_description'}}->{$comment->{'id'}} = $comment;
    }

    $c->stats->profile(end => "Utils::get_servicecomments()");

    return $servicecomments;
}


########################################

=head2 calculate_overall_processinfo

  my $process_info = calculate_overall_processinfo($process_info)

computes a combined status for process infos

=cut
sub calculate_overall_processinfo {
    my $pi = shift;
    my $return;
    for my $peer (keys %{$pi}) {
        for my $key (keys %{$pi->{$peer}}) {
            my $value = $pi->{$peer}->{$key};
            if($value eq "0" or $value eq "1") {
                if(!defined $return->{$key}) {
                    $return->{$key} = $value;
                }elsif($return->{$key} == -1) {
                    # do nothing, result already varies
                }elsif($return->{$key} == $value) {
                    # do nothing, result is the same
                }elsif($return->{$key} != $value) {
                    # set result to vary
                    $return->{$key} = -1;
                }
            }
        }
    }
    return($return);
}


########################################

=head2 get_start_end_for_timeperiod

  my($start, $end) = get_start_end_for_timeperiod($c,
                                                  $timeperiod,
                                                  $smon,
                                                  $sday,
                                                  $syear,
                                                  $shour,
                                                  $smin,
                                                  $ssec,
                                                  $emon,
                                                  $eday,
                                                  $eyear,
                                                  $ehour,
                                                  $emin,
                                                  $esec,
                                                  $t1,
                                                  $t2);

returns a start and end timestamp for a report date definition

=cut
sub get_start_end_for_timeperiod {
    my($c,$timeperiod,$smon,$sday,$syear,$shour,$smin,$ssec,$emon,$eday,$eyear,$ehour,$emin,$esec,$t1,$t2) = @_;

    my $start;
    my $end;
    $timeperiod = 'custom' unless defined $timeperiod;
    if($timeperiod eq 'today') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        $start = Mktime($year,$month,$day,  0,0,0);
        $end   = time();
    }
    elsif($timeperiod eq 'last24hours') {
        $end   = time();
        $start = $end - 86400;
    }
    elsif($timeperiod eq 'yesterday') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        $start = Mktime($year,$month,$day,  0,0,0) - 86400;
        $end   = $start + 86400;
    }
    elsif($timeperiod eq 'thisweek') {
        # start on last sunday 0:00 till now
        my @today  = Today();
        my @monday = Monday_of_Week(Week_of_Year(@today));
        $start     = Mktime(@monday,  0,0,0) - 86400;
        $end       = time();
    }
    elsif($timeperiod eq 'last7days') {
        $end   = time();
        $start = $end - 7 * 86400;
    }
    elsif($timeperiod eq 'lastweek') {
        # start on last weeks sunday 0:00 till last weeks saturday 24:00
        my @today  = Today();
        my @monday = Monday_of_Week(Week_of_Year(@today));
        $end       = Mktime(@monday,  0,0,0) - 86400;
        $start     = $end - 7*86400;
    }
    elsif($timeperiod eq 'thismonth') {
        # start on first till now
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        $start = Mktime($year,$month,1,  0,0,0);
        $end   = time();
    }
    elsif($timeperiod eq 'last31days') {
        $end   = time();
        $start = $end - 31 * 86400;
    }
    elsif($timeperiod eq 'lastmonth') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        $end   = Mktime($year,$month,1,  0,0,0);
        my $lastmonth = $month - 1;
        if($lastmonth <= 0) { $lastmonth = $lastmonth + 12; $year--;}
        $start = Mktime($year,$lastmonth,1,  0,0,0);
    }
    elsif($timeperiod eq 'thisyear') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        $start = Mktime($year,1,1,  0,0,0);
        $end   = time();
    }
    elsif($timeperiod eq 'lastyear') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        $start = Mktime($year-1,1,1,  0,0,0);
        $end   = Mktime($year,1,1,  0,0,0);
    }
    elsif(defined $t1 and defined $t2) {
        $start = $t1;
        $end   = $t2;
        if(!defined $start) {
            $start = Mktime($syear,$smon,$sday, $shour,$smin,$ssec);
        }
        if(!defined $end) {
            $end   = Mktime($eyear,$emon,$eday, $ehour,$emin,$esec);
        }
    } else {
        return(undef, undef);
    }

    $c->log->debug("start: ".$start." - ".(scalar localtime($start)));
    $c->log->debug("end  : ".$end." - ".(scalar localtime($end)));

    return($start, $end);
}


########################################

=head2 get_start_end_for_timeperiod_from_param

  my($start, $end) = get_start_end_for_timeperiod_from_param($c)

returns a start and end timestamp for a report date definition
will use cgi params for input

=cut
sub get_start_end_for_timeperiod_from_param {
    my $c = shift;

    confess("no c") unless defined($c);

    # get timeperiod
    my $timeperiod   = $c->{'request'}->{'parameters'}->{'timeperiod'};
    my $smon         = $c->{'request'}->{'parameters'}->{'smon'};
    my $sday         = $c->{'request'}->{'parameters'}->{'sday'};
    my $syear        = $c->{'request'}->{'parameters'}->{'syear'};
    my $shour        = $c->{'request'}->{'parameters'}->{'shour'};
    my $smin         = $c->{'request'}->{'parameters'}->{'smin'};
    my $ssec         = $c->{'request'}->{'parameters'}->{'ssec'};
    my $emon         = $c->{'request'}->{'parameters'}->{'emon'};
    my $eday         = $c->{'request'}->{'parameters'}->{'eday'};
    my $eyear        = $c->{'request'}->{'parameters'}->{'eyear'};
    my $ehour        = $c->{'request'}->{'parameters'}->{'ehour'};
    my $emin         = $c->{'request'}->{'parameters'}->{'emin'};
    my $esec         = $c->{'request'}->{'parameters'}->{'esec'};
    my $t1           = $c->{'request'}->{'parameters'}->{'t1'};
    my $t2           = $c->{'request'}->{'parameters'}->{'t2'};

    $timeperiod = 'last24hours' if(!defined $timeperiod and !defined $t1 and !defined $t2);
    return Thruk::Utils::get_start_end_for_timeperiod($c, $timeperiod,$smon,$sday,$syear,$shour,$smin,$ssec,$emon,$eday,$eyear,$ehour,$emin,$esec,$t1,$t2);
}


########################################

=head2 name2id

  my $striped_string = name2id($name)

returns a string which can be used as id in html elements

An id must begin with a letter ([A-Za-z]) and may be followed
by any number of letters, digits ([0-9]), hyphens ("-"),
underscores ("_"), colons (":"), and periods (".").

=cut
sub name2id {
    my $name       = shift;
    my $opt_prefix = shift || '';
    my $return = $name;
    $return =~ s/[^a-zA-Z0-9\-_\.]*//gmx;
    if($return =~ m/^\d+/gmx) {
        $return = $opt_prefix."_".$return;
    }
    return($return);
}


########################################

=head2 page_data

  page_data($c, $data)

adds paged data set to the template stash.
Data will be available as 'data'
The pager itself as 'pager'

=cut
sub page_data {
    my $c                   = shift;
    my $data                = shift || [];
    my $default_result_size = shift || $c->stash->{'default_page_size'};

    my $entries = $c->{'request'}->{'parameters'}->{'entries'} || $default_result_size;
    my $page    = $c->{'request'}->{'parameters'}->{'page'}    || 1;

    # we dont use paging at all?
    unless($c->stash->{'use_pager'} and defined $entries and $entries ne 'all' and $entries > 0) {
        $c->stash->{'data'}  = $data,
        return 1;
    }

    my $pager = new Data::Page;
    $pager->total_entries(scalar @{$data});
    my $pages = POSIX::ceil($pager->total_entries / $entries);

    if(exists $c->{'request'}->{'parameters'}->{'next'}) {
        $page++;
    }
    elsif(exists $c->{'request'}->{'parameters'}->{'previous'}) {
        $page-- if $page > 1;
    }
    elsif(exists $c->{'request'}->{'parameters'}->{'first'}) {
        $page = 1;
    }
    elsif(exists $c->{'request'}->{'parameters'}->{'last'}) {
        $page = $pages;
    }

    if($page < 0)      { $page = 1;      }
    if($page > $pages) { $page = $pages; }

    $c->stash->{'entries_per_page'} = $entries;
    $c->stash->{'current_page'}     = $page;

    if($entries eq 'all') {
        $c->stash->{'data'}  = $data,
    }
    else {
        $pager->entries_per_page($entries);
        $pager->current_page($page);
        my @data = $pager->splice($data);
        $c->stash->{'data'}  = \@data,
    }

    $c->stash->{'pager'} = $pager;
    $c->stash->{'pages'} = $pages;

    return 1;
}


########################################

=head2 uri

  uri($c)

returns a correct uri

=cut
sub uri {
    my $c = shift;
    my $uri = $c->request->uri();
    $uri =~ s/&/&amp;/gmx;
    return $uri;
}


########################################

=head2 uri_with

  uri_with($c, $data)

returns a correct uri

=cut
sub uri_with {
    my $c    = shift;
    my $data = shift;

    for my $key (keys %{$data}) {
        $data->{$key} = undef if $data->{$key} eq 'undef';
    }

    my $uri = $c->request->uri_with($data);

    $uri =~ s/&/&amp;/gmx;

    return $uri;
}

########################################

=head2 combine_filter

  combine_filter($filter_array_ref, $operator)

combines the filter by given operator

=cut
sub combine_filter {
    my $filter = shift;
    my $op     = shift;

    return "" if scalar @{$filter} == 0;

    confess("unknown operator: ".$op) if ($op ne 'And' and $op ne 'Or');

    if(scalar @{$filter} > 1) {
        return join("\n", @{$filter})."\n$op: ".(scalar @{$filter})."\n";
    }

    return $filter->[0]."\n";
}


########################################

=head2 set_can_submit_commands

  set_can_submit_commands($c)

sets the is_authorized_for_read_only role

=cut
sub set_can_submit_commands {
    my $c = shift;

    my $username = $c->request->{'user'}->{'username'};

    # is the contact allowed to send commands?
    my $can_submit_commands;
    eval {
        $can_submit_commands = $c->{'live'}->selectscalar_value("GET contacts\nColumns: can_submit_commands\nFilter: name = $username", { Slice => {}, Sum => 1 });
    };
    if($@) {
        $c->log->error("livestatus error: $@");
        $c->detach('/error/index/9');
    }
    if(!defined $can_submit_commands) {
        $can_submit_commands = Thruk->config->{'can_submit_commands'} || 0;
    }

    # override can_submit_commands from cgi.cfg
    if(grep 'authorized_for_all_host_commands', @{$c->request->{'user'}->{'roles'}}) {
        $can_submit_commands = 1;
    }
    elsif(grep 'authorized_for_all_service_commands', @{$c->request->{'user'}->{'roles'}}) {
        $can_submit_commands = 1;
    }
    elsif(grep 'authorized_for_system_commands', @{$c->request->{'user'}->{'roles'}}) {
        $can_submit_commands = 1;
    }

    $c->log->debug("can_submit_commands: $can_submit_commands");
    if($can_submit_commands != 1) {
        push @{$c->request->{'user'}->{'roles'}}, 'is_authorized_for_read_only';
    }
    return 1;
}


########################################

=head2 calculate_availability

  calculate_availability($c)

calculates the availability

=cut
sub calculate_availability {
    my $c    = shift;

    my $host           = $c->{'request'}->{'parameters'}->{'host'};
    my $hostgroup      = $c->{'request'}->{'parameters'}->{'hostgroup'};
    my $service        = $c->{'request'}->{'parameters'}->{'service'};
    my $servicegroup   = $c->{'request'}->{'parameters'}->{'servicegroup'};

    if(defined $service and CORE::index($service, ';') > 0) {
        ($host,$service) = split/;/mx, $service;
        $c->stash->{host}    = $host;
        $c->stash->{service} = $service;
    }

    if(defined $host and $host eq 'null') { undef $host; }

    my $csvoutput = 0;
    $csvoutput = 1 if exists $c->{'request'}->{'parameters'}->{'csvoutput'};

    if(defined $hostgroup and $hostgroup ne '') {
        $c->stash->{template}   = 'avail_report_hostgroup.tt';
    }
    elsif(defined $service and $service ne 'all') {
        $c->stash->{template}   = 'avail_report_service.tt';
    }
    elsif(defined $service and $service eq 'all') {
        if($csvoutput) {
            $c->stash->{template} = 'avail_report_services_csv.tt';
        } else {
            $c->stash->{template} = 'avail_report_services.tt';
        }
    }
    elsif(defined $servicegroup and $servicegroup ne '') {
        $c->stash->{template}   = 'avail_report_servicegroup.tt';
    }
    elsif(defined $host and $host ne 'all') {
        $c->stash->{template}   = 'avail_report_host.tt';
    }
    elsif(defined $host and $host eq 'all') {
        if($csvoutput) {
            $c->stash->{template}   = 'avail_report_hosts_csv.tt';
        } else {
            $c->stash->{template}   = 'avail_report_hosts.tt';
        }
    }
    else {
        $c->log->debug("unknown report type");
        return;
    }

    if($csvoutput) {
        $c->response->header('Content-Type' => 'text/plain');
        delete $c->{'request'}->{'parameters'}->{'show_log_entries'};
        delete $c->{'request'}->{'parameters'}->{'full_log_entries'};
    }

    # get start/end from timeperiod in params
    my($start,$end) = Thruk::Utils::get_start_end_for_timeperiod_from_param($c);
    return 0 if (!defined $start or !defined $end);

    $c->stash->{start}      = $start;
    $c->stash->{end}        = $end;
    $c->stash->{timeperiod} = $c->{'request'}->{'parameters'}->{'timeperiod'};

    my $rpttimeperiod                = $c->{'request'}->{'parameters'}->{'rpttimeperiod'};
    my $assumeinitialstates          = $c->{'request'}->{'parameters'}->{'assumeinitialstates'};
    my $assumestateretention         = $c->{'request'}->{'parameters'}->{'assumestateretention'};
    my $assumestatesduringnotrunning = $c->{'request'}->{'parameters'}->{'assumestatesduringnotrunning'};
    my $includesoftstates            = $c->{'request'}->{'parameters'}->{'includesoftstates'};
    my $initialassumedhoststate      = $c->{'request'}->{'parameters'}->{'initialassumedhoststate'};
    my $initialassumedservicestate   = $c->{'request'}->{'parameters'}->{'initialassumedservicestate'};
    my $backtrack                    = $c->{'request'}->{'parameters'}->{'backtrack'};
    my $show_log_entries             = $c->{'request'}->{'parameters'}->{'show_log_entries'};
    my $full_log_entries             = $c->{'request'}->{'parameters'}->{'full_log_entries'};
    my $zoom                         = $c->{'request'}->{'parameters'}->{'zoom'};

    # calculate zoom
    $zoom = 4 unless defined $zoom;
    $zoom =~ s/^\+//gmx;

    # default zoom is 4
    if($zoom !~ m/^(\-|)\d+$/mx) {
        $zoom = 4;
    }
    $zoom = 1 if $zoom == 0;

    # show_log_entries is true if it exists
    $show_log_entries = 1 if exists $c->{'request'}->{'parameters'}->{'show_log_entries'};

    # full_log_entries is true if it exists
    $full_log_entries = 1 if exists $c->{'request'}->{'parameters'}->{'full_log_entries'};

    # default backtrack is 4 days
    $backtrack = 4 unless defined $backtrack;
    $backtrack = 4 if $backtrack < 0;

    $assumeinitialstates          = 'yes' unless defined $assumeinitialstates;
    $assumeinitialstates          = 'no'  unless $assumeinitialstates          eq 'yes';

    $assumestateretention         = 'yes' unless defined $assumestateretention;
    $assumestateretention         = 'no'  unless $assumestateretention         eq 'yes';

    $assumestatesduringnotrunning = 'yes' unless defined $assumestatesduringnotrunning;
    $assumestatesduringnotrunning = 'no'  unless $assumestatesduringnotrunning eq 'yes';

    $includesoftstates            = 'no'  unless defined $includesoftstates;
    $includesoftstates            = 'no'  unless $includesoftstates            eq 'yes';

    $initialassumedhoststate      = 0 unless defined $initialassumedhoststate;
    $initialassumedhoststate      = 0 unless $initialassumedhoststate ==  0  # Unspecified
                                          or $initialassumedhoststate == -1  # Current State
                                          or $initialassumedhoststate ==  3  # Host Up
                                          or $initialassumedhoststate ==  4  # Host Down
                                          or $initialassumedhoststate ==  5; # Host Unreachable

    $initialassumedservicestate   = 0 unless defined $initialassumedservicestate;
    $initialassumedservicestate   = 0 unless $initialassumedservicestate ==  0  # Unspecified
                                          or $initialassumedservicestate == -1  # Current State
                                          or $initialassumedservicestate ==  6  # Service Ok
                                          or $initialassumedservicestate ==  8  # Service Warning
                                          or $initialassumedservicestate ==  7  # Service Unknown
                                          or $initialassumedservicestate ==  9; # Service Critical

    $c->stash->{rpttimeperiod}                = $rpttimeperiod;
    $c->stash->{assumeinitialstates}          = $assumeinitialstates;
    $c->stash->{assumestateretention}         = $assumestateretention;
    $c->stash->{assumestatesduringnotrunning} = $assumestatesduringnotrunning;
    $c->stash->{includesoftstates}            = $includesoftstates;
    $c->stash->{initialassumedhoststate}      = $initialassumedhoststate;
    $c->stash->{initialassumedservicestate}   = $initialassumedservicestate;
    $c->stash->{backtrack}                    = $backtrack;
    $c->stash->{show_log_entries}             = $show_log_entries;
    $c->stash->{full_log_entries}             = $full_log_entries;
    $c->stash->{zoom}                         = $zoom;

    # get groups / hosts /services
    my $groupfilter      = "";
    my $hostfilter       = "";
    my $servicefilter    = "";
    my $logserviceheadfilter;
    my $loghostheadfilter;
    my $initial_states = { 'hosts' => {}, 'services' => {} };

    # for which services do we need availability data?
    my $hosts = [];
    my $services = [];

    my $softlogs = "";
    if(!$includesoftstates or $includesoftstates eq 'no') {
        $softlogs = "Filter: options ~ ;HARD;\nAnd: 2\n"
    }

    my $logs;
    my $logstart = $start - $backtrack * 86400;
    $c->log->debug("logstart: ".$logstart." - ".(scalar localtime($logstart)));
    my $logfilter = "Filter: time >= $logstart\n";
    $logfilter   .= "Filter: time <= $end\n";
    $logfilter   .= "And: 2\n";

    # a single service
    if(defined $service and $service ne 'all') {
        unless($c->check_permissions('service', $service, $host)) {
            $c->detach('/error/index/15');
        }
        $logserviceheadfilter = "Filter: service_description = $service\n";
        $loghostheadfilter    = "Filter: host_name = $host\n";
        push @{$services}, { 'host' => $host, 'service' => $service };

        if($initialassumedservicestate == -1) {
            my $service_data = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Utils::get_auth_filter($c, 'services')."\nColumns: state\nLimit: 1", {Slice => 1});
            $initial_states->{'services'}->{$host}->{$service} = $service_data->[0]->{'state'};
        }
    }

    # all services
    elsif(defined $service and $service eq 'all') {
        my $all_services = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Utils::get_auth_filter($c, 'services')."\nColumns: host_name description state", { Slice => 1});
        my $services_data;
        for my $service (@{$all_services}) {
            $services_data->{$service->{'host_name'}}->{$service->{'description'}} = 1;
            push @{$services}, { 'host' => $service->{'host_name'}, 'service' => $service->{'description'} };
            if($initialassumedservicestate == -1) {
                $initial_states->{'services'}->{$service->{'host_name'}}->{$service->{'description'}} = $service->{'state'};
            }
        }
        $c->stash->{'services'} = $services_data;
    }

    # a single host
    elsif(defined $host and $host ne 'all') {
        unless($c->check_permissions('host', $host)) {
            $c->detach('/error/index/5');
        }
        my $service_data = $c->{'live'}->selectall_hashref("GET services\nFilter: host_name = ".$host."\n".Thruk::Utils::get_auth_filter($c, 'services')."\nColumns: description state", 'description' );
        $c->stash->{'services'} = { $host =>  $service_data };
        $loghostheadfilter = "Filter: host_name = $host\n";

        for my $description (keys %{$service_data}) {
            push @{$services}, { 'host' => $host, 'service' => $description };
        }
        if($initialassumedservicestate == -1) {
            for my $servicename (keys %{$service_data}) {
                $initial_states->{'services'}->{$host}->{$servicename} = $service_data->{$servicename}->{'state'};
            }
        }
        if($initialassumedhoststate == -1) {
            my $host_data = $c->{'live'}->selectall_arrayref("GET hosts\nFilter: name = $host\n".Thruk::Utils::get_auth_filter($c, 'hosts')."\nColumns: state\nLimit: 1", {Slice => 1});
            $initial_states->{'hosts'}->{$host} = $host_data->[0]->{'state'};
        }
        push @{$hosts}, $host;
    }

    # all hosts
    elsif(defined $host and $host eq 'all') {
        my $host_data = $c->{'live'}->selectall_hashref("GET hosts\n".Thruk::Utils::get_auth_filter($c, 'hosts')."\nColumns: name state", 'name' );
        $logserviceheadfilter = "Filter: service_description =\n";
        $c->stash->{'hosts'} = $host_data;
        push @{$hosts}, keys %{$host_data};
        if($initialassumedhoststate == -1) {
            for my $hostname (keys %{$host_data}) {
                $initial_states->{'hosts'}->{$hostname} = $host_data->{$hostname}->{'state'};
            }
        }
    }

    # one or all hostgroups
    elsif(defined $hostgroup and $hostgroup ne '') {
        if($hostgroup ne '' and $hostgroup ne 'all') {
            $groupfilter       = "Filter: name = $hostgroup\n";
            $hostfilter        = "Filter: groups >= $hostgroup\n";
            $loghostheadfilter = "Filter: current_host_groups >= $hostgroup\n";
        }
        my $host_data = $c->{'live'}->selectall_hashref("GET hosts\n".Thruk::Utils::get_auth_filter($c, 'hosts')."\nColumns: name state\n$hostfilter", 'name' );
        my $groups    = $c->{'live'}->selectall_arrayref("GET hostgroups\n".Thruk::Utils::get_auth_filter($c, 'hostgroups')."\n$groupfilter\nColumns: name members", { Slice => {} });

        # join our groups together
        my %joined_groups;
        for my $group (@{$groups}) {
            my $name = $group->{'name'};
            if(!defined $joined_groups{$name}) {
                $joined_groups{$name}->{'name'}  = $group->{'name'};
                $joined_groups{$name}->{'hosts'} = {};
            }

            if(defined $group->{'members'}) {
                for my $hostname (split /,/mx, $group->{'members'}) {
                    # show only hosts with proper authorization
                    next unless defined $host_data->{$hostname};

                    if(!defined $joined_groups{$name}->{'hosts'}->{$hostname}) {
                        $joined_groups{$name}->{'hosts'}->{$hostname} = 1;
                    }
                }
            }
            # remove empty groups
            if(scalar keys %{$joined_groups{$name}->{'hosts'}} == 0) {
                delete $joined_groups{$name};
            }
        }
        $c->stash->{'groups'} = \%joined_groups;
        $logserviceheadfilter = "Filter: service_description =\n";

        push @{$hosts}, keys %{$host_data};

        if($initialassumedhoststate == -1) {
            for my $hostname (keys %{$host_data}) {
                $initial_states->{'hosts'}->{$hostname} = $host_data->{$hostname}->{'state'};
            }
        }
    }


    # one or all servicegroups
    elsif(defined $servicegroup and $servicegroup ne '') {
        if($servicegroup ne '' and $servicegroup ne 'all') {
            $groupfilter          = "Filter: name = $servicegroup\n";
            $servicefilter        = "Filter: groups >= $servicegroup\n";
            $logserviceheadfilter = "Filter: current_service_groups >= $servicegroup\n";
        }
        my $all_services = $c->{'live'}->selectall_arrayref("GET services\n".$servicefilter.Thruk::Utils::get_auth_filter($c, 'services')."\nColumns: host_name description state host_state", { Slice => 1});
        my $groups       = $c->{'live'}->selectall_arrayref("GET servicegroups\n".Thruk::Utils::get_auth_filter($c, 'servicegroups')."\n$groupfilter\nColumns: name members", { Slice => {} });

        my $service_data;
        for my $service (@{$all_services}) {
            $service_data->{$service->{'host_name'}}->{$service->{'description'}} = 1;
        }

        # join our groups together
        my %joined_groups;
        for my $group (@{$groups}) {
            my $name = $group->{'name'};
            if(!defined $joined_groups{$name}) {
                $joined_groups{$name}->{'name'}     = $group->{'name'};
                $joined_groups{$name}->{'services'} = {};
            }

            for my $member (split /,/mx, $group->{'members'}) {
                my($hostname,$description) = split/\|/mx, $member, 2;
                # show only services with proper authorization
                next unless defined $service_data->{$hostname}->{$description};

                if(!defined $joined_groups{$name}->{'services'}->{$hostname}->{$description}) {
                    $joined_groups{$name}->{'services'}->{$hostname}->{$description} = 1;
                }
            }
            # remove empty groups
            if(scalar keys %{$joined_groups{$name}->{'services'}} == 0) {
                delete $joined_groups{$name};
            }
        }
        $c->stash->{'groups'} = \%joined_groups;

        my %tmp_hosts;
        for my $service (@{$all_services}) {
            $tmp_hosts{$service->{host_name}} = 1;
            push @{$services}, { 'host' => $service->{host_name}, 'service' => $service->{'description'} };
        }
        push @{$hosts}, keys %tmp_hosts;
        if($initialassumedservicestate == -1) {
            for my $service (@{$all_services}) {
                $initial_states->{'services'}->{$service->{host_name}}->{$service->{'description'}} = $service->{'state'};
            }
        }
        if($initialassumedhoststate == -1) {
            for my $service (@{$all_services}) {
                next if defined $initial_states->{'hosts'}->{$service->{host_name}};
                $initial_states->{'hosts'}->{$service->{host_name}} = $service->{'host_state'};
            }
        }
    } else {
        croak("unknown report type: ".Dumper($c->{'request'}->{'parameters'}));
    }


    ########################
    # fetch logs
    my(@loghostfilter,@logservicefilter);
    unless($service) {
        push @loghostfilter, "Filter: type = HOST ALERT\n".$softlogs;
        push @loghostfilter, "Filter: type = INITIAL HOST STATE\n".$softlogs;
        push @loghostfilter, "Filter: type = CURRENT HOST STATE\n".$softlogs;
    }
    push @loghostfilter, "Filter: type = HOST DOWNTIME ALERT\n";
    if($service or $host or $servicegroup) {
        push @logservicefilter, "Filter: type = SERVICE ALERT\n".$softlogs;
        push @logservicefilter, "Filter: type = INITIAL SERVICE STATE\n".$softlogs;
        push @logservicefilter, "Filter: type = CURRENT SERVICE STATE\n".$softlogs;
        push @logservicefilter, "Filter: type = SERVICE DOWNTIME ALERT\n";
    }
    my @typefilter;
    if(defined $loghostheadfilter) {
        push @typefilter, $loghostheadfilter.join("\n", @loghostfilter)."\nOr: ".(scalar @loghostfilter)."\nAnd: 2";
    } else {
        push @typefilter, join("\n", @loghostfilter)."\nOr: ".(scalar @loghostfilter)."\n";
    }
    if(scalar @logservicefilter > 0) {
        if(defined $logserviceheadfilter and defined $loghostheadfilter) {
            push @typefilter, $loghostheadfilter.$logserviceheadfilter."\nAnd: 2\n".join("\n", @logservicefilter)."\nOr: ".(scalar @logservicefilter)."\nAnd: 2";
        }
        elsif(defined $logserviceheadfilter) {
            push @typefilter, $logserviceheadfilter."\n".join("\n", @logservicefilter)."\nOr: ".(scalar @logservicefilter)."\nAnd: 2";
        }
        elsif(defined $loghostheadfilter) {
            push @typefilter, $loghostheadfilter."\n".join("\n", @logservicefilter)."\nOr: ".(scalar @logservicefilter)."\nAnd: 2";
        }
        else {
            push @typefilter, join("\n", @logservicefilter)."\nOr: ".(scalar @logservicefilter)."\n";
        }
    }
    push @typefilter, "Filter: class = 2\n"; # programm messages
    $logfilter .= join("\n", @typefilter)."\nOr: ".(scalar @typefilter);

    my $log_query = "GET log\n".$logfilter.Thruk::Utils::get_auth_filter($c, 'log')."\nColumns: class time type options state host_name service_description plugin_output";
    #$c->log->debug($log_query);
    $c->stats->profile(begin => "avail.pm fetchlogs");
    $logs = $c->{'live'}->selectall_arrayref($log_query, { Slice => 1} );
    $c->stats->profile(end   => "avail.pm fetchlogs");

    #$Data::Dumper::Indent = 1;
    #open(FH, '>', '/tmp/logs.txt') or die("cannot open logs.txt: $!");
    ##print FH Dumper($logs);
    #for my $line (@{$logs}) {
    #    print FH '['.$line->{'time'}.'] '.$line->{'type'};
    #    print FH ': '.$line->{'options'} if(defined $line->{'options'} and $line->{'options'} ne '');
    #    print FH "\n";
    #}
    #close(FH);

    $c->stats->profile(begin => "calculate availability");
    my $ma = Monitoring::Availability->new(
        'rpttimeperiod'                => $rpttimeperiod,
        'assumeinitialstates'          => $assumeinitialstates,
        'assumestateretention'         => $assumestateretention,
        'assumestatesduringnotrunning' => $assumestatesduringnotrunning,
        'includesoftstates'            => $includesoftstates,
        'initialassumedhoststate'      => Thruk::Utils::_initialassumedhoststate_to_state($initialassumedhoststate),
        'initialassumedservicestate'   => Thruk::Utils::_initialassumedservicestate_to_state($initialassumedservicestate),
        'backtrack'                    => $backtrack,
#        'verbose'                      => 1,
#        'logger'                       => $c->log,
    );
    $c->stash->{avail_data} = $ma->calculate(
        'start'                        => $start,
        'end'                          => $end,
        'log_livestatus'               => $logs,
        'hosts'                        => $hosts,
        'services'                     => $services,
        'initial_states'               => $initial_states,
    );
    #$c->log->info(Dumper($c->stash->{avail_data}));
    $c->stats->profile(end => "calculate availability");

    if($full_log_entries) {
        $c->stash->{'logs'} = $ma->get_full_logs();
        #$c->log->debug("got full logs: ".Dumper($c->stash->{'logs'}));
    }
    elsif($show_log_entries) {
        $c->stash->{'logs'} = $ma->get_condensed_logs();
        #$c->log->debug("got condensed logs: ".Dumper($c->stash->{'logs'}));
    }

    $c->stats->profile(end => "got logs");
    return 1;
}

########################################

=head2 set_message

  set_message($c, $style, $text)

set a message in an cookie for later display

=cut
sub set_message {
    my $c       = shift;
    my $style   = shift;
    my $message = shift;

    $c->res->cookies->{'thruk_message'} = {
        value => $style.'~~'.$message,
    };

    return 1;
}

########################################

=head2 get_message

  get_message($c)

get a message from an cookie, display and delete it

=cut
sub get_message {
    my $c       = shift;

    if(defined $c->request->cookie('thruk_message')) {
        my $cookie = $c->request->cookie('thruk_message');
        my($style,$message) = split/~~/mx, $cookie->value;
        $c->stash->{'thruk_message'}       = $message;
        $c->stash->{'thruk_message_class'} = $style;

        $c->res->cookies->{'thruk_message'} = {
            value   => '',
            expires => '-1M',
        };
    }

    return 1;
}

########################################
sub _initialassumedhoststate_to_state {
    my $initialassumedhoststate = shift;

    return 'unspecified' if $initialassumedhoststate ==  0; # Unspecified
    return 'current'     if $initialassumedhoststate == -1; # Current State
    return 'up'          if $initialassumedhoststate ==  3; # Host Up
    return 'down'        if $initialassumedhoststate ==  4; # Host Down
    return 'unreachable' if $initialassumedhoststate ==  5; # Host Unreachable
    croak('unknown state: '.$initialassumedhoststate);
}


########################################
sub _initialassumedservicestate_to_state {
    my $initialassumedservicestate = shift;

    return 'unspecified' if $initialassumedservicestate ==  0; # Unspecified
    return 'current'     if $initialassumedservicestate == -1; # Current State
    return 'ok'          if $initialassumedservicestate ==  6; # Service Ok
    return 'warning'     if $initialassumedservicestate ==  8; # Service Warning
    return 'unknown'     if $initialassumedservicestate ==  7; # Service Unknown
    return 'critical'    if $initialassumedservicestate ==  9; # Service Critical
    croak('unknown state: '.$initialassumedservicestate);
}


########################################
sub _html_escape {
    my $text = shift;

    return HTML::Entities::encode($text);
}

1;

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
