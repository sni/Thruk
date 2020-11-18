package Thruk::Backend::Provider::Mysql;

use strict;
use warnings;
#use Thruk::Timer qw/timing_breakpoint/;
use Data::Dumper qw/Dumper/;
use Module::Load qw/load/;
use parent 'Thruk::Backend::Provider::Base';
use Thruk::Utils ();
use Thruk::Utils::Log qw/:all/;
use Carp qw/confess/;
use POSIX ();

=head1 NAME

Thruk::Backend::Provider::Mysql - connection provider for Mysql connections

=head1 DESCRIPTION

connection provider for Mysql connections

=head1 METHODS

=cut

$Thruk::Backend::Provider::Mysql::cache_version = 6;

$Thruk::Backend::Provider::Mysql::db_types = {
    'INITIAL HOST STATE'      => 6, # LOGCLASS_STATE
    'CURRENT HOST STATE'      => 6, # LOGCLASS_STATE
    'HOST ALERT'              => 1, # LOGCLASS_ALERT
    'HOST DOWNTIME ALERT'     => 1, # LOGCLASS_ALERT
    'HOST FLAPPING ALERT'     => 1, # LOGCLASS_ALERT

    'INITIAL SERVICE STATE'   => 6, #LOGCLASS_STATE
    'CURRENT SERVICE STATE'   => 6, # LOGCLASS_STATE
    'SERVICE ALERT'           => 1, # LOGCLASS_ALERT
    'SERVICE DOWNTIME ALERT'  => 1, # LOGCLASS_ALERT
    'SERVICE FLAPPING ALERT'  => 1, # LOGCLASS_ALERT

    'TIMEPERIOD TRANSITION'   => 6, # LOGCLASS_STATE

    'HOST NOTIFICATION'       => 3, # LOGCLASS_NOTIFICATION
    'SERVICE NOTIFICATION'    => 3, # LOGCLASS_NOTIFICATION

    'PASSIVE SERVICE CHECK'   => 4, # LOGCLASS_PASSIVECHECK
    'PASSIVE HOST CHECK'      => 4, # LOGCLASS_PASSIVECHECK

    'SERVICE EVENT HANDLER'   => 0, # INFO
    'HOST EVENT HANDLER'      => 0, # INFO

    'EXTERNAL COMMAND'        => 5, # LOGCLASS_COMMAND
    'LOG ROTATION'            => 0, # INFO
};

$Thruk::Backend::Provider::Mysql::db_classes = {
    'INFO'          => 0,
    'ALERT'         => 1,
    'PROGRAMM'      => 2,
    'NOTIFICATION'  => 3,
    'PASSIVE'       => 4,
    'COMMAND'       => 5,
    'STATE'         => 6,
};

use constant {
    MODE_IMPORT         => 1,
    MODE_UPDATE         => 2,
};

@Thruk::Backend::Provider::Mysql::tables = (qw/contact contact_host_rel contact_service_rel host log service status/);

##########################################################

=head2 new

create new manager

=cut
sub new {
    my($class, $peer_config) = @_;

    my $options = $peer_config->{'options'};
    confess('need at least one peer. Minimal options are <options>peer = mysql://user:password@host:port/dbname</options>'."\ngot: ".Dumper($peer_config)) unless defined $options->{'peer'};

    $options->{'name'} = 'mysql' unless defined $options->{'name'};
    if(!defined $options->{'peer_key'}) {
        confess('please provide peer_key');
    }
    my($dbhost, $dbport, $dbuser, $dbpass, $dbname, $dbsock);
    if($options->{'peer'} =~ m/^mysql:\/\/(.*?)(|:.*?)@([^:]+)(|:.*?)\/([^\/]*?)$/mx) {
        $dbuser = $1;
        $dbpass = $2;
        $dbhost = $3;
        $dbport = $4;
        $dbname = $5;
        $dbpass =~ s/^://gmx;
        $dbport =~ s/^://gmx;
        if($dbhost =~ m|/|mx) {
            $dbsock = $dbhost;
            $dbhost = 'localhost';
        }
    } else {
        die('Mysql connection must match this form: mysql://user:password@host:port/dbname');
    }

    my $self = {
        'dbhost'      => $dbhost,
        'dbport'      => $dbport,
        'dbname'      => $dbname,
        'dbuser'      => $dbuser,
        'dbpass'      => $dbpass,
        'dbsock'      => $dbsock,
        'peer_config' => $options,
        'verbose'     => 0,
    };
    bless $self, $class;

    return $self;
}

##########################################################

=head2 reconnect

recreate database connection

=cut
sub reconnect {
    my($self) = @_;
    $self->_disconnect();
    return;
}

##########################################################

=head2 _disconnect

close database connection

=cut
sub _disconnect {
    my($self) = @_;
    if(defined $self->{'mysql'}) {
        #&timing_breakpoint('disconnect');
        $self->{'mysql'}->disconnect();
        delete $self->{'mysql'};
    }
    return;
}

##########################################################

=head2 _dbh

try to connect to database and return database handle

=cut
sub _dbh {
    my($self) = @_;
    if(!defined $self->{'mysql'}) {
        #&timing_breakpoint('connecting '.$self->{'dbname'}.' '.($self->{'dbsock'} || $self->{'dbhost'}).($self->{'dbport'} ? ':'.$self->{'dbport'} : ''));
        if(!$self->{'modules_loaded'}) {
            load DBI;
            load File::Temp, qw/tempfile/;
            load Encode, qw/encode_utf8/;
            $self->{'modules_loaded'} = 1;
        }
        my $dsn = "DBI:mysql:database=".$self->{'dbname'}.";host=".$self->{'dbhost'};
        $dsn .= ";port=".$self->{'dbport'} if $self->{'dbport'};
        $dsn .= ";mysql_socket=".$self->{'dbsock'} if $self->{'dbsock'};
        $self->{'mysql'} = DBI->connect($dsn, $self->{'dbuser'}, $self->{'dbpass'}, {RaiseError => 1, AutoCommit => 0, mysql_enable_utf8 => 1, mysql_local_infile => 1});
        $self->{'mysql'}->do("SET NAMES utf8 COLLATE utf8_bin");
        $self->{'mysql'}->do("SET myisam_stats_method=nulls_ignored");
        #&timing_breakpoint('connected');
    }
    return $self->{'mysql'};
}

##########################################################

=head2 peer_key

return the peers key

=cut
sub peer_key {
    my($self, $new_val) = @_;
    if(defined $new_val) {
        $self->{'peer_config'}->{'peer_key'} = $new_val;
    }
    return $self->{'peer_config'}->{'peer_key'};
}


##########################################################

=head2 peer_addr

return the peers address

=cut
sub peer_addr {
    my $self = shift;
    return $self->{'peer_config'}->{'peer'};
}

##########################################################

=head2 peer_name

return the peers name

=cut
sub peer_name {
    my $self = shift;
    return $self->{'peer_config'}->{'name'};
}

##########################################################

=head2 send_command

=cut
sub send_command {
    confess("not implemented");
}

##########################################################

=head2 get_processinfo

=cut
sub get_processinfo {
    confess("not implemented");
}

##########################################################

=head2 get_sites

=cut

sub get_sites {
    confess("unimplemented");
}

##########################################################

=head2 get_can_submit_commands

=cut
sub get_can_submit_commands {
    confess("not implemented");
}

##########################################################

=head2 get_contactgroups_by_contact

=cut
sub get_contactgroups_by_contact {
    confess("not implemented");
}

##########################################################

=head2 get_hosts

=cut
sub get_hosts {
    confess("not implemented");
}

##########################################################

=head2 get_hosts_by_servicequery

=cut
sub get_hosts_by_servicequery {
    confess("not implemented");
}

##########################################################

=head2 get_host_names

=cut
sub get_host_names{
    confess("not implemented");
}

##########################################################

=head2 get_hostgroups

=cut
sub get_hostgroups {
    confess("not implemented");
}

##########################################################

=head2 get_hostgroup_names

=cut
sub get_hostgroup_names {
    confess("not implemented");
}

##########################################################

=head2 get_services

=cut
sub get_services {
    confess("not implemented");
}

##########################################################

=head2 get_service_names

=cut
sub get_service_names {
    confess("not implemented");
}

##########################################################

=head2 get_servicegroups

=cut
sub get_servicegroups {
    confess("not implemented");
}

##########################################################

=head2 get_servicegroup_names

=cut
sub get_servicegroup_names {
    confess("not implemented");
}

##########################################################

=head2 get_comments

=cut
sub get_comments {
    confess("not implemented");
}

##########################################################

=head2 get_downtimes

=cut
sub get_downtimes {
    confess("not implemented");
}

##########################################################

=head2 get_contactgroups

=cut
sub get_contactgroups {
    confess("not implemented");
}

##########################################################

=head2 get_logs

  get_logs

returns logfile entries

