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
use Date::Manip;
use Data::Page;
use Monitoring::Livestatus::MULTI;
use File::Slurp;


##############################################
=head1 METHODS

=head2 parse_date

  my $timestamp = parse_date($c, $string)

Format: 2010-03-02 00:00:00
parse given date and return timestamp

=cut
sub parse_date {
    my $c      = shift;
    my $string = shift;
    my $timestamp;
    eval {
        if($string =~ m/(\d{4})\-(\d{2})\-(\d{2})\ (\d{2}):(\d{2}):(\d{2})/mx) {
            $timestamp = Mktime($1,$2,$3, $4,$5,$6);
            $c->log->debug("parse_date: '".$string."' to -> '".(scalar localtime $timestamp)."'");
        }
        else {
            $timestamp = UnixDate($string, '%s');
            $c->log->debug("parse_date: '".$string."' to -> '".(scalar localtime $timestamp)."'");
        }
    };
    if($@) {
        $c->detach('/error/index/19');
        return;
    }
    return $timestamp;
}


##############################################

=head2 format_date

  my $date_string = format_date($string, $format)

return date from timestamp in given format

=cut
sub format_date {
    my $timestamp = shift;
    my $format    = shift;
    return UnixDate("epoch $timestamp", $format);
}


######################################

=head2 read_cgi_cfg

  read_cgi_cfg($c);

parse the cgi.cfg and put it into $c->config

=cut
sub read_cgi_cfg {
    my $c      = shift;
    my $config = shift;
    if(defined $c) {
        $config = $c->config;
    }

    $c->stats->profile(begin => "Utils::read_cgi_cfg()") if defined $c;

    # read only if its changed
    my $file = $config->{'cgi.cfg'};
    if(!defined $file or $file eq '') {
        $config->{'cgi_cfg'} = 'undef';
        if(defined $c) {
            $c->log->error("cgi.cfg not set");
            $c->error("cgi.cfg not set");
            $c->detach('/error/index/4');
        }
        print STDERR "cgi_cfg option must be set in thruk.conf or thruk_local.conf\n\n";
        return;
    }
    elsif( -r $file ) {
        # perfect, file exists and is readable
    }
    elsif(-r $config->{'project_root'}.'/'.$file) {
        $file = $config->{'project_root'}.'/'.$file;
    }
    else {
        if(defined $c) {
            $c->log->error("cgi.cfg not readable: ".$!);
            $c->error("cgi.cfg not readable: ".$!);
            $c->detach('/error/index/4');
        }
        print STDERR "$file not readable: ".$!."\n\n";
        return;
    }

    # (dev,ino,mode,nlink,uid,gid,rdev,size,atime,mtime,ctime,blksize,blocks)
    my @cgi_cfg_stat = stat($file);

    my $last_stat = $config->{'cgi_cfg_stat'};
    if(!defined $last_stat
       or $last_stat->[1] != $cgi_cfg_stat[1] # inode changed
       or $last_stat->[9] != $cgi_cfg_stat[9] # modify time changed
      ) {
        $c->log->info("cgi.cfg has changed, updating...") if defined $last_stat;
        $c->log->debug("reading $file") if defined $c;
        $config->{'cgi_cfg_stat'} = \@cgi_cfg_stat;
        my $conf = new Config::General($file);
        %{$config->{'cgi_cfg'}} = $conf->getall;
    }

    $c->stats->profile(end => "Utils::read_cgi_cfg()") if defined $c;

    return 1;
}


######################################

=head2 is_valid_regular_expression

  my $result = is_valid_regular_expression($expression)

return true if this is a valid regular expression