=cut
sub get_logs {
    my($self, %options) = @_;

    my $orderby = '';
    my $sorted  = 0;
    if(defined $options{'sort'}->{'DESC'} and $options{'sort'}->{'DESC'} eq 'time') {
        $orderby = ' ORDER BY l.time DESC';
        $sorted  = 1;
    }
    if(defined $options{'sort'}->{'ASC'} and $options{'sort'}->{'ASC'} eq 'time') {
        $orderby = ' ORDER BY l.time ASC';
        $sorted  = 1;
    }
    my $limit = '';
    if(defined $options{'options'} && $options{'options'}->{'limit'}) {
        $limit = ' LIMIT '.$options{'options'}->{'limit'};
    }

    my $prefix = $options{'collection'};
    $prefix    =~ s/^logs_//gmx;
    my $dbh = $self->_dbh;

    $self->{'query_meta'} = {
        dbh     => $dbh,
        prefix  => $prefix,
    };
    my($where,$auth_data) = $self->_get_filter($options{'filter'});

    return unless _tables_exist($dbh, $prefix);

    # check logcache version
    my @versions = @{$dbh->selectcol_arrayref('SELECT value FROM `'.$prefix.'_status` WHERE status_id = 4 LIMIT 1')};
    if(scalar @versions < 1 || $versions[0] != $Thruk::Backend::Provider::Mysql::cache_version) {
        confess(sprintf("Logcache too old, required version %s but got %s. Run 'thruk logcache update' to upgrade.", $Thruk::Backend::Provider::Mysql::cache_version, $versions[0] // '0'));
    }

    # check compact timerange and set a warning flag
    my $c =$Thruk::Request::c;
    if($c) {
        my $compact_start_data = Thruk::Backend::Manager::get_expanded_start_date($c, $c->config->{'logcache_compact_duration'});
        # get time filter
        my($start, $end) = Thruk::Backend::Manager::extract_time_filter($options{'filter'});
        if($start && $start < $compact_start_data) {
            $c->stash->{'logs_from_compacted_zone'} = 1;
        }
        elsif($end && $end < $compact_start_data) {
            $c->stash->{'logs_from_compacted_zone'} = 1;
        }
    }

    my $sql = '
    SELECT
        l.time as time,
        l.class as class,
        l.type as type,
        l.state as state,
        l.state_type as state_type,
        IFNULL(h.host_name, "") as host_name,
        IFNULL(s.service_description, "") as service_description,
        IFNULL(c.name, "") as contact_name,
        l.message as message,
        "'.$prefix.'" as peer_key
    FROM
        `'.$prefix.'_log` l
        LEFT JOIN `'.$prefix.'_host` h ON l.host_id = h.host_id
        LEFT JOIN `'.$prefix.'_service` s ON l.service_id = s.service_id
        LEFT JOIN `'.$prefix.'_contact` c ON l.contact_id = c.contact_id
    '.$where.'
    '.$orderby.'
    '.$limit.'
    ';
    confess($sql) if $sql =~ m/(ARRAY|HASH)/mx;

    # logfiles into tmp file
    my($fh, $filename);
    if($options{'file'}) {
        ($fh, $filename) = tempfile();
        open($fh, '>', $filename) or die('open '.$filename.' failed: '.$!);
    }

    # add performance related debug output
    if(Thruk->verbose >= 3) {
        _trace($sql);

        _trace("EXPLAIN:");
        _trace(_sql_debug("EXPLAIN\n".$sql, $dbh));

        my $debug_sql = "SHOW INDEXES FROM `".$prefix."_log`";
        _trace($debug_sql.":");
        _trace(_sql_debug($debug_sql, $dbh));
    }

    # queries with authorization
    my $data;
    if($auth_data->{'username'}) {
        my($contact,$strict,$authorized_for_all_services,$authorized_for_all_hosts,$authorized_for_system_information) = ($auth_data->{'username'},$auth_data->{'strict'},$auth_data->{'authorized_for_all_services'},$auth_data->{'authorized_for_all_hosts'},$auth_data->{'authorized_for_system_information'});
        my $sth = $dbh->prepare($sql);
        $sth->execute;

        my $hosts_lookup    = $self->_get_log_host_auth($dbh, $prefix, $contact);
        my $services_lookup = $self->_get_log_service_auth($dbh, $prefix, $contact);

        while(my $r = $sth->fetchrow_hashref()) {
            if($r->{'service_description'}) {
                if($authorized_for_all_services) {
                }
                elsif($strict) {
                    next if(!defined $services_lookup->{$r->{'host_name'}}->{$r->{'service_description'}});
                } else {
                    next if(!defined $hosts_lookup->{$r->{'host_name'}} && !defined $services_lookup->{$r->{'host_name'}}->{$r->{'service_description'}});
                }
            }
            elsif($r->{'host_name'}) {
                if($authorized_for_all_hosts) {
                } else {
                    next if !defined $hosts_lookup->{$r->{'host_name'}};
                }
            }
            else {
                next if !$authorized_for_system_information;
            }
            if($fh) {
                print $fh encode_utf8($r->{'message'}),"\n";
            } else {
                push @{$data}, $r;
            }
        }
    }
    else {
        if($fh) {
            my $sth = $dbh->prepare($sql);
            $sth->execute;
            while(my $r = $sth->fetchrow_arrayref()) {
                print $fh encode_utf8($r->[8]),"\n";
            }
        } else {
            $data = $dbh->selectall_arrayref($sql, { Slice => {} });
        }
    }

    if($fh) {
        my $rc = Thruk::Utils::IO::close($fh, $filename);
        if(!$rc) {
            unlink($filename);
            confess("writing logs to $filename failed: $!");
        }
        return($filename, 'file');
    } else {
        return($data, ($sorted ? 'sorted' : ''));
    }
}

##########################################################

=head2 get_timeperiods

=cut
sub get_timeperiods {
    confess("not implemented");
}

##########################################################

=head2 get_timeperiod_names

=cut
sub get_timeperiod_names {
    confess("not implemented");
}

##########################################################

=head2 get_commands

=cut
sub get_commands {
    confess("not implemented");
}

##########################################################

=head2 get_contacts

=cut
sub get_contacts {
    confess("not implemented");
}

##########################################################

=head2 get_contact_names

=cut
sub get_contact_names {
    confess("not implemented");
}

##########################################################

=head2 get_host_stats

=cut
sub get_host_stats {
    confess("not implemented");
}

##########################################################

=head2 get_host_totals_stats

  get_host_totals_stats

returns the host statistics used on the service/host details page

=cut

sub get_host_totals_stats {
    confess("not implemented");
}

##########################################################

=head2 get_service_stats

=cut
sub get_service_stats {
    confess("not implemented");
}

##########################################################

=head2 get_service_totals_stats

  get_service_totals_stats

returns the services statistics used on the service/host details page

=cut

sub get_service_totals_stats {
    confess("not implemented");
}

##########################################################

=head2 get_performance_stats

=cut
sub get_performance_stats {
    confess("not implemented");
}

##########################################################

=head2 get_extra_perf_stats

=cut
sub get_extra_perf_stats {
    confess("not implemented");
}

##########################################################

=head2 set_verbose

  set_verbose

sets verbose mode for this backend and returns old value

=cut
sub set_verbose {
    my($self, $val) = @_;
    my $old = $self->{'verbose'};
    $self->{'verbose'} = $val;
    return($old);
}

##########################################################

=head2 renew_logcache

  renew_logcache

renew logcache

=cut
sub renew_logcache {
    return;
}

##########################################################

=head2 _add_peer_data

  _add_peer_data

add peer name, addr and key to result array

=cut
sub _add_peer_data {
    my($self, $data) = @_;
    for my $d (@{$data}) {
        $d->{'peer_name'} = $self->peer_name;
        $d->{'peer_addr'} = $self->peer_addr;
        $d->{'peer_key'}  = $self->peer_key;
    }
    return $data;
}

##########################################################

=head2 _get_filter

  _get_filter

return Mysql filter

=cut
sub _get_filter {
    my($self, $inp) = @_;
    my $auth_data = {};
    if($inp && ref $inp eq 'ARRAY') {
        for my $f (@{$inp}) {
            if(ref $f eq 'HASH' && $f->{'auth_filter'}) {
                $auth_data = $f->{'auth_filter'};
                $f = undef;
            }
        }
    }
    my $filter = $self->_get_subfilter($inp);
    if($filter and ref $filter) {
        $filter = '('.join(' AND ', @{$filter}).')';
    }
    $filter = " WHERE ".$filter if $filter;

    $filter =~ s/WHERE\ \(\((.*)\)\ AND\ \)/WHERE ($1)/gmx;
    $filter =~ s/\Qtype = ''\E/type IS NULL/gmx;
    $filter =~ s/\ AND\ \)/)/gmx;
    $filter =~ s/\(\ AND\ \(/((/gmx;
    $filter =~ s/AND\s+AND/AND/gmx;
    $filter = '' if $filter eq ' WHERE ';

    return($filter, $auth_data);
}

##########################################################

=head2 _get_subfilter

  _get_subfilter

return Mysql filter

=cut
sub _get_subfilter {
    my($self, $inp, $f) = @_;
    return '' unless defined $inp;
    if(ref $inp eq 'ARRAY') {
        # empty lists
        return '' if scalar @{$inp} == 0;

        # single array items will be stripped from array
        if(scalar @{$inp} == 1) {
            return $self->_get_subfilter($inp->[0]);
        }

        my $x   = 0;
        my $num = scalar @{$inp};
        my $filter = [];
        while($x < $num) {
            # [ 'key', { 'op' => 'value' } ]
            if(exists $inp->[$x+1] and ref $inp->[$x] eq '' and ref $inp->[$x+1] eq 'HASH') {
                my $key = $inp->[$x];
                my $val = $inp->[$x+1];
                if(!defined $key) {
                    $x=$x+1;
                    next;
                }
                push @{$filter}, $self->_get_subfilter({$key => $val});
                $x=$x+2;
                next;
            }
            # [ '-or', [ 'key' => 'value' ] ]
            if(exists $inp->[$x+1] and ref $inp->[$x] eq '' and ref $inp->[$x+1] eq 'ARRAY') {
                my $key = $inp->[$x];
                my $val = $inp->[$x+1];
                if(!defined $key) {
                    $x=$x+1;
                    next;
                }
                push @{$filter}, $self->_get_subfilter({$key => $val});
                $x=$x+2;
                next;
            }

            # [ 'key', 'value' ] => { 'key' => 'value' }
            if(exists $inp->[$x+1] and ref $inp->[$x] eq '' and ref $inp->[$x+1] eq '') {
                my $key = $inp->[$x];
                my $val = $inp->[$x+1];
                push @{$filter}, $self->_get_subfilter({$key => $val});
                $x=$x+2;
                next;
            }

            if(defined $inp->[$x]) {
                my $f =  $self->_get_subfilter($inp->[$x]);
                if($f and ref $f) {
                    $f= '('.join(' AND ', @{$f}).')';
                }
                push @{$filter}, $f;
            }
            $x++;
        }
        if(scalar @{$filter} == 1) {
            return $filter->[0];
        }
        return $filter;
    }
    if(ref $inp eq 'HASH') {
        # single hash elements with an operator
        if(scalar keys %{$inp} == 1) {
            my $k = [keys   %{$inp}]->[0];
            my $v = [values %{$inp}]->[0];
            if($k eq '=')                           { return '= '._quote($v); }
            if($k eq '!=')                          { return '!= '._quote($v); }
            if($k eq '~')                           { return 'RLIKE '._quote_backslash(_quote(Thruk::Utils::clean_regex($v))); }
            if($k eq '~~')                          { return 'RLIKE '._quote_backslash(_quote(Thruk::Utils::clean_regex($v))); }
            if($k eq '!~~')                         { return 'NOT RLIKE '._quote_backslash(_quote(Thruk::Utils::clean_regex($v))); }
            if($k eq '>='  and ref $v eq 'ARRAY')   { confess("whuus") unless defined $f; return '= '.join(' OR '.$f.' = ', @{_quote($v)}); }
            if($k eq '!>=' and ref $v eq 'ARRAY')   { confess("whuus") unless defined $f; return '!= '.join(' OR '.$f.' != ', @{_quote($v)}); }
            if($k eq '!>=')                         { return '!= '._quote($v); }
            if($k eq '>=' and $v !~ m/^[\d\.]+$/mx) { return 'IN ('._quote($v).')'; }
            if($k eq '>=')                          { return '>= '._quote($v); }
            if($k eq '<=')                          { return '<= '._quote($v); }
            if($k eq '>')                           { return '> '._quote($v); }
            if($k eq '<')                           { return '< '._quote($v); }
            if($k eq '-or') {
                my $list = $self->_get_subfilter($v);
                if(ref $list) {
                    # remove empty elements
                    @{$list} = grep(!/^$/mx, @{$list});
                    for my $l (@{$list}) {
                        if(ref $l eq 'ARRAY') {
                            $l = '('.join(' AND ', @{$l}).')';
                        }
                    }
                    return('('.join(' OR ', @{$list}).')');
                }
                return $list;
            }
            if($k eq '-and') {
                my $list = $self->_get_subfilter($v);
                if(ref $list) {
                    @{$list} = grep(!/^$/mx, @{$list});
                    for my $l (@{$list}) {
                        if(ref $l eq 'ARRAY') {
                            $l = '('.join(' AND ', @{$l}).')';
                        }
                    }
                    return('('.join(' AND ', @{$list}).')');
                }
                return $list;
            }
            if(ref $v) {
                $v = $self->_get_subfilter($v, $k);
                if($v =~ m/\ OR\ $k\ /mx) {
                    return '('.$k.' '.$v.')';
                }
                return $k.' '.$v;
            }
            # using ids makes mysql prefer index
            if($k eq 'host_name' && $self->{'query_meta'}->{'prefix'}) {
                $k = 'l.host_id';
                $self->{'query_meta'}->{'host_lookup'} = _get_host_lookup($self->{'query_meta'}->{'dbh'},undef,$self->{'query_meta'}->{'prefix'}, 1) unless defined $self->{'query_meta'}->{'host_lookup'};
                $v = $self->{'query_meta'}->{'host_lookup'}->{$v} // 0;
            }
            if($k eq 'contact_name') {
                $k = 'c.name';
            }
            return $k.' = '._quote($v);
        }

        # multiple keys will be converted to list
        # { 'key' => 'v', 'key2' => v }
        my $list = [];
        for my $k (sort keys %{$inp}) {
            push @{$list}, {$k => $inp->{$k}};
        }
        return $self->_get_subfilter({'-and' => $list});
    }
    return $inp;
}

##########################################################
sub _quote {
    return "''" unless defined $_[0];
    if(ref $_[0] eq 'ARRAY') {
        my $list = [];
        for my $v (@{$_[0]}) {
            push @{$list}, _quote($v);
        }
        return $list;
    }
    if($_[0] =~ m/^\-?(\d+|\d+\.\d+)$/mx) {
        return $_[0];
    }
    $_[0] =~ s/'/\'/gmx;
    return("'".$_[0]."'");
}

##########################################################
sub _quote_backslash {
    return '' unless defined $_[0];
    $_[0] =~ s|\\|\\\\|gmx;
    return($_[0]);
}

##########################################################

=head2 get_logs_start_end

  get_logs_start_end

returns first and last logfile entry

=cut
sub get_logs_start_end {
    return(_get_logs_start_end(@_));
}

##########################################################

=head2 _get_logs_start_end

  _get_logs_start_end

returns the min/max timestamp for given logs

=cut
sub _get_logs_start_end {
    my($self, %options) = @_;
    my($start, $end);
    my $prefix = $options{'collection'} || $self->{'peer_config'}->{'peer_key'};
    $prefix    =~ s/^logs_//gmx;
    my $dbh  = $options{'dbh'} || $self->_dbh();
    return([$start, $end]) unless _tables_exist($dbh, $prefix);
    my $where = "";
    ($where) = $self->_get_filter($options{'filter'}) if $options{'filter'};
    my @data = @{$dbh->selectall_arrayref('SELECT MIN(l.time) as mi, MAX(l.time) as ma FROM `'.$prefix.'_log` l '.$where.' LIMIT 1', { Slice => {} })};
    $start   = $data[0]->{'mi'} if defined $data[0];
    $end     = $data[0]->{'ma'} if defined $data[0];
    return([$start, $end]);
}

##########################################################

=head2 _log_stats

  _log_stats

gather log statistics

=cut

sub _log_stats {
    my($self, $c, $backends) = @_;

    $c->stats->profile(begin => "Mysql::_log_stats");

    ($backends) = $c->{'db'}->select_backends('get_logs') unless defined $backends;
    $backends  = Thruk::Utils::list($backends);

    my @result;
    for my $key (@{$backends}) {
        my $peer = $c->{'db'}->get_peer_by_key($key);
        next unless $peer->{'logcache'};
        $peer->logcache->reconnect();
        my $dbh  = $peer->logcache->_dbh();
        my $res  = $dbh->selectall_hashref("SHOW TABLE STATUS LIKE '".$key."%'", 'Name');
        next unless defined $res->{$key.'_log'};
        my $index_size = $res->{$key.'_log'}->{'Index_length'};
        my $data_size  = $res->{$key.'_log'}->{'Data_length'};
        my $status  = $dbh->selectall_hashref("SELECT name, value FROM `".$key."_status`", 'name');
        my(undef, $last_entry) = @{$self->_get_logs_start_end(collection => $key, dbh => $dbh)};
        push @result, {
            key              => $key,
            name             => $c->stash->{'backend_detail'}->{$key}->{'name'},
            index_size       => $index_size,
            data_size        => $data_size,
            items            => $res->{$key.'_log'}->{'Rows'},
            cache_version    => $status->{'cache_version'}->{'value'},
            last_update      => $status->{'last_update'}->{'value'},
            last_reorder     => $status->{'last_reorder'}->{'value'},
            last_compact     => $status->{'last_compact'}->{'value'},
            reorder_duration => $status->{'reorder_duration'}->{'value'} // '',
            update_duration  => $status->{'update_duration'}->{'value'} // '',
            compact_duration => $status->{'compact_duration'}->{'value'} // '',
            compact_till     => $status->{'compact_till'}->{'value'} // '',
            last_entry       => $last_entry // '',
        };
    }

    $c->stats->profile(end => "Mysql::_log_stats");
    return @result if wantarray;
    return Thruk::Utils::text_table(
        keys => [['Backend', 'name'],
                 { name => 'Index Size',  key => 'index_size', type => 'bytes', format => "%.1f" },
                 { name => 'Data Size',   key => 'data_size',  type => 'bytes', format => "%.1f" },
                 ['Items', 'items'],
                 { name => 'Last Update', key => 'last_update', type => 'date', format => '%Y-%m-%d %H:%M:%S' },
                 { name => 'Last Item',   key => 'last_entry',  type => 'date', format => '%Y-%m-%d %H:%M:%S' },
                ],
        data => \@result,
    );
}

##########################################################

=head2 _logcache_stats_types

  _logcache_stats_types

gather log type statistics

=cut

sub _logcache_stats_types {
    my($self, $c, $groupby, $backends) = @_;

    $c->stats->profile(begin => "Mysql::_logcache_stats_types: ".$groupby);

    ($backends) = $c->{'db'}->select_backends('get_logs') unless defined $backends;
    $backends  = Thruk::Utils::list($backends);

    my @result;
    for my $key (@{$backends}) {
        my $peer = $c->{'db'}->get_peer_by_key($key);
        next unless $peer->{'logcache'};
        $peer->logcache->reconnect();
        my $dbh  = $peer->logcache->_dbh();
        my $res  = $dbh->selectall_hashref("SHOW TABLE STATUS LIKE '".$key."%'", 'Name');
        next unless defined $res->{$key.'_log'};
        my $types  = [values %{$dbh->selectall_hashref("SELECT IFNULL(".$groupby.", '') as $groupby, count(*) as total FROM `".$key."_log` GROUP BY ".$groupby, $groupby)}];
        $types     = [reverse sort { $a->{'total'} <=> $b->{'total'} } @{$types}];
        my $total = 0;
        for my $t (@{$types}) {
            $total += $t->{'total'};
        }
        for my $t (@{$types}) {
            $t->{'procent'} = 0;
            if($total > 0) {
                $t->{'procent'} = $t->{'total'} * 100 / $total;
            }
        }
        push @result, {
            key     => $key,
            name    => $c->stash->{'backend_detail'}->{$key}->{'name'},
            types   => $types,
        };
    }

    $c->stats->profile(end => "Mysql::_logcache_stats_types: ".$groupby);
    return \@result;
}

##########################################################

=head2 _log_removeunused

  _log_removeunused

remove logcache tables from backends which do no longer exist

=cut

sub _log_removeunused {
    my($self, $c, $print_only) = @_;
    $c->stats->profile(begin => "Mysql::_log_removeunused");

    # use first peers logcache
    my $peer;
    for my $key (@{$c->stash->{'backends'}}) {
        $peer = $c->{'db'}->get_peer_by_key($key);
        last if $peer->{'logcache'};
    }
    return "no logcache configured?" unless(defined $peer and defined $peer->{'logcache'});

    $peer->logcache->reconnect();
    my $dbh  = $peer->logcache->_dbh();
    my $res  = $dbh->selectall_hashref("SHOW TABLE STATUS", 'Name');

    # gather backend ids
    my $backends = {};
    for my $tbl (keys %{$res}) {
        if($tbl =~ m/^(.*?)_(status|log)/mx) {
            $backends->{$1} = 1;
        }
    }

    # do not remove the ones still existing
    for my $key (@{$c->stash->{'backends'}}) {
        delete $backends->{$key};
    }
    return($backends) if $print_only;

    my $removed = 0;
    my $tables  = 0;
    for my $key (keys %{$backends}) {
        for my $tbl (keys %{$res}) {
            next unless $tbl =~ m/^${key}_/mx;
            $tables++;
            $dbh->do("DROP TABLE `".$tbl."`");
        }
        $removed++;
    }
    $dbh->commit || confess $dbh->errstr;

    return "no old tables found in logcache" if $removed == 0;

    $c->stats->profile(end => "Mysql::_log_removeunused");
    return $removed." old backends removed (".$tables." tables) from logcache";
}

##########################################################

=head2 _import_logs

  _import_logs

imports logs into Mysql

=cut

sub _import_logs {
    my($self, $c, $mode, $backends, $blocksize, $options) = @_;
    my $files = $options->{'files'} || [];
    $c->stats->profile(begin => "Mysql::_import_logs($mode)");

    my $forcestart;
    if($options->{'start'}) {
        $forcestart = time() - Thruk::Utils::expand_duration($options->{'start'});
    }

    my $backend_count = 0;
    my $log_count     = 0;

    if(!defined $backends) {
        Thruk::Action::AddDefaults::set_possible_backends($c, {}) unless defined $c->stash->{'backends'};
        $backends = $c->stash->{'backends'};
    }
    $backends = Thruk::Utils::list($backends);
    my @peer_keys;
    for my $key (@{$backends}) {
        my $peer   = $c->{'db'}->get_peer_by_key($key);
        next unless $peer->{'enabled'};
        push @peer_keys, $key;
    }

    if(scalar @peer_keys > 1 and scalar @{$files} > 0) {
        _error("you must specify a backend (-b) when importing files.");
        return(0, -1);
    }

    my $errors = [];
    for my $key (@{$backends}) {
        my $prefix = $key;
        my $peer   = $c->{'db'}->get_peer_by_key($key);
        next unless $peer->{'enabled'};
        next unless $peer->{'logcache'};
        $c->stats->profile(begin => "$key");
        $backend_count++;
        $peer->logcache->reconnect();
        my $dbh = $peer->logcache->_dbh;

        _info("running ".$mode." for site ".$c->stash->{'backend_detail'}->{$key}->{'name'});

        # backends maybe down, we still want to continue updates
        eval {
            my $count;
            if($mode eq 'update' or $mode eq 'import') {
                $count = $peer->logcache->_update_logcache($c, $mode, $peer, $dbh, $prefix, $blocksize, $files, $forcestart);
            }
            elsif($mode eq 'clean') {
                my $tmp = $peer->logcache->_update_logcache($c, $mode, $peer, $dbh, $prefix, $blocksize, $files, $forcestart);
                $log_count = [0,0] unless ref $log_count eq 'ARRAY';
                $log_count->[0] += $tmp->[0];
                $log_count->[1] += $tmp->[1];
            }
            elsif($mode eq 'compact') {
                my $tmp = $peer->logcache->_update_logcache($c, $mode, $peer, $dbh, $prefix, $blocksize, $files, $forcestart, $options->{'force'});
                $log_count = [0,0] unless ref $log_count eq 'ARRAY';
                $log_count->[0] += $tmp->[0];
                $log_count->[1] += $tmp->[1];
            }
            elsif($mode eq 'drop') {
                $peer->logcache->_update_logcache($c, $mode, $peer, $dbh, $prefix, $blocksize, $files, $forcestart);
            }
            elsif($mode eq 'authupdate') {
                $count = $peer->logcache->_update_logcache_auth($c, $peer, $dbh, $prefix);
            }
            elsif($mode eq 'optimize') {
                $count = $peer->logcache->_update_logcache_optimize($c, $peer, $dbh, $prefix, $options);
            } else {
                die("unknown mode: ".$mode."\n");
            }
            $log_count += $count if($count && $count > 0);
        };
        my $err = $@;
        if($err) {
            _debug($err);
            push @{$errors}, $err;
        }

        # cleanup connection
        eval {
            $peer->logcache->_disconnect();
        };

        $c->stats->profile(end => "$key");
    }

    $c->stats->profile(end => "Mysql::_import_logs($mode)");
    return($backend_count, $log_count, $errors);
}

##########################################################
sub _update_logcache {
    my($self, $c, $mode, $peer, $dbh, $prefix, $blocksize, $files, $forcestart,$force) = @_;

    #&timing_breakpoint('_update_logcache');
    unless(defined $blocksize) {
        $blocksize = 86400;
        if($mode eq 'clean') {
            $blocksize = Thruk::Utils::expand_duration($c->config->{'logcache_clean_duration'}) / 86400;
        }
        if($mode eq 'compact') {
            $blocksize = Thruk::Utils::expand_duration($c->config->{'logcache_compact_duration'}) / 86400;
        }
    }

    if($mode eq 'drop') {
        _drop_tables($dbh, $prefix);
        return;
    }

    if($mode eq 'update') {
        $mode = 'import' if _update_logcache_version($c, $dbh, $prefix);
    }

    # check tables
    _drop_tables($dbh, $prefix) if $mode eq 'import';
    my $fresh_created = 0;
    if(_create_tables_if_not_exist($dbh, $prefix)) {
        $fresh_created = 1;
    }

    return(-1) unless _check_lock($dbh, $prefix, $c);

    if($mode eq 'clean') {
        return(_update_logcache_clean($dbh, $prefix, $blocksize));
    }
    if($mode eq 'compact') {
        return($self->_update_logcache_compact($c, $dbh, $prefix, $blocksize, $force));
    }

    $mode = 'import' if $fresh_created;
    my $start = time();

    my $log_count = 0;
    eval {
        my $host_lookup    = _get_host_lookup(   $dbh,$peer,$prefix,               $mode eq 'import' ? 0 : 1);
        my $service_lookup = _get_service_lookup($dbh,$peer,$prefix, $host_lookup, $mode eq 'import' ? 0 : 1);
        my $contact_lookup = _get_contact_lookup($dbh,$peer,$prefix,               $mode eq 'import' ? 0 : 1);

        if(defined $files and scalar @{$files} > 0) {
            $log_count += $self->_import_logcache_from_file($mode,$dbh,$files,$host_lookup,$service_lookup,$prefix,$contact_lookup,$c);
        } else {
            $log_count += $self->_import_peer_logfiles($c,$mode,$peer,$blocksize,$dbh,$host_lookup,$service_lookup,$prefix,$contact_lookup,$forcestart);
        }

        if($mode eq 'import') {
            _debug2("updateing auth cache");
            $self->_update_logcache_auth($c, $peer, $dbh, $prefix);
        }
    };
    my $error = $@ || '';

    _finish_update($c, $dbh, $prefix, time() - $start) or $error .= $dbh->errstr;

    if($error) {
        _error('logcache '.$mode.' failed: '.$error);
        die($error);
    }

    return $log_count;
}

##########################################################
sub _finish_update {
    my($c, $dbh, $prefix, $duration) = @_;
    $dbh->do("INSERT INTO `".$prefix."_status` (status_id,name,value) VALUES(1,'last_update',UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE value=UNIX_TIMESTAMP()");
    $dbh->do("INSERT INTO `".$prefix."_status` (status_id,name,value) VALUES(2,'update_pid',NULL) ON DUPLICATE KEY UPDATE value=NULL");
    $dbh->do("INSERT INTO `".$prefix."_status` (status_id,name,value) VALUES(6,'update_duration','".$duration."') ON DUPLICATE KEY UPDATE value='".$duration."'");
    _release_write_locks($dbh) unless $c->config->{'logcache_pxc_strict_mode'};
    $dbh->commit || return;
    return 1;
}

##########################################################
# returns 1 if tables have been newly created or undef if already exist
sub _create_tables_if_not_exist {
    my($dbh, $prefix) = @_;

    return if _tables_exist($dbh, $prefix);

    _debug2("creating logcache tables");
    _create_tables($dbh, $prefix);
    return 1;
}

##########################################################
# returns 1 if logcache tables exist, undef if not
sub _tables_exist {
    my($dbh, $prefix) = @_;

    # check if our tables exist
    my @tables = @{$dbh->selectcol_arrayref('SHOW TABLES LIKE "'.$prefix.'\_%"')};
    if(scalar @tables >= 1) {
        return 1;
    }

    return;
}

##########################################################
sub _check_lock {
    my($dbh, $prefix, $c) = @_;

    # check if there is already a update / import running
    my $skip          = 0;
    my $cache_version = 1;
    eval {
        $dbh->do('LOCK TABLES `'.$prefix.'_status` READ') unless $c->config->{'logcache_pxc_strict_mode'};
        my @pids = @{$dbh->selectcol_arrayref('SELECT value FROM `'.$prefix.'_status` WHERE status_id = 2 LIMIT 1')};
        if(scalar @pids > 0 and $pids[0]) {
            if(kill(0, $pids[0])) {
                _info("WARNING: logcache update already running with pid ".$pids[0]);
                $skip = 1;
            }
        }
        my @versions = @{$dbh->selectcol_arrayref('SELECT value FROM `'.$prefix.'_status` WHERE status_id = 4 LIMIT 1')};
        if(scalar @versions > 0 and $versions[0]) {
            $cache_version = $versions[0];
        }
    };
    $dbh->do('UNLOCK TABLES') unless $c->config->{'logcache_pxc_strict_mode'};
    if($@) {
        _debug($@);
        return;
    }
    if($skip) {
        return;
    }

    $dbh->do('LOCK TABLES `'.$prefix.'_status` WRITE') unless $c->config->{'logcache_pxc_strict_mode'};
    $dbh->do("INSERT INTO `".$prefix."_status` (status_id,name,value) VALUES(1,'last_update',UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE value=UNIX_TIMESTAMP()");
    $dbh->do("INSERT INTO `".$prefix."_status` (status_id,name,value) VALUES(2,'update_pid',".$$.") ON DUPLICATE KEY UPDATE value=".$$);
    $dbh->commit || confess $dbh->errstr;
    $dbh->do('UNLOCK TABLES') unless $c->config->{'logcache_pxc_strict_mode'};
    return(1);
}

##########################################################
sub _update_logcache_version {
    my($c, $dbh, $prefix) = @_;

    my $cache_version = 1;
    my @versions = @{$dbh->selectcol_arrayref('SELECT value FROM `'.$prefix.'_status` WHERE status_id = 4 LIMIT 1')};
    if(scalar @versions > 0 and $versions[0]) {
        $cache_version = $versions[0];
    }

    if($cache_version < $Thruk::Backend::Provider::Mysql::cache_version) {
        # only log message if not importing already
        my $msg = 'logcache version too old: '.$cache_version.', recreating with version '.$Thruk::Backend::Provider::Mysql::cache_version.'...';
        _warn($msg);
        return 1;
    }

    return;
}

##########################################################
sub _update_logcache_clean {
    my($dbh, $prefix, $blocksize) = @_;

    if($blocksize =~ m/^\d+[a-z]{1}/mx) {
        # blocksize is in days
        $blocksize = int(Thruk::Utils::expand_duration($blocksize) / 86400);
    }

    my $start = time() - ($blocksize * 86400);
    _debug2("cleaning logs older than: ", scalar localtime $start);
    my $plugin_ref_count = 0;
    my $log_count = $dbh->do("DELETE FROM `".$prefix."_log` WHERE time < ".$start);
    return([$log_count, $plugin_ref_count]) if $log_count == 0;

    $dbh->commit || confess $dbh->errstr;
    return([$log_count, $plugin_ref_count]);
}

##########################################################
sub _update_logcache_compact {
    my($self, $c, $dbh, $prefix, $blocksize, $force) = @_;
    my $log_count = 0;
    my $log_clear = 0;

    if($blocksize =~ m/^\d+[a-z]{1}/mx) {
        # blocksize is in days
        $blocksize = int(Thruk::Utils::expand_duration($blocksize) / 86400);
    }
    my $t1     = time();
    my $end  = Thruk::Utils::DateTime::start_of_day(time() - ($blocksize * 86400));
    _debug("compacting logs older than: ".(scalar localtime $end));
    my $status = $dbh->selectall_hashref("SELECT name, value FROM `".$prefix."_status`", 'name');
    my $start  = $status->{'compact_till'}->{'value'};
    if(!$start || $force) {
        my($mstart) = @{$self->_get_logs_start_end()};
        $start = $mstart;
    }
    if(!$start) {
        return([$log_count, $log_clear]);
    }
    my $current = $start;
    while(1) {
        if($current >= $end) {
            last;
        }

        _infos("compacting ".(scalar localtime $current). ": ");
        my $next = Thruk::Utils::DateTime::start_of_day($current + 26*86400); # add 2 extra hours to compensate timshifts

        my $sth = $dbh->prepare("SELECT log_id, class, type, state, state_type, host_id, service_id, message FROM `".$prefix."_log` WHERE time >= $current and time < $next");
        $sth->execute;
        my $processed = 0;
        my @delete;
        my $alerts = {};
        for my $l (@{$sth->fetchall_arrayref({})}) {
            $processed++;
            if($processed%10000 == 0) {
                $dbh->do("DELETE FROM `".$prefix."_log` WHERE log_id IN (".join(",", @delete).")");
                $dbh->commit || confess $dbh->errstr;
                $log_clear += scalar @delete;
                @delete = ();
                _infoc('.');
            }
            if(_is_compactable($l, $alerts)) {
                push @delete, $l->{'log_id'};
            }
        }

        _debug(sprintf("%d removed. done", scalar @delete));
        $current  = $next;
        $log_count += $processed;
        $log_clear += scalar @delete;

        if(scalar @delete > 0) {
            $dbh->do("DELETE FROM `".$prefix."_log` WHERE log_id IN (".join(",", @delete).")");
            $dbh->commit || confess $dbh->errstr;
        }
    }

    my $duration = time() - $t1;
    $dbh->do("INSERT INTO `".$prefix."_status` (status_id,name,value) VALUES(7,'last_compact',UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE value=UNIX_TIMESTAMP()");
    $dbh->do("INSERT INTO `".$prefix."_status` (status_id,name,value) VALUES(8,'compact_duration','".$duration."') ON DUPLICATE KEY UPDATE value='".$duration."'");
    $dbh->do("INSERT INTO `".$prefix."_status` (status_id,name,value) VALUES(9,'compact_till','".$end."') ON DUPLICATE KEY UPDATE value='".$end."'");

    $dbh->commit || confess $dbh->errstr;
    return([$log_count, $log_clear]);
}

##########################################################
# returns true if log entry can be removed during compact
sub _is_compactable {
    my($l, $alertstore) = @_;
    if($l->{'class'} == 2 || $l->{'class'} == 3 || $l->{'class'} == 5 || $l->{'class'} == 6) {
        # keep program, notifications, external commands, timeperiod transitions
        return;
    }
    elsif($l->{'class'} == 1) {
        if($l->{'type'} eq 'HOST DOWNTIME ALERT' || $l->{'type'} eq 'SERVICE DOWNTIME ALERT') {
            # keep downtimes
            return;
        }
        # remove duplicate alerts
        my $uniq = sprintf("%s;%s", $l->{'state_type'}//'', $l->{'state'}//'');
        if($l->{'type'} eq 'SERVICE ALERT') {
            my $host_id    = $l->{'host_id'} // $l->{'host_name'};
            my $service_id = $l->{'service_id'} // $l->{'service_description'};
            my $chk = $alertstore->{'svc'}->{$host_id}->{$service_id};
            if(!$chk || $chk ne $uniq) {
                $alertstore->{'svc'}->{$host_id}->{$service_id} = $uniq;
                return;
            }
        }
        elsif($l->{'type'} eq 'HOST ALERT') {
            my $host_id = $l->{'host_id'} // $l->{'host_name'};
            my $chk     = $alertstore->{'hst'}->{$host_id};
            if(!$chk || $chk ne $uniq) {
                $alertstore->{'hst'}->{$host_id} = $uniq;
                return;
            }
        }
    }
    return 1;
}

##########################################################
sub _update_logcache_auth {
    #my($self, $c, $peer, $dbh, $prefix) = @_;
    my($self, undef, $peer, $dbh, $prefix) = @_;

    # bad idea, this moves contact ids which are also used in notifications log entries
    #$dbh->do("TRUNCATE TABLE `".$prefix."_contact`");
    my $contact_lookup = _get_contact_lookup($dbh,$peer,$prefix);
    my $host_lookup    = _get_host_lookup($dbh,$peer,$prefix);
    my $service_lookup = _get_service_lookup($dbh,$peer,$prefix);

    # update hosts
    my($hosts)    = $peer->{'class'}->get_hosts(columns => [qw/name contacts/]);
    _debugs("hosts: ");
    my $stm = "INSERT INTO `".$prefix."_contact_host_rel` (contact_id, host_id) VALUES";
    $dbh->do("TRUNCATE TABLE `".$prefix."_contact_host_rel`");
    my $count = 0;
    for my $host (@{$hosts}) {
        my $host_id    = &_host_lookup($host_lookup, $host->{'name'}, $dbh, $prefix);
        my @values;
        for my $contact (@{$host->{'contacts'}}) {
            my $contact_id = _contact_lookup($contact_lookup, $contact, $dbh, $prefix);
            push @values, '('.$contact_id.','.$host_id.')';
        }
        $dbh->do($stm.join(',', @values)) if scalar @values > 0;
        $count++;
        _debugc(".") if $count%100 == 0;
    }
    _debug("done");

    # update services
    _debugs("services: ");
    $dbh->do("TRUNCATE TABLE `".$prefix."_contact_service_rel`");
    $stm = "INSERT INTO `".$prefix."_contact_service_rel` (contact_id, service_id) VALUES";
    my($services) = $peer->{'class'}->get_services(columns => [qw/host_name description contacts/]);
    $count = 0;
    for my $service (@{$services}) {
        my $service_id = &_service_lookup($service_lookup, $host_lookup, $service->{'host_name'}, $service->{'description'}, $dbh, $prefix);
        next unless $service_id;
        my @values;
        for my $contact (@{$service->{'contacts'}}) {
            my $contact_id = _contact_lookup($contact_lookup, $contact, $dbh, $prefix);
            push @values, '('.$contact_id.','.$service_id.')';
        }
        $dbh->do($stm.join(',', @values)) if scalar @values > 0;
        $count++;
        _debugc(".") if $count%1000 == 0;
    }

    _debug("done");

    $dbh->commit || confess $dbh->errstr;

    return(scalar @{$hosts} + scalar @{$services});
}

##########################################################
sub _update_logcache_optimize {
    my($self, $c, $peer, $dbh, $prefix, $options) = @_;

    # update sort order / optimize every day
    my @times = @{$dbh->selectcol_arrayref('SELECT value FROM `'.$prefix.'_status` WHERE status_id = 3 LIMIT 1')};
    if(!$options->{'force'} && scalar @times > 0 && $times[0] && $times[0] > time()-86400) {
        _info("no optimize neccessary, last optimize: ".(scalar localtime $times[0]).", use -f to force");
        return(-1);
    }
    my $start = time();

    eval {
        _infos("update logs table order...");
        $dbh->do("ALTER TABLE `".$prefix."_log` ORDER BY time");
        $dbh->do("INSERT INTO `".$prefix."_status` (status_id,name,value) VALUES(3,'last_reorder',UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE value=UNIX_TIMESTAMP()");
        _info("done");
    };
    _warn($@) if $@;

    unless ($c->config->{'logcache_pxc_strict_mode'}) {
        # remove temp files from previously repair attempt if filesystem was full
        if($ENV{'OMD_ROOT'}) {
            my $root = $ENV{'OMD_ROOT'};
            Thruk::Utils::IO::cmd("rm -f $root/var/mysql/thruk_log_cache/*.TMD");
        }
        # repair / optimize tables
        _debug("optimizing / repairing tables");
        for my $table (@Thruk::Backend::Provider::Mysql::tables) {
            _infos($table.'...');
            $dbh->do("REPAIR TABLE `".$prefix."_".$table.'`');
            $dbh->do("OPTIMIZE TABLE `".$prefix."_".$table.'`');
            $dbh->do("ANALYZE TABLE `".$prefix."_".$table.'`');
            $dbh->do("CHECK TABLE `".$prefix."_".$table.'`');
            _info("OK");
        }
    }

    $dbh->commit || confess $dbh->errstr;
    my $duration = time() - $start;
    $dbh->do("INSERT INTO `".$prefix."_status` (status_id,name,value) VALUES(5,'reorder_duration','".$duration."') ON DUPLICATE KEY UPDATE value='".$duration."'");
    $dbh->commit || confess $dbh->errstr;
    return(-1);
}

##########################################################
sub _get_host_lookup {
    my($dbh,$peer,$prefix, $noupdate) = @_;

    my $sth = $dbh->prepare("SELECT host_id, host_name FROM `".$prefix."_host`");
    $sth->execute;
    my $hosts_lookup = {};
    for my $r (@{$sth->fetchall_arrayref()}) { $hosts_lookup->{$r->[1]} = $r->[0]; }
    return $hosts_lookup if $noupdate;

    my($hosts) = $peer->{'class'}->get_hosts(columns => [qw/name/]);
    my $stm = "INSERT INTO `".$prefix."_host` (host_name) VALUES";
    my @values;
    for my $h (@{$hosts}) {
        next if defined $hosts_lookup->{$h->{'name'}};
        push @values, '('.$dbh->quote($h->{'name'}).')';
    }
    if(scalar @values > 0) {
        for my $chunk (@{Thruk::Utils::array_chunk_fixed_size(\@values, 50)}) {
            $dbh->do($stm.join(',', @{$chunk}));
            $sth->execute;
        }
        for my $r (@{$sth->fetchall_arrayref()}) { $hosts_lookup->{$r->[1]} = $r->[0]; }
    }
    return $hosts_lookup;
}


##########################################################
sub _get_service_lookup {
    my($dbh,$peer,$prefix,$hosts_lookup,$noupdate, $auto_increments, $foreign_key_stash) = @_;

    my $sth = $dbh->prepare("SELECT s.service_id, h.host_name, s.service_description FROM `".$prefix."_service` s, `".$prefix."_host` h WHERE s.host_id = h.host_id");
    $sth->execute;
    my $services_lookup = {};
    for my $r (@{$sth->fetchall_arrayref()}) { $services_lookup->{$r->[1]}->{$r->[2]} = $r->[0]; }
    return $services_lookup if $noupdate;

    my($services) = $peer->{'class'}->get_services(columns => [qw/host_name description/]);
    my $stm = "INSERT INTO `".$prefix."_service` (host_id, service_description) VALUES";
    my @values;
    for my $s (@{$services}) {
        next if defined $services_lookup->{$s->{'host_name'}}->{$s->{'description'}};
        my $host_id = &_host_lookup($hosts_lookup, $s->{'host_name'}, $dbh, $prefix, $auto_increments, $foreign_key_stash);
        push @values, '('.$host_id.','.$dbh->quote($s->{'description'}).')';
    }
    if(scalar @values > 0) {
        for my $chunk (@{Thruk::Utils::array_chunk_fixed_size(\@values, 50)}) {
            $dbh->do($stm.join(',', @{$chunk}));
            $sth->execute;
        }
        for my $r (@{$sth->fetchall_arrayref()}) { $services_lookup->{$r->[1]}->{$r->[2]} = $r->[0]; }
    }
    return $services_lookup;
}

##########################################################
sub _get_contact_lookup {
    my($dbh,$peer,$prefix,$noupdate) = @_;

    my $sth = $dbh->prepare("SELECT contact_id, name FROM `".$prefix."_contact`");
    $sth->execute;
    my $contact_lookup = {};
    for my $r (@{$sth->fetchall_arrayref()}) { $contact_lookup->{$r->[1]} = $r->[0]; }
    return $contact_lookup if $noupdate;

    my($contacts) = $peer->{'class'}->get_contacts(columns => [qw/name/]);
    my $stm = "INSERT INTO `".$prefix."_contact` (name) VALUES";
    my @values;
    for my $c (@{$contacts}) {
        next if defined $contact_lookup->{$c->{'name'}};
        push @values, '('.$dbh->quote($c->{'name'}).')';
    }
    if(scalar @values > 0) {
        for my $chunk (@{Thruk::Utils::array_chunk_fixed_size(\@values, 50)}) {
            $dbh->do($stm.join(',', @{$chunk}));
            $sth->execute;
        }
        for my $r (@{$sth->fetchall_arrayref()}) { $contact_lookup->{$r->[1]} = $r->[0]; }
    }
    return $contact_lookup;
}

##########################################################
sub _host_lookup {
    my($host_lookup, $host_name, $dbh, $prefix, $auto_increments, $foreign_key_stash) = @_;
    return unless $host_name;

    my $id = $host_lookup->{$host_name};
    return $id if $id;

    if($auto_increments) {
        $id = $auto_increments->{$prefix.'_host'}->{'AUTO_INCREMENT'}++;
        push @{$foreign_key_stash->{'host'}}, '('.$id.', '.$dbh->quote($host_name).')';
        $host_lookup->{$host_name} = $id;
        return $id;
    }

    $dbh->do("INSERT INTO `".$prefix."_host` (host_name) VALUES(".$dbh->quote($host_name).")");
    $id = $dbh->last_insert_id(undef, undef, undef, undef);
    $host_lookup->{$host_name} = $id;

    return $id;
}

##########################################################
sub _get_log_host_auth {
    my($self,$dbh, $prefix, $contact) = @_;
    my @hosts = @{$dbh->selectall_arrayref("SELECT h.host_name FROM `".$prefix."_host` h, `".$prefix."_contact_host_rel` chr, `".$prefix."_contact` c WHERE h.host_id = chr.host_id AND c.contact_id = chr.contact_id AND c.name = ".$dbh->quote($contact))};
    my $hosts_lookup = {};
    for my $h (@hosts) { $hosts_lookup->{$h->[0]} = 1; }
    return $hosts_lookup;
}

##########################################################
sub _get_log_service_auth {
    my($self,$dbh, $prefix, $contact) = @_;

    # Select all Services where the host is allowed by contact
    my $sql1 = "SELECT h.host_name, s.service_description
               FROM
                 `".$prefix."_service` s,
                 `".$prefix."_host` h,
                 `".$prefix."_contact_host_rel` chr,
                 `".$prefix."_contact` c1,
                 `".$prefix."_contact_service_rel` csr
               WHERE
                 s.host_id = h.host_id
                 AND h.host_id = chr.host_id
                 AND c1.contact_id = chr.contact_id
                 AND s.service_id = csr.service_id
                 AND c1.name = ".$dbh->quote($contact)
               ;
    # Select all Services which are directly allowed by contact
    my $sql2 = "SELECT h.host_name, s.service_description
               FROM
                 `".$prefix."_service` s,
                 `".$prefix."_host` h,
                 `".$prefix."_contact_host_rel` chr,
                 `".$prefix."_contact` c1,
                 `".$prefix."_contact_service_rel` csr
               WHERE
                 s.host_id = h.host_id
                 AND h.host_id = chr.host_id
                 AND c1.contact_id = csr.contact_id
                 AND s.service_id = csr.service_id
                 AND c1.name = ".$dbh->quote($contact)
                ;
    my $services1        = $dbh->selectall_arrayref($sql1);
    my $services2        = $dbh->selectall_arrayref($sql2);
    # Make them unique
    my $services_lookup = {};
    for my $s (@{$services1}) { $services_lookup->{$s->[0]}->{$s->[1]} = 1; }
    for my $s (@{$services2}) { $services_lookup->{$s->[0]}->{$s->[1]} = 1; }
    return $services_lookup;
}

##########################################################
sub _service_lookup {
    my($service_lookup, $host_lookup, $host_name, $service_description, $dbh, $prefix, $host_id, $auto_increments, $foreign_key_stash) = @_;
    return unless $service_description;
    return unless $host_name;

    my $id = $service_lookup->{$host_name}->{$service_description};
    return $id if $id;

    $host_id = &_host_lookup($host_lookup, $host_name, $dbh, $prefix, $auto_increments, $foreign_key_stash) unless $host_id;

    if($auto_increments) {
        $id = $auto_increments->{$prefix.'_service'}->{'AUTO_INCREMENT'}++;
        push @{$foreign_key_stash->{'service'}}, '('.$id.', '.$host_id.','.$dbh->quote($service_description).')';
        $service_lookup->{$host_name}->{$service_description} = $id;
        return $id;
    }

    $dbh->do("INSERT INTO `".$prefix."_service` (host_id, service_description) VALUES(".$host_id.", ".$dbh->quote($service_description).")");
    $id = $dbh->last_insert_id(undef, undef, undef, undef);
    $service_lookup->{$host_name}->{$service_description} = $id;

    return $id;
}

##########################################################
sub _contact_lookup {
    my($contact_lookup, $contact_name, $dbh, $prefix, $auto_increments, $foreign_key_stash) = @_;
    return unless $contact_name;

    my $id = $contact_lookup->{$contact_name};
    return $id if $id;

    if($auto_increments) {
        $id = $auto_increments->{$prefix.'_contact'}->{'AUTO_INCREMENT'}++;
        push @{$foreign_key_stash->{'contact'}}, '('.$id.', '.$dbh->quote($contact_name).')';
        $contact_lookup->{$contact_name} = $id;
        return $id;
    }

    $dbh->do("INSERT INTO `".$prefix."_contact` (name) VALUES(".$dbh->quote($contact_name).")");
    $id = $dbh->last_insert_id(undef, undef, undef, undef);
    $contact_lookup->{$contact_name} = $id;

    return $id;
}

##########################################################
sub _fill_lookup_logs {
    my($self,$prefix,$start,$end) = @_;
    my $lookup = {};
    my($mlogs) = $self->get_logs(
                                filter  => [{ '-and' => [
                                                        { time => { '>=' => $start } },
                                                        { time => { '<=' => $end } },
                                           ]}],
                                collection => $prefix,
                              );
    for my $l (@{$mlogs}) {
        next unless defined $l->{'message'};
        $lookup->{$l->{'message'}} = 1;
    }

    return $lookup;
}

##########################################################
sub _import_peer_logfiles {
    my($self,$c,$mode,$peer,$blocksize,$dbh,$host_lookup,$service_lookup,$prefix,$contact_lookup,$forcestart) = @_;

    # get start / end timestamp
    my($mstart, $mend);
    my $filter = [];
    if($mode eq 'update') {
        $c->stats->profile(begin => "get last mysql timestamp");
        # get last timestamp from Mysql
        ($mstart, $mend) = @{$peer->logcache->get_logs_start_end(collection => $prefix)};
        if(defined $mend) {
            _debug("latest entry in logcache: ".(scalar localtime $mend));
            push @{$filter}, {time => { '>=' => $mend }};
        }
        $c->stats->profile(end => "get last mysql timestamp");
    }

    my $log_count = 0;
    my($start, $end);
    if($forcestart) {
        $start = $forcestart;
    }
    elsif(scalar @{$filter} == 0) {
        my $mend;
        if($mode eq 'import') {
            # it does not make send to import more than we would clean immediatly again
            $mend = time() - Thruk::Utils::expand_duration($c->config->{'logcache_clean_duration'});
        }
        # fetching logs without any filter is a terrible bad idea
        $c->stats->profile(begin => "get livestatus timestamp no filter");
        ($start, $end) = Thruk::Backend::Manager::get_logs_start_end_no_filter($peer->{'class'}, $mend);
        $c->stats->profile(end => "get livestatus timestamp no filter");
    } else {
        $c->stats->profile(begin => "get livestatus timestamp");
        ($start, $end) = @{$peer->{'class'}->get_logs_start_end(filter => $filter, nocache => 1)};
        $c->stats->profile(end => "get livestatus timestamp");
        if(defined $mend && $start < $mend) {
            $start = $mend;
        }
    }
    if(!$start) {
        die("something went wrong, cannot get start from logfiles (".(defined $start ? $start : "undef").")\nIf this is an Icinga2 please have a look at: https://thruk.org/documentation/logfile-cache.html#icinga-2 for a workaround.\n");
    }

    _info("importing from ".(scalar localtime $start));
    _info("until latest entry in logfile: ".(scalar localtime $end)) if $end;
    my $time = $start;
    $end = time() unless $end;

    # add import filter again, even if it should have been filtered in the logs query already, but it seems like not all backends handle them correctly
    my $import_filter = [];
    for my $f (@{Thruk::Utils::list($c->config->{'logcache_import_exclude'})}) {
        push @{$import_filter}, { message => { '!~~' => $f } }
    }
    if($mode eq 'import') {
        $dbh->do('SET foreign_key_checks = 0');
        $dbh->do('SET unique_checks = 0');
        $dbh->do('ALTER TABLE `'.$prefix.'_log` DISABLE KEYS');
    }
    my $compact_start_data = Thruk::Backend::Manager::get_expanded_start_date($c, $c->config->{'logcache_compact_duration'});
    my $alertstore = {};
    my $last_day = "";

    my @columns = qw/class time type state host_name service_description message state_type contact_name/;
    my $reordered = 0;
    while($time <= $end) {
        my $stime = scalar localtime $time;
        $c->stats->profile(begin => $stime);
        my $duplicate_lookup = {};
        _infos(scalar localtime $time);

        my $today = POSIX::strftime("%Y-%m-%d", localtime($time));
        if($last_day ne $today) {
            $alertstore = {};
            $last_day = $today;
        }

        my $import_compacted = 0;
        if($mode eq 'import') {
            if(($time + $blocksize - 1) < $compact_start_data) {
                $import_compacted = 1;
            }
        }

        my $logs = [];
        my $file = $peer->{'class'}->{'fetch_command'} ? 1 : undef;
        #&timing_breakpoint('_get_logs');
        eval {
            # get logs from peer
            ($logs) = $peer->{'class'}->get_logs(nocache => 1,
                                                 filter  => [{ '-and' => [
                                                                    { time => { '>=' => $time } },
                                                                    { time => { '<=' => ($time + $blocksize - 1) } },
                                                            ]}, @{$import_filter} ],
                                                 columns => \@columns,
                                                 file => $file,
                                                );
            #&timing_breakpoint('_get_logs done');
            if($mode eq 'update') {
                # get already stored logs to filter duplicates
                $duplicate_lookup = $self->_fill_lookup_logs($prefix,$time,($time+$blocksize));
                #&timing_breakpoint('_fill_lookup_logs_logs done');
            }
            _infoc(":");
        };
        if($@) {
            my $err = $@;
            chomp($err);
            if($mode eq 'import') {
                die($err);
            } else {
                print($err);
            }
        }

        $time = $time + $blocksize;

        if($file) {
            $file = $logs;
            $log_count += $self->_import_logcache_from_file($mode,$dbh,[$file],$host_lookup,$service_lookup,$prefix,$contact_lookup,$c, $import_compacted, $alertstore);
        } else {
            $log_count += $self->_insert_logs($dbh,$mode,$logs,$host_lookup,$service_lookup,$duplicate_lookup,$prefix,$contact_lookup,$c, undef, $import_compacted, $alertstore);
            $reordered = 1;
        }

        $c->stats->profile(end => $stime);
    }

    if($mode eq 'import') {
        _debugs("creating index...");
        #&timing_breakpoint('_import_peer_logfiles enable index');
        $dbh->do('SET foreign_key_checks = 1');
        $dbh->do('SET unique_checks = 1');
        $dbh->do('ALTER TABLE `'.$prefix.'_log` ENABLE KEYS');
        if($reordered) {
            $dbh->do("INSERT INTO `".$prefix."_status` (status_id,name,value) VALUES(3,'last_reorder',UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE value=UNIX_TIMESTAMP()");
        }
        _debug("done");
        #&timing_breakpoint('_import_peer_logfiles enable index done');
    }

    # update index statistics
    if($log_count > 0) {
        _check_index($c, $dbh, $prefix);
    }

    return $log_count;
}

##########################################################
sub _import_logcache_from_file {
    my($self,$mode,$dbh,$files,$host_lookup,$service_lookup,$prefix,$contact_lookup, $c, $import_compacted, $alertstore) = @_;
    my $log_count = 0;

    require Monitoring::Availability::Logs;

    # get current auto increment values
    my $auto_increments = _get_autoincrements($dbh, $prefix);
    my $foreign_key_stash = {};

    # add import filter
    my $import_filter;
    if(scalar @{Thruk::Utils::list($c->config->{'logcache_import_exclude'})} > 0) {
        my $f = join('|', @{Thruk::Utils::list($c->config->{'logcache_import_exclude'})});
        ## no critic
        $import_filter = qr/($f)/i;
        ## use critic
    }

    my $stm = "INSERT INTO `".$prefix."_log` (time,class,type,state,state_type,contact_id,host_id,service_id,message) VALUES";

    for my $f (@{$files}) {
        _infos($f);
        my $duplicate_lookup  = {};
        my $last_duplicate_ts = 0;
        my @values;

        open(my $fh, '<', $f) or die("cannot open ".$f.": ".$!);
        while(my $line = <$fh>) {
            chomp($line);
            &Thruk::Utils::decode_any($line);
            my $original_line = $line;
            my $l = &Monitoring::Availability::Logs::parse_line($line); # do not use xs here, unchanged $line breaks the _set_class later
            next unless($l && $l->{'time'});
            next if $import_filter && $original_line =~ $import_filter;

            if($mode eq 'update') {
                if($last_duplicate_ts < $l->{'time'}) {
                    $self->_safe_insert($dbh, $stm, \@values);
                    $self->_safe_insert_stash($dbh, $prefix, $foreign_key_stash);
                    @values = ();
                    $duplicate_lookup = $self->_fill_lookup_logs($prefix,$l->{'time'},$l->{'time'}+86400);
                    $last_duplicate_ts = $l->{'time'}+86400;
                }
                next if defined $duplicate_lookup->{$original_line};
            }

            $log_count++;
            $l->{'message'} = $original_line;
            my($host, $svc, $contact) = _fix_import_log($l, $host_lookup, $service_lookup, $contact_lookup, $dbh, $prefix, $auto_increments, $foreign_key_stash);

            # commit every 1000th to avoid to large blocks
            if($log_count%1000 == 0) {
                $self->_safe_insert($dbh, $stm, \@values);
                $self->_safe_insert_stash($dbh, $prefix, $foreign_key_stash);
                @values = ();
                _infoc('.');
            }

            if($import_compacted && _is_compactable($l, $alertstore)) {
                # skip insert
                next;
            }

            push @values, sprintf('(%s,%s,%s,%s,%s,%s,%s,%s,%s)',
                    $l->{'time'},
                    $l->{'class'},
                    $dbh->quote($l->{'type'}),
                    $dbh->quote($l->{'state'}),
                    $dbh->quote($l->{'state_type'}),
                    $dbh->quote($contact),
                    $dbh->quote($host),
                    $dbh->quote($svc),
                    $dbh->quote($l->{'message'}),
            );
        }
        $self->_safe_insert($dbh, $stm, \@values);
        $self->_safe_insert_stash($dbh, $prefix, $foreign_key_stash);
        CORE::close($fh);
        _debug("\n");
    }

    unless ($c->config->{'logcache_pxc_strict_mode'}) {
        _release_write_locks($dbh);
        _info("it is recommended to run logcacheoptimize after importing logfiles.");
    }

    return $log_count;
}

##########################################################
sub _insert_logs {
    my($self,$dbh,$mode,$logs,$host_lookup,$service_lookup,$duplicate_lookup,$prefix,$contact_lookup,$c,$use_extended_inserts, $import_compacted, $alertstore) = @_;
    my $log_count = 0;
    my $compacted = 0;

    my $dots_each = 1000;
    if($mode eq 'update') {
        $mode = MODE_UPDATE;
    } elsif($mode eq 'import') {
        $mode = MODE_IMPORT;
        $dots_each = 10000;
    }

    if(!defined $use_extended_inserts) {
        $use_extended_inserts = $mode == MODE_IMPORT ? 0 : 1;
    }

    # check pid / lock
    my @pids = @{$dbh->selectcol_arrayref('SELECT value FROM `'.$prefix.'_status` WHERE status_id = 2 LIMIT 1')};
    if(scalar @pids == 1 && $pids[0] && $pids[0] != $$) {
        _warn("logcache update already running with pid ".$pids[0]);
        return $log_count;
    }

    # get current auto increment values
    my $auto_increments = _get_autoincrements($dbh, $prefix);
    my $foreign_key_stash = {};

    # add import filter
    my $import_filter;
    if(scalar @{Thruk::Utils::list($c->config->{'logcache_import_exclude'})} > 0) {
        my $f = join('|', @{Thruk::Utils::list($c->config->{'logcache_import_exclude'})});
        ## no critic
        $import_filter = qr/($f)/i;
        ## use critic
    }

    my $stm = "INSERT INTO `".$prefix."_log` (time,class,type,state,state_type,contact_id,host_id,service_id,message) VALUES";

    my @values;
    my($fh, $datafilename);
    if(!$use_extended_inserts) {
        ($fh, $datafilename) = tempfile();
        $fh->binmode (":encoding(utf-8)");
    }
    #&timing_breakpoint('_insert_logs');
    for my $l (@{$logs}) {
        next unless $l->{'message'};
        if($mode == MODE_UPDATE) {
            next if defined $duplicate_lookup->{$l->{'message'}};
        }

        next if $import_filter && $l->{'message'} =~ $import_filter;

        $log_count++;
        _infoc('.') if $log_count % $dots_each == 0;

        my($host, $svc, $contact) = _fix_import_log($l, $host_lookup, $service_lookup, $contact_lookup, $dbh, $prefix, $auto_increments, $foreign_key_stash);

        if($import_compacted && _is_compactable($l, $alertstore)) {
            # skip insert
            $compacted++;
            next;
        }

        if($use_extended_inserts) {
            push @values, sprintf('(%s,%s,%s,%s,%s,%s,%s,%s,%s)',
                    $l->{'time'},
                    $l->{'class'},
                    $dbh->quote($l->{'type'}),
                    $dbh->quote($l->{'state'}),
                    $dbh->quote($l->{'state_type'}),
                    $dbh->quote($contact),
                    $dbh->quote($host),
                    $dbh->quote($svc),
                    $dbh->quote($l->{'message'}),
            );
        } else {
            printf($fh "%s\0%s\0%s\0%s\0%s\0%s\0%s\0%s\0%s\n",
                    $l->{'time'},
                    $l->{'class'},
                    $l->{'type'}       // '\N',
                    $l->{'state'}      // '\N',
                    $l->{'state_type'} // '\N',
                    $contact           // '\N',
                    $host              // '\N',
                    $svc               // '\N',
                    $l->{'message'},
            );
        }

        # commit every 1000th to avoid to large blocks
        if($use_extended_inserts && $log_count%1000 == 0) {
            #&timing_breakpoint('_insert_logs logs calculated');
            $self->_safe_insert($dbh, $stm, \@values);
            @values = ();
            #&timing_breakpoint('_insert_logs logs inserted');
            $self->_safe_insert_stash($dbh, $prefix, $foreign_key_stash);
        }
    }
    if($use_extended_inserts) {
        $self->_safe_insert($dbh, $stm, \@values);
    } else {
        #&timing_breakpoint('_insert_logs load data local');
        CORE::close($fh);
        my $stm = sprintf("LOAD DATA LOCAL INFILE '%s' INTO TABLE `%s_log` FIELDS TERMINATED BY '\0' ENCLOSED BY '' (time,class,type,state,state_type,contact_id,host_id,service_id,message)", $datafilename, $prefix);
        eval {
            $dbh->do($stm);
        };
        my $err = $@;
        unlink($datafilename);
        if($err) {
            _error("ERROR DETAIL: ".$err);
            _error("ERROR SQL: ".$stm);
            # retry with extended inserts
            return(_insert_logs($self,$dbh,$mode,$logs,$host_lookup,$service_lookup,$duplicate_lookup,$prefix,$contact_lookup,$c,1));
        }
        $dbh->commit || confess $dbh->errstr;
        #&timing_breakpoint('_insert_logs load data local done');
    }

    $self->_safe_insert_stash($dbh, $prefix, $foreign_key_stash);
    # release locks, unless in import mode. Import releases lock later
    if($mode != MODE_IMPORT) {
        _release_write_locks($dbh) unless $c->config->{'logcache_pxc_strict_mode'};
    }

    if($compacted > 0) {
        _info('. '.($log_count-$compacted) . " entries added and ".$compacted." compacted rows skipped");
    } else {
        _info('. '.$log_count . " entries added");
    }
    return $log_count;
}

##########################################################
sub _create_tables {
    my($dbh, $prefix) = @_;
    for my $stm (@{_get_create_statements($prefix)}) {
        $dbh->do($stm);
    }
    $dbh->commit || confess $dbh->errstr;
    return;
}

##########################################################
sub _drop_tables {
    my($dbh, $prefix) = @_;
    for my $table (@Thruk::Backend::Provider::Mysql::tables) {
        $dbh->do("DROP TABLE IF EXISTS `".$prefix."_".$table.'`');
    }
    $dbh->do("DROP TABLE IF EXISTS `".$prefix."_plugin_output`");
    $dbh->commit || confess $dbh->errstr;
    return;
}

##########################################################
sub _safe_insert {
    my($self, $dbh, $stm, $values) = @_;
    return if scalar @{$values} == 0;
    eval {
        $dbh->do($stm.join(',', @{$values}));
    };
    if($@) {
        _error("ERROR INSERT: ".$@);

        # insert failed for some reason, try them one by one to see which one breaks
        for my $v (@{$values}) {
            eval {
                $dbh->do($stm.$v);
            };
            if ($@) {
                _error("ERROR DETAIL: ".$@);
                _error("ERROR SQL: ".$stm.$v);
            }
        }
    }
    $dbh->commit || confess $dbh->errstr;
    return;
}

##########################################################
sub _safe_insert_stash {
    my($self, $dbh, $prefix, $foreign_key_stash) = @_;

    if($foreign_key_stash->{'host'}) {
        $self->_safe_insert($dbh, "INSERT INTO `".$prefix."_host` (host_id, host_name) VALUES", \@{$foreign_key_stash->{'host'}});
        delete $foreign_key_stash->{'host'};
    }

    if($foreign_key_stash->{'service'}) {
        $self->_safe_insert($dbh, "INSERT INTO `".$prefix."_service` (service_id, host_id, service_description) VALUES", \@{$foreign_key_stash->{'service'}});
        delete $foreign_key_stash->{'service'};
    }

    if($foreign_key_stash->{'contact'}) {
        $self->_safe_insert($dbh, "INSERT INTO `".$prefix."_contact` (contact_id, name) VALUES", \@{$foreign_key_stash->{'contact'}});
        delete $foreign_key_stash->{'contact'};
    }

    return;
}

##########################################################
sub _get_autoincrements {
    my($dbh, $prefix) = @_;
    my $auto_increments = $dbh->selectall_hashref(
        'SELECT
            TABLE_NAME,
            AUTO_INCREMENT
         FROM
            INFORMATION_SCHEMA.TABLES
         WHERE
            TABLE_SCHEMA = Database()
            AND TABLE_NAME LIKE "%'.$prefix.'_%"
        ', 'TABLE_NAME');
    return($auto_increments);
}

##########################################################
sub _release_write_locks {
    my($dbh) = @_;
    $dbh->do('UNLOCK TABLES');
    return;
}

##########################################################
sub _fix_import_log {
    my($l, $host_lookup, $service_lookup, $contact_lookup, $dbh, $prefix, $auto_increments, $foreign_key_stash) = @_;
    my($host, $svc, $contact);

    if(exists $l->{'hard'}) {
        if($l->{'hard'}) {
            $l->{'state_type'} = 'HARD';
        } else {
            $l->{'state_type'} = 'SOFT';
        }
    }
    if(!$l->{'state_type'} || ($l->{'state_type'} ne 'HARD' && $l->{'state_type'} ne 'SOFT')) {
        $l->{'state_type'} = undef;
    }

    $l->{'state'} = undef unless(defined $l->{'state'} && $l->{'state'} ne '');
    &_set_class($l);
    &_set_type($l);

    if($l->{'class'} == 5) { &_set_external_command($l); }

    if($l->{'service_description'}) {
        $host = $host_lookup->{$l->{'host_name'}} || &_host_lookup($host_lookup, $l->{'host_name'}, $dbh, $prefix, $auto_increments, $foreign_key_stash);
        $svc  = $service_lookup->{$l->{'host_name'}}->{$l->{'service_description'}} || &_service_lookup($service_lookup, $host_lookup, $l->{'host_name'}, $l->{'service_description'}, $dbh, $prefix, $host, $auto_increments, $foreign_key_stash);
    }
    elsif($l->{'host_name'}) {
        $host = $host_lookup->{$l->{'host_name'}} || &_host_lookup($host_lookup, $l->{'host_name'}, $dbh, $prefix, $auto_increments, $foreign_key_stash);
    }
    if($l->{'contact_name'}) {
        $contact = $contact_lookup->{$l->{'contact_name'}} || &_contact_lookup($contact_lookup, $l->{'contact_name'}, $dbh, $prefix, $auto_increments, $foreign_key_stash);
    }
    return($host, $svc, $contact);
}

##########################################################
sub _set_class {
    my($l) = @_;
    return if $l->{'class'};
    my $type = $l->{'type'};
    $l->{'class'} = $Thruk::Backend::Provider::Mysql::db_types->{$type} if defined $type;
    return if $l->{'class'};

    if(!defined $l->{'message'}) {
        $l->{'class'}   = 0; # LOGCLASS_INFO
        $l->{'message'} = $type;
        $l->{'type'}    = '';
        return;
    }

    if(   $l->{'message'} =~ m/starting\.\.\./mxo
       or $l->{'message'} =~ m/shutting\ down\.\.\./mxo
       or $l->{'message'} =~ m/Bailing\ out/mxo
       or $l->{'message'} =~ m/active\ mode\.\.\./mxo
       or $l->{'message'} =~ m/standby\ mode\.\.\./mxo
    ) {
        $l->{'class'} = 2; # LOGCLASS_PROGRAM
        $l->{'message'} = $l->{'type'}.': '.$l->{'message'} if($l->{'type'} && $l->{'message'} !~ m/^\[\d+\]/mx);
        $l->{'type'}    = '';
        return;
    }

    $l->{'type'}    = '';
    $l->{'class'}   = 0; # LOGCLASS_INFO
    return;
}

##########################################################
sub _set_type {
    my($l) = @_;

    if($l->{'message'} =~ m/^\[\d+\]\s+TIMEPERIOD\ TRANSITION/mxo) {
        $l->{'type'}  = 'TIMEPERIOD TRANSITION';
        $l->{'class'} = 6; # LOGCLASS_STATE
        return;
    }

    if(defined $l->{'type'}) {
        if(!defined $Thruk::Backend::Provider::Mysql::db_types->{$l->{'type'}}) {
            # Set type to NULL to prevent SQL insert errors if type is not a special type.
            undef $l->{'type'};
        }
        return;
    }

    return;
}

##########################################################
sub _check_index {
    my($c, $dbh, $prefix) = @_;
    $c->stats->profile(begin => "update index statistics");
    _debugs("running check/analyse...");

    my $data = $dbh->selectall_hashref("SHOW INDEXES FROM `".$prefix."_log`", "Key_name");
    if($data && $data->{'host_id'}) {
        my($hostcount) = @{$dbh->selectcol_arrayref("SELECT COUNT(*) as total FROM `".$prefix."_host`")};
        if($data->{'host_id'}->{'Cardinality'} < $hostcount * 5) {
            $c->stats->profile(end => "update index statistics");
            _debug("not required");
            return;
        }
    }

    for my $table (@Thruk::Backend::Provider::Mysql::tables) {
        $dbh->do("ANALYZE TABLE `".$prefix."_".$table.'`');
        $dbh->do("CHECK TABLE `".$prefix."_".$table.'`');
    }
    _debug("done");
    $c->stats->profile(end => "update index statistics");
    return;
}

##########################################################
sub _set_external_command {
    my($l) = @_;
    # add hosts/services to external commands
    my $msg = $l->{'message'};
    $msg =~ s/^\[\d+\]\ EXTERNAL\ COMMAND:\ //gmxo;
    $msg =~ s/^(.*?);//gmxo;
    my $cmd;
    if($1) {
        $cmd = $1;
    }
    return unless $cmd;
    if($cmd =~ m/_HOST(_|$)/mx) {
        if($msg =~ m/^([^;]+);(;|$)/gmx) {
            $l->{'host_name'} = $1;
        }
    }
    elsif($cmd =~ m/_SVC(_|$)/mx) {
        if($msg =~ m/^([^;]+);([^;]+)(;|$)/gmx) {
            $l->{'host_name'} = $1;
            $l->{'service_description'} = $2;
        }
    }
    elsif($cmd =~ m/_CONTACT(_|$)/mx) {
        if($msg =~ m/^([^;]+);(;|$)/gmx) {
            $l->{'contact_name'} = $1;
        }
    }
    return;
}

##########################################################
sub _sql_debug {
    my($sql, $dbh) = @_;

    my $sth = $dbh->prepare($sql);
    $sth->execute;
    my $data = $sth->fetchall_arrayref({});

    return(Thruk::Utils::text_table(
        keys => $sth->{'NAME'},
        data => $data,
    ));
}

##########################################################
sub _get_create_statements {
    my($prefix) = @_;
    my @statements = (
    # contact
        "DROP TABLE IF EXISTS `".$prefix."_contact`",
        "CREATE TABLE `".$prefix."_contact` (
          contact_id mediumint(9) unsigned NOT NULL AUTO_INCREMENT,
          name varchar(150) NOT NULL,
          PRIMARY KEY (contact_id)
        ) DEFAULT CHARSET=utf8 COLLATE=utf8_bin",

    # contact_host_rel
        "DROP TABLE IF EXISTS `".$prefix."_contact_host_rel`",
        "CREATE TABLE `".$prefix."_contact_host_rel` (
          contact_id mediumint(9) unsigned NOT NULL,
          host_id mediumint(9) unsigned NOT NULL,
          PRIMARY KEY (contact_id,host_id)
        ) DEFAULT CHARSET=utf8 COLLATE=utf8_bin",

    # contact_service_rel
        "DROP TABLE IF EXISTS `".$prefix."_contact_service_rel`",
        "CREATE TABLE `".$prefix."_contact_service_rel` (
          contact_id mediumint(9) unsigned NOT NULL,
          service_id mediumint(9) unsigned NOT NULL,
          PRIMARY KEY (contact_id,service_id)
        ) DEFAULT CHARSET=utf8 COLLATE=utf8_bin",

    # host
        "DROP TABLE IF EXISTS `".$prefix."_host`",
        "CREATE TABLE `".$prefix."_host` (
          host_id mediumint(9) unsigned NOT NULL AUTO_INCREMENT,
          host_name varchar(150) NOT NULL,
          PRIMARY KEY (host_id)
        ) DEFAULT CHARSET=utf8 COLLATE=utf8_bin",

    # log
        "DROP TABLE IF EXISTS `".$prefix."_log`",
        "CREATE TABLE IF NOT EXISTS `".$prefix."_log` (
          log_id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
          time int(11) unsigned NOT NULL,
          class tinyint(4) unsigned NOT NULL,
          type enum('CURRENT SERVICE STATE','CURRENT HOST STATE','SERVICE NOTIFICATION','HOST NOTIFICATION','SERVICE ALERT','HOST ALERT','SERVICE EVENT HANDLER','HOST EVENT HANDLER','EXTERNAL COMMAND','PASSIVE SERVICE CHECK','PASSIVE HOST CHECK','SERVICE FLAPPING ALERT','HOST FLAPPING ALERT','SERVICE DOWNTIME ALERT','HOST DOWNTIME ALERT','LOG ROTATION','INITIAL HOST STATE','INITIAL SERVICE STATE','TIMEPERIOD TRANSITION') DEFAULT NULL,
          state tinyint(4) unsigned DEFAULT NULL,
          state_type enum('HARD','SOFT') DEFAULT NULL,
          contact_id mediumint(9) unsigned DEFAULT NULL,
          host_id mediumint(9) unsigned DEFAULT NULL,
          service_id mediumint(9) unsigned DEFAULT NULL,
          message mediumtext NOT NULL,
          PRIMARY KEY (log_id),
          KEY time (time),
          KEY host_id (host_id)
        ) DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci PACK_KEYS=1",    # using utf8_bin here would break case-insensitive rlike queries

    # service
        "DROP TABLE IF EXISTS `".$prefix."_service`",
        "CREATE TABLE `".$prefix."_service` (
          service_id mediumint(9) unsigned NOT NULL AUTO_INCREMENT,
          host_id mediumint(9) unsigned NOT NULL,
          service_description varchar(150) NOT NULL,
          PRIMARY KEY (service_id),
          KEY host_id (host_id)
        ) DEFAULT CHARSET=utf8 COLLATE=utf8_bin",

    # status
        "DROP TABLE IF EXISTS `".$prefix."_status`",
        "CREATE TABLE `".$prefix."_status` (
          status_id smallint(6) unsigned NOT NULL AUTO_INCREMENT,
          name varchar(150) NOT NULL,
          value varchar(150) DEFAULT NULL,
          PRIMARY KEY (status_id)
        ) DEFAULT CHARSET=utf8 COLLATE=utf8_bin",

        "INSERT INTO `".$prefix."_status` (status_id, name, value) VALUES(1, 'last_update', '')",
        "INSERT INTO `".$prefix."_status` (status_id, name, value) VALUES(2, 'update_pid', '')",
        "INSERT INTO `".$prefix."_status` (status_id, name, value) VALUES(3, 'last_reorder', '')",
        "INSERT INTO `".$prefix."_status` (status_id, name, value) VALUES(4, 'cache_version', '".$Thruk::Backend::Provider::Mysql::cache_version."')",
        "INSERT INTO `".$prefix."_status` (status_id, name, value) VALUES(5, 'reorder_duration', '')",
        "INSERT INTO `".$prefix."_status` (status_id, name, value) VALUES(6, 'update_duration', '')",
        "INSERT INTO `".$prefix."_status` (status_id, name, value) VALUES(7, 'last_compact', '')",
        "INSERT INTO `".$prefix."_status` (status_id, name, value) VALUES(8, 'compact_duration', '')",
        "INSERT INTO `".$prefix."_status` (status_id, name, value) VALUES(9, 'compact_till', '')",
    );
    return \@statements;
}

##########################################################

1;