=cut
sub is_valid_regular_expression {
    my $c          = shift;
    my $expression = shift;
    return 1 unless defined $expression;
    local $SIG{__DIE__} = undef;
    eval { "test" =~ m/$expression/mx; };
    if($@) {
        my $error_message = "invalid regular expression: ".$@;
        $error_message =~ s/\s+at\s+.*$//gmx;
        $error_message =~ s/in\s+regex\;/in regex<br \/>/gmx;
        $error_message =~ s/HERE\s+in\s+m\//HERE in <br \/>/gmx;
        $error_message =~ s/\/$//gmx;
        set_message($c, 'fail_message', $error_message);
        return;
    }
    return 1;
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

        my $tmp_data = $c->{'live'}->selectall_arrayref("GET $type\n".Thruk::Utils::Auth::get_auth_filter($c, $type)."\nColumns: execution_time has_been_checked last_check latency percent_state_change check_type", { Slice => 1, AddPeer => 1 });
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

        my $query = "GET $type\n".Thruk::Utils::Auth::get_auth_filter($c, $type)."\n";
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
    my $comments    = $c->{'live'}->selectall_arrayref("GET comments\n".Thruk::Utils::Auth::get_auth_filter($c, 'comments')."\n$filter\nFilter: service_description =\nColumns: host_name id", { Slice => 1 });

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
    my $comments = $c->{'live'}->selectall_arrayref("GET comments\n".Thruk::Utils::Auth::get_auth_filter($c, 'comments')."\n$filter\nFilter: service_description !=\nColumns: host_name service_description id", { Slice => 1 });

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
    if(!$c->stash->{'use_pager'} or !defined $entries) {
        $c->stash->{'data'}  = $data,
        return 1;
    }

    $c->stash->{'entries_per_page'} = $entries;

    my $pager = new Data::Page;
    $pager->total_entries(scalar @{$data});
    if($entries eq 'all') { $entries = $pager->total_entries; }
    my $pages = 0;
    if($entries > 0) {
        $pages = POSIX::ceil($pager->total_entries / $entries);
    }
    else {
        $c->stash->{'data'}  = $data,
        return 1;
    }

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

=head2 combine_filter

  combine_filter($filter_array_ref, $operator)

combines the filter by given operator

=cut
sub combine_filter {
die("obsolete!!");
    my $filter = shift;
    my $op     = shift;
    my $erg    = "";

    confess("unknown operator: ".$op) if ($op ne 'And' and $op ne 'Or');

    # filter empty strings
    @{$filter} = grep {!/\Z\s*\A/mx} @{$filter};

    if(scalar @{$filter} == 0) {
        $erg = ""
    }
    elsif(scalar @{$filter} > 1) {
        $erg = join("\n", @{$filter})."\n$op: ".(scalar @{$filter})."\n";
    }
    else {
        $erg = $filter->[0]."\n";

    }

    return $erg;
}


########################################

=head2 set_can_submit_commands

  set_can_submit_commands($c)

sets the is_authorized_for_read_only role

=cut
sub set_can_submit_commands {
    my $c = shift;

    $c->stats->profile(begin => "Thruk::Utils::set_can_submit_commands");
    my $username = $c->request->{'user'}->{'username'};

    # is the contact allowed to send commands?
    my($can_submit_commands,$alias,$data);
    my $cache = $c->cache;
    my $cached_data = $cache->get($username);
    if(defined $cached_data->{'can_submit_commands'}) {
        # got cached data
        $data = $cached_data->{'can_submit_commands'};
    }
    else {
        eval {
            $data = $c->{'db'}->get_can_submit_commands($username);
            $cached_data->{'can_submit_commands'} = $data;
            $cache->set($username, $cached_data);
        }
    };
    if($@) {
        $c->log->error("livestatus error: $@");
        $c->detach('/error/index/9');
    }

    if(defined $data) {
        for my $dat (@{$data}) {
            $alias               = $dat->{'alias'}               if defined $dat->{'alias'};
            $can_submit_commands = $dat->{'can_submit_commands'} if defined $dat->{'can_submit_commands'};
        }
    }

    if(defined $alias) {
        $c->request->{'user'}->{'alias'} = $alias;
    }
    if(!defined $can_submit_commands) {
        $can_submit_commands = Thruk->config->{'can_submit_commands'} || 0;
    }

    # override can_submit_commands from cgi.cfg
    if(grep /authorized_for_all_host_commands/mx, @{$c->request->{'user'}->{'roles'}}) {
        $can_submit_commands = 1;
    }
    elsif(grep /authorized_for_all_service_commands/mx, @{$c->request->{'user'}->{'roles'}}) {
        $can_submit_commands = 1;
    }
    elsif(grep /authorized_for_system_commands/mx, @{$c->request->{'user'}->{'roles'}}) {
        $can_submit_commands = 1;
    }

    $c->log->debug("can_submit_commands: $can_submit_commands");
    if($can_submit_commands != 1) {
        push @{$c->request->{'user'}->{'roles'}}, 'is_authorized_for_read_only';
    }

    $c->stats->profile(end => "Thruk::Utils::set_can_submit_commands");
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
            my $service_data = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Utils::Auth::get_auth_filter($c, 'services')."\nColumns: state\nLimit: 1", {Slice => 1});
            $initial_states->{'services'}->{$host}->{$service} = $service_data->[0]->{'state'};
        }
    }

    # all services
    elsif(defined $service and $service eq 'all') {
        my $all_services = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Utils::Auth::get_auth_filter($c, 'services')."\nColumns: host_name description state", { Slice => 1});
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
        my $service_data = $c->{'live'}->selectall_hashref("GET services\nFilter: host_name = ".$host."\n".Thruk::Utils::Auth::get_auth_filter($c, 'services')."\nColumns: description state", 'description' );
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
            my $host_data = $c->{'live'}->selectall_arrayref("GET hosts\nFilter: name = $host\n".Thruk::Utils::Auth::get_auth_filter($c, 'hosts')."\nColumns: state\nLimit: 1", {Slice => 1});
            $initial_states->{'hosts'}->{$host} = $host_data->[0]->{'state'};
        }
        push @{$hosts}, $host;
    }

    # all hosts
    elsif(defined $host and $host eq 'all') {
        my $host_data = $c->{'live'}->selectall_hashref("GET hosts\n".Thruk::Utils::Auth::get_auth_filter($c, 'hosts')."\nColumns: name state", 'name' );
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
        my $host_data = $c->{'live'}->selectall_hashref("GET hosts\n".Thruk::Utils::Auth::get_auth_filter($c, 'hosts')."\nColumns: name state\n$hostfilter", 'name' );
        my $groups    = $c->{'live'}->selectall_arrayref("GET hostgroups\n".Thruk::Utils::Auth::get_auth_filter($c, 'hostgroups')."\n$groupfilter\nColumns: name members", { Slice => {} });

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
        my $all_services = $c->{'live'}->selectall_arrayref("GET services\n".$servicefilter.Thruk::Utils::Auth::get_auth_filter($c, 'services')."\nColumns: host_name description state host_state", { Slice => 1});
        my $groups       = $c->{'live'}->selectall_arrayref("GET servicegroups\n".Thruk::Utils::Auth::get_auth_filter($c, 'servicegroups')."\n$groupfilter\nColumns: name members", { Slice => {} });

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

    my $log_query = "GET log\n".$logfilter.Thruk::Utils::Auth::get_auth_filter($c, 'log')."\nColumns: class time type options state host_name service_description plugin_output";
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
    $c->stash->{'thruk_message'} = $style.'~~'.$message;

    return 1;
}


########################################

=head2 ssi_include

  ssi_include($c)

puts the ssi templates into the stash

=cut
sub ssi_include {
    my $c = shift;
    my $global_header_file = "global-header.ssi";
    my $header_file        = $c->stash->{'page'}."-header.ssi";
    my $global_footer_file = "global-footer.ssi";
    my $footer_file        = $c->stash->{'page'}."-footer.ssi";

    if ( defined $c->config->{ssi_includes}->{$global_header_file} ){
        $c->stash->{ssi_header} = Thruk::Utils::read_ssi($c, $global_header_file);
    }
    if ( defined $c->config->{ssi_includes}->{$header_file} ){
        $c->stash->{ssi_header} .= Thruk::Utils::read_ssi($c, $header_file);
    }
    # Footer
    if ( defined $c->config->{ssi_includes}->{$global_footer_file} ){
        $c->stash->{ssi_footer} = Thruk::Utils::read_ssi($c, $global_footer_file);
    }
    if ( defined $c->config->{ssi_includes}->{$footer_file} ){
        $c->stash->{ssi_footer} .= Thruk::Utils::read_ssi($c, $footer_file);
    }

    return 1;
}


########################################

=head2 read_ssi

  read_ssi($c, $file)

reads a ssi file or executes it if its executable

=cut
sub read_ssi {
   my $c    = shift;
   my $file = shift;
   # retun if file is execitabel
   if( -x $c->config->{'ssi_path'}.$file ){
       open(my $ph, '-|', $c->config->{'ssi_path'}.$file.' 2>&1') or carp("cannot execute ssi: $!");
       my $output = <$ph>;
       close($ph);
       return $output;
   }
   return read_file($c->config->{'ssi_path'}.$file) or carp("cannot open ssi: $!");

}


########################################

=head2 version_compare

  version_compare($version1, $version2)

compare too version strings

=cut
sub version_compare {
    my($v1,$v2) = @_;
    confess("version_compare() needs two params") unless defined $v2;

    my @v1 = split/\./mx,$v1;
    my @v2 = split/\./mx,$v2;

    for(my $x = 0; $x < scalar @v1; $x++) {
        next if !defined $v2[$x];
        my $cmp = 0;
        if($v2[$x] =~ m/^(\d+)/gmx) { $cmp = $1; }
        return 0 unless $v1[$x] <= $cmp;
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


1;

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
