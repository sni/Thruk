package Thruk::Backend::Provider::Mysql;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Digest::MD5 qw/md5_hex/;
use utf8;
use DBI;
use File::Temp qw/tempfile/;
use Thruk::Utils;
use Encode qw/encode_utf8/;
use Monitoring::Availability::Logs;
use parent 'Thruk::Backend::Provider::Base';

=head1 NAME

Thruk::Backend::Provider::Mysql - connection provider for Mysql connections

=head1 DESCRIPTION

connection provider for Mysql connections

=head1 METHODS

=cut

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

$Thruk::Backend::Provider::Mysql::cache_version = 3;

##########################################################

=head2 new

create new manager

=cut
sub new {
    my( $class, $peer_config, $config ) = @_;

    die('need at least one peer. Minimal options are <options>peer = mysql://user:password@host:port/dbname</options>'."\ngot: ".Dumper($peer_config)) unless defined $peer_config->{'peer'};

    $peer_config->{'name'} = 'mysql' unless defined $peer_config->{'name'};
    if(!defined $peer_config->{'peer_key'}) {
        my $key = md5_hex($peer_config->{'name'}.$peer_config->{'peer'});
        $peer_config->{'peer_key'} = $key;
    }
    my($dbhost, $dbport, $dbuser, $dbpass, $dbname, $dbsock);
    if($peer_config->{'peer'} =~ m/^mysql:\/\/(.*?)(|:.*?)@([^:]+)(|:.*?)\/([^\/]*?)$/mx) {
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
        'config'      => $config,
        'peer_config' => $peer_config,
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
        my $dsn = "DBI:mysql:database=".$self->{'dbname'}.";host=".$self->{'dbhost'};
        $dsn .= ";port=".$self->{'dbport'} if $self->{'dbport'};
        $dsn .= ";mysql_socket=".$self->{'dbsock'} if $self->{'dbsock'};
        $self->{'mysql'} = DBI->connect($dsn, $self->{'dbuser'}, $self->{'dbpass'}, {RaiseError => 1, AutoCommit => 0, mysql_enable_utf8 => 1});
        $self->{'mysql'}->do("SET NAMES utf8 COLLATE utf8_bin");
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
    return;
}

##########################################################

=head2 get_processinfo

=cut
sub get_processinfo {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_can_submit_commands

=cut
sub get_can_submit_commands {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_contactgroups_by_contact

=cut
sub get_contactgroups_by_contact {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_hosts

=cut
sub get_hosts {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_hosts_by_servicequery

=cut
sub get_hosts_by_servicequery {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_host_names

=cut
sub get_host_names{
    confess("not implemented");
    return;
}

##########################################################

=head2 get_hostgroups

=cut
sub get_hostgroups {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_hostgroup_names

=cut
sub get_hostgroup_names {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_services

=cut
sub get_services {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_service_names

=cut
sub get_service_names {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_servicegroups

=cut
sub get_servicegroups {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_servicegroup_names

=cut
sub get_servicegroup_names {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_comments

=cut
sub get_comments {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_downtimes

=cut
sub get_downtimes {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_contactgroups

=cut
sub get_contactgroups {
    confess("not implemented");
    return;
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
    my($where,$contact,$system,$strict) = $self->_get_filter($options{'filter'});

    my $prefix = $options{'collection'};
    $prefix    =~ s/^logs_//gmx;

    my $dbh = $self->_dbh;
    my $sql = '
        SELECT
            l.time as time,
            l.class as class,
            l.type as type,
            l.state as state,
            l.state_type as state_type,
            IFNULL(h.host_name, "") as host_name,
            IFNULL(s.service_description, "") as service_description,
            p2.output as plugin_output,
            c.name as contact_name,
            CONCAT("[", CAST(l.time AS CHAR CHARACTER SET utf8 ) ,"] ",
                   IF(l.type IS NULL, "", IF(l.type != "", CONCAT(l.type, ": "), "")),
                   IF(l.contact_id IS NULL, "", CONCAT(c.name, ";")),
                   IF(h.host_name IS NULL, "", CONCAT(h.host_name, ";")),
                   IF(s.service_description IS NULL, "", CONCAT(s.service_description, ";")),
                   p1.output,
                   p2.output
                ) as message,
            "'.$prefix.'" as peer_key
        FROM
            `'.$prefix.'_log` l
            LEFT JOIN `'.$prefix.'_host` h ON l.host_id = h.host_id
            LEFT JOIN `'.$prefix.'_service` s ON l.service_id = s.service_id
            LEFT JOIN `'.$prefix.'_plugin_output` p1 ON l.message = p1.output_id
            LEFT JOIN `'.$prefix.'_plugin_output` p2 ON l.plugin_output = p2.output_id
            LEFT JOIN `'.$prefix.'_contact` c ON l.contact_id = c.contact_id
        '.$where.'
        '.$orderby.'
    ';
    confess($sql) if $sql =~ m/(ARRAY|HASH)/mx;

    # logfiles into tmp file
    my($fh, $filename);
    if($options{'file'}) {
        my($fh, $filename) = tempfile(DIR => ($c->config->{'tmp_path'} || '/tmp'));
        open($fh, '>', $filename) or die('open '.$filename.' failed: '.$!);
    }

    # querys with authorization
    my $data;
    if($contact) {
        my $sth = $dbh->prepare($sql);
        $sth->execute;

        my $hosts_lookup    = $self->_get_log_host_auth($dbh, $prefix, $contact);
        my $services_lookup = $self->_get_log_service_auth($dbh, $prefix, $contact);

        while(my $r = $sth->fetchrow_hashref()) {
            if($r->{'service_description'}) {
                if($strict) {
                    next if(!defined $services_lookup->{$r->{'host_name'}}->{$r->{'service_description'}});
                } else {
                    next if(!defined $hosts_lookup->{$r->{'host_name'}} and !defined $services_lookup->{$r->{'host_name'}}->{$r->{'service_description'}});
                }
            }
            elsif($r->{'host_name'}) {
                next if !defined $hosts_lookup->{$r->{'host_name'}};
            }
            else {
                next if !$system;
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
                print $fh encode_utf8($r->[9]),"\n";
            }
        } else {
            $data = $dbh->selectall_arrayref($sql, { Slice => {} });
        }
    }
    if($fh) {
        Thruk::Utils::IO::close($fh, $filename);
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
    return;
}

##########################################################

=head2 get_timeperiod_names

=cut
sub get_timeperiod_names {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_commands

=cut
sub get_commands {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_contacts

=cut
sub get_contacts {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_contact_names

=cut
sub get_contact_names {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_host_stats

=cut
sub get_host_stats {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_service_stats

=cut
sub get_service_stats {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_performance_stats

=cut
sub get_performance_stats {
    confess("not implemented");
    return;
}

##########################################################

=head2 get_extra_perf_stats

=cut
sub get_extra_perf_stats {
    confess("not implemented");
    return;
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
    my $filter = $self->_get_subfilter($inp);
    if($filter and ref $filter) {
        $filter = '('.join(' AND ', @{$filter}).')';
    }
    $filter = " WHERE ".$filter if $filter;

    # message filter have to go into a having clause
    my($contact,$system,$strict);
    if($filter and $filter =~ m/message\ (RLIKE|=|LIKE|!=)\ /mx) {
        if($filter =~ s/^\ WHERE\ \((time\ >=\ \d+\ AND\ time\ <=\ \d+)//mx) {
            my $timef = $1;
            my $having = $filter;
            $filter = 'WHERE ('.$timef.')';
            # time filter are the only filter
            if($having eq ')') {
                $having = '';
            } else {
                $having =~ s/^\ AND\ //mx;
                $having =~ s/\)$//mx;
                $filter = $filter.' HAVING ('.$having.')';
            }
        }
    }

    # authentication filter hack
    # hosts, services and system_information
    # ((current_service_contacts IN ('test_contact') AND service_description != '') OR current_host_contacts IN ('test_contact') OR (service_description = '' AND host_name = ''))
    if($filter =~ s/\(\(current_service_contacts\ IN\ \('(.*?)'\)\ AND\ service_description\ !=\ ''\)\ OR\ current_host_contacts\ IN\ \('(.*?)'\)\ OR\ \(service_description\ =\ ''\ AND\ host_name\ =\ ''\)\)//mx) {
        $contact = $1;
        $system  = 1;
    }
    # hosts, services and system_information and strict host auth on
    if($filter =~ s/\(\(current_service_contacts\ IN\ \('(.*?)'\)\ AND\ service_description\ !=\ ''\)\ OR\ \(current_host_contacts\ IN\ \('(.*?)'\)\ AND\ service_description\ =\ ''\)\ OR\ \(service_description\ =\ ''\ AND\ host_name\ =\ ''\)\)//mx) {
        $contact = $1;
        $system  = 1;
        $strict  = 1;
    }
    # hosts and services and strict host auth on
    if($filter =~ s/\(\(current_service_contacts\ IN\ \('(.*?)'\)\ AND\ service_description\ !=\ ''\)\ OR\ \(current_host_contacts\ IN\ \('.*?'\)\ AND\ service_description\ =\ ''\)\)//mx) {
        $contact = $1;
        $strict  = 1;
    }
    # hosts and services
    # ((current_service_contacts IN ('test_contact') AND service_description != '') OR current_host_contacts IN ('test_contact'))
    if($filter =~ s/\(\(current_service_contacts\ IN\ \('(.*?)'\)\ AND\ service_description\ !=\ ''\)\ OR\ current_host_contacts\ IN\ \('.*?'\)\)//mx) {
        $contact = $1;
    }

    $filter =~ s/\ AND\ \)/)/gmx;
    $filter =~ s/\(\ AND\ \(/((/gmx;
    $filter = '' if $filter eq ' WHERE ';

    return($filter, $contact, $system, $strict);
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
                push @{$filter}, $self->_get_subfilter({$key => $val});
                $x=$x+2;
                next;
            }
            # [ '-or', [ 'key' => 'value' ] ]
            if(exists $inp->[$x+1] and ref $inp->[$x] eq '' and ref $inp->[$x+1] eq 'ARRAY') {
                my $key = $inp->[$x];
                my $val = $inp->[$x+1];
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
            if($k eq '~')                           { return 'RLIKE '._quote($v); }
            if($k eq '~~')                          { return 'RLIKE '._quote($v); }
            if($k eq '!~~')                         { return 'NOT RLIKE '._quote($v); }
            if($k eq '>='  and ref $v eq 'ARRAY')   { confess("whuus") unless defined $f; return '= '.join(' OR '.$f.' = ', @{_quote($v)}); }
            if($k eq '!>=' and ref $v eq 'ARRAY')   { confess("whuus") unless defined $f; return '!= '.join(' OR '.$f.' != ', @{_quote($v)}); }
            if($k eq '!>=')                         { return '!= '._quote($v); }
            if($k eq '>=' and $v !~ m/^[\d\.]+$/mx) { return 'IN ('._quote($v).')'; }
            if($k eq '>=')                          { return '>= '._quote($v); }
            if($k eq '<=')                          { return '<= '._quote($v); }
            if($k eq '-or') {
                my $list = $self->_get_subfilter($v);
                if(ref $list) {
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
    if($_[0] =~ m/^[\d\.]+$/mx) {
        return $_[0];
    }
    $_[0] =~ s/'/\'/gmx;
    return("'".$_[0]."'");
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
    my $dbh  = $self->_dbh();
    my @data = @{$dbh->selectall_arrayref('SELECT MIN(time) as mi, MAX(time) as ma FROM `'.$prefix.'_log` LIMIT 1', { Slice => {} })};
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
    my($self, $c) = @_;

    $c->stats->profile(begin => "Mysql::_log_stats");

    Thruk::Action::AddDefaults::_set_possible_backends($c, {}) unless defined $c->stash->{'backends'};
    my $output = sprintf("%-20s %-15s %-13s %7s\n", 'Backend', 'Index Size', 'Data Size', 'Items');
    my @result;
    for my $key (@{$c->stash->{'backends'}}) {
        my $peer = $c->{'db'}->get_peer_by_key($key);
        $peer->{'logcache'}->reconnect();
        my $dbh  = $peer->{'logcache'}->_dbh();
        my $res  = $dbh->selectall_hashref("SHOW TABLE STATUS LIKE '".$key."%'", 'Name');
        next unless defined $res->{$key.'_log'};
        my $index_size = $res->{$key.'_log'}->{'Index_length'} + $res->{$key.'_plugin_output'}->{'Index_length'};
        my $data_size  = $res->{$key.'_log'}->{'Data_length'}  + $res->{$key.'_plugin_output'}->{'Data_length'};
        my($val1,$unit1) = Thruk::Utils::reduce_number($index_size, 'B', 1024);
        my($val2,$unit2) = Thruk::Utils::reduce_number($data_size, 'B', 1024);
        $output .= sprintf("%-20s %5.1f %-9s %5.1f %-7s %7d\n", $c->stash->{'backend_detail'}->{$key}->{'name'}, $val1, $unit1, $val2, $unit2, $res->{$key.'_log'}->{'Rows'});
        push @result, {
            key         => $key,
            name        => $c->stash->{'backend_detail'}->{$key}->{'name'},
            index_size  => $index_size,
            data_size   => $data_size,
            items       => $res->{$key.'_log'}->{'Rows'},
        };
    }

    $c->stats->profile(end => "Mysql::_log_stats");
    return @result if wantarray;
    return $output;
}

##########################################################

=head2 _import_logs

  _import_logs

imports logs into Mysql

=cut

sub _import_logs {
    my($self, $c, $mode, $verbose, $backends, $blocksize, $options) = @_;
    my $files = $options->{'url'} || [];
    $c->stats->profile(begin => "Mysql::_import_logs($mode)");

    my $backend_count = 0;
    my $log_count     = 0;
    my $log_skipped   = 0;

    if(!defined $backends) {
        Thruk::Action::AddDefaults::_set_possible_backends($c, {}) unless defined $c->stash->{'backends'};
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
        print "ERROR: you must specify a backend (-b) when importing files.\n" if $verbose;
        return(0, -1);
    }

    for my $key (@{$backends}) {
        my $prefix = $key;
        my $peer   = $c->{'db'}->get_peer_by_key($key);
        next unless $peer->{'enabled'};
        $c->stats->profile(begin => "$key");
        $backend_count++;
        $peer->{'logcache'}->reconnect();
        my $dbh = $peer->{'logcache'}->_dbh;

        print "running ".$mode." for site ".$c->stash->{'backend_detail'}->{$key}->{'name'},"\n" if $verbose;

        # backends maybe down, we still want to continue updates
        eval {
            if($mode eq 'update' or $mode eq 'import' or $mode eq 'clean') {
                $log_count += $self->_update_logcache($c, $mode, $peer, $dbh, $prefix, $verbose, $blocksize, $files);
            }
            elsif($mode eq 'authupdate') {
                $log_count += $self->_update_logcache_auth($c, $peer, $dbh, $prefix, $verbose);
            }
            elsif($mode eq 'optimize') {
                $log_count += $self->_update_logcache_optimize($c, $peer, $dbh, $prefix, $verbose, $options);
            } else {
                print "ERROR: unknown mode: ".$mode."\n" if $@ and $verbose;
            }
        };
        print "ERROR: ", $@,"\n" if $@ and $verbose;

        $c->stats->profile(end => "$key");
        print "\n" if $verbose;
    }

    $c->stats->profile(end => "Mysql::_import_logs($mode)");
    return($backend_count, $log_count);
}

##########################################################
sub _update_logcache {
    my($self, $c, $mode, $peer, $dbh, $prefix, $verbose, $blocksize, $files) = @_;

    unless(defined $blocksize) {
        $blocksize = 86400;
        $blocksize = 365 if $mode eq 'clean';
    }

    my $log_count = 0;

    if($mode eq 'clean') {
        my $start = time() - ($blocksize * 86400);
        print "cleaning logs older than: ", scalar localtime $start, "\n" if $verbose;
        $log_count += $dbh->do("DELETE FROM `".$prefix."_log` WHERE time < ".$start);
        $dbh->commit or die $dbh->errstr;
        return $log_count;
    }

    # check if our tables exist
    my @tables = @{$dbh->selectcol_arrayref('SHOW TABLES LIKE "'.$prefix.'%"')};

    # check if there is already a update / import running
    my $skip          = 0;
    my $cache_version = 1;
    if(scalar @tables == 0) {
        $mode = 'import';
    } else {
        eval {
            my @pids = @{$dbh->selectcol_arrayref('SELECT value FROM `'.$prefix.'_status` WHERE status_id = 2 LIMIT 1')};
            if(scalar @pids > 0 and $pids[0]) {
                if(kill(0, $pids[0])) {
                    print "logcache update already running with pid ".$pids[0]."\n" if $verbose;
                    $skip = 1;
                }
            }
            my @versions = @{$dbh->selectcol_arrayref('SELECT value FROM `'.$prefix.'_status` WHERE status_id = 4 LIMIT 1')};
            if(scalar @versions > 0 and $versions[0]) {
                $cache_version = $versions[0];
            }
        };
        if($@) {
            return(-1);
        }
    }
    return(-1) if $skip;

    if($cache_version < $Thruk::Backend::Provider::Mysql::cache_version) {
        # only log message if not importing already
        if($mode ne 'import') {
            my $msg = 'logcache version too old: '.$cache_version.', recreating with version '.$Thruk::Backend::Provider::Mysql::cache_version.'...';
            print "WARNING: ".$msg."\n" if $verbose;
            $c->log->info($msg);
        }
        $mode = 'import';
    }

    $Thruk::Backend::Provider::Mysql::skip_plugin_db_lookup = 0;
    if($mode eq 'import') {
        $Thruk::Backend::Provider::Mysql::skip_plugin_db_lookup = 1;
        $self->_create_tables($dbh, $prefix);
    }

    $dbh->do("INSERT INTO `".$prefix."_status` (status_id,name,value) VALUES(1,'last_update',UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE value=UNIX_TIMESTAMP()");
    $dbh->do("INSERT INTO `".$prefix."_status` (status_id,name,value) VALUES(2,'update_pid',".$$.") ON DUPLICATE KEY UPDATE value=".$$);
    $dbh->commit or die $dbh->errstr;

    my $stm            = "INSERT INTO `".$prefix."_log` (time,class,type,state,state_type,contact_id,host_id,service_id,plugin_output,message) VALUES";
    my $host_lookup    = _get_host_lookup(   $dbh,$peer,$prefix,               $mode eq 'import' ? 0 : 1);
    my $service_lookup = _get_service_lookup($dbh,$peer,$prefix, $host_lookup, $mode eq 'import' ? 0 : 1);
    my $contact_lookup = _get_contact_lookup($dbh,$peer,$prefix,               $mode eq 'import' ? 0 : 1);
    my $plugin_lookup  = {};

    if(defined $files and scalar @{$files} > 0) {
        $log_count += $self->_import_logcache_from_file($mode,$dbh,$files,$stm,$host_lookup,$service_lookup,$plugin_lookup,$verbose,$prefix,$peer,$contact_lookup);
    } else {
        $log_count += $self->_import_peer_logfiles($c,$mode,$peer,$blocksize,$dbh,$stm,$host_lookup,$service_lookup,$plugin_lookup,$verbose,$prefix,$contact_lookup);
    }

    if($mode eq 'import') {
        print "updateing auth cache\n" if $verbose;
        $self->_update_logcache_auth($c, $peer, $dbh, $prefix, $verbose);
    }

    $dbh->do("INSERT INTO `".$prefix."_status` (status_id,name,value) VALUES(1,'last_update',UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE value=UNIX_TIMESTAMP()");
    $dbh->do("INSERT INTO `".$prefix."_status` (status_id,name,value) VALUES(2,'update_pid',NULL) ON DUPLICATE KEY UPDATE value=NULL");
    $dbh->commit or die $dbh->errstr;

    return $log_count;
}


##########################################################
sub _update_logcache_auth {
    my($self, $c, $peer, $dbh, $prefix, $verbose) = @_;

    $dbh->do("TRUNCATE TABLE `".$prefix."_contact`");
    my $contact_lookup = _get_contact_lookup($dbh,$peer,$prefix);
    my $host_lookup    = _get_host_lookup($dbh,$peer,$prefix);
    my $service_lookup = _get_service_lookup($dbh,$peer,$prefix);

    # update hosts
    my($hosts)    = $peer->{'class'}->get_hosts(columns => [qw/name contacts/]);
    print "hosts" if $verbose;
    my $stm = "INSERT INTO `".$prefix."_contact_host_rel` (contact_id, host_id) VALUES";
    $dbh->do("TRUNCATE TABLE `".$prefix."_contact_host_rel`");
    for my $host (@{$hosts}) {
        my $host_id    = &_host_lookup($host_lookup, $host->{'name'}, $dbh, $prefix);
        my @values;
        for my $contact (@{$host->{'contacts'}}) {
            my $contact_id = _contact_lookup($contact_lookup, $contact, $dbh, $prefix);
            push @values, '('.$contact_id.','.$host_id.')'
        }
        $dbh->do($stm.join(',', @values)) if scalar @values > 0;
        print "." if $verbose;
    }
    print "\n" if $verbose;

    # update services
    print "services" if $verbose;
    $dbh->do("TRUNCATE TABLE `".$prefix."_contact_service_rel`");
    $stm = "INSERT INTO `".$prefix."_contact_service_rel` (contact_id, service_id) VALUES";
    my($services) = $peer->{'class'}->get_services(columns => [qw/host_name description contacts/]);
    for my $service (@{$services}) {
        my $service_id = &_service_lookup($service_lookup, $host_lookup, $service->{'host_name'}, $service->{'description'}, $dbh, $prefix);
        my @values;
        for my $contact (@{$service->{'contacts'}}) {
            my $contact_id = _contact_lookup($contact_lookup, $contact, $dbh, $prefix);
            push @values, '('.$contact_id.','.$service_id.')'
        }
        $dbh->do($stm.join(',', @values)) if scalar @values > 0;
        print "." if $verbose;
    }

    print "\n" if $verbose;

    $dbh->commit or die $dbh->errstr;

    return(scalar @{$hosts} + scalar @{$services});
}

##########################################################
sub _update_logcache_optimize {
    my($self, $c, $peer, $dbh, $prefix, $verbose, $options) = @_;

    # update sort order / optimize every day
    my @times = @{$dbh->selectcol_arrayref('SELECT value FROM `'.$prefix.'_status` WHERE status_id = 3 LIMIT 1')};
    if(!$options->{'force'} and scalar @times > 0 and $times[0] and $times[0] > time()-86400) {
        print "no optimize neccessary, last optimize: ".(scalar localtime $times[0]).", use -f to force\n" if $verbose;
        return(-1);
    }

    print "update logs table order..." if $verbose;
    $dbh->do("ALTER TABLE `".$prefix."_log` ORDER BY time");
    $dbh->do("INSERT INTO `".$prefix."_status` (status_id,name,value) VALUES(3,'last_reorder',UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE value=UNIX_TIMESTAMP()");
    print "done\n" if $verbose;

    # repair / optimize tables
    print "optimizing / repairing tables\n" if $verbose;
    for my $table (qw/contact contact_host_rel contact_service_rel host log plugin_output service status/) {
        print $table.'...' if $verbose;
        $dbh->do("REPAIR TABLE `".$prefix."_".$table.'`');
        $dbh->do("OPTIMIZE TABLE `".$prefix."_".$table.'`');
        print "OK\n" if $verbose;
    }

    $dbh->commit or die $dbh->errstr;
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
        $dbh->do($stm.join(',', @values));
        $sth->execute;
        for my $r (@{$sth->fetchall_arrayref()}) { $hosts_lookup->{$r->[1]} = $r->[0]; }
    }
    return $hosts_lookup;
}


##########################################################
sub _get_service_lookup {
    my($dbh,$peer,$prefix,$hosts_lookup,$noupdate) = @_;

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
        my $host_id = &_host_lookup($hosts_lookup, $s->{'host_name'}, $dbh, $prefix);
        push @values, '('.$host_id.','.$dbh->quote($s->{'description'}).')';
    }
    if(scalar @values > 0) {
        $dbh->do($stm.join(',', @values));
        $sth->execute;
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
        $dbh->do($stm.join(',', @values));
        $sth->execute;
        for my $r (@{$sth->fetchall_arrayref()}) { $contact_lookup->{$r->[1]} = $r->[0]; }
    }
    return $contact_lookup;
}

##########################################################
sub _get_plugin_lookup {
    my($dbh,$peer,$prefix) = @_;

    my $sth = $dbh->prepare("SELECT output_id, output FROM `".$prefix."_plugin_output`");
    $sth->execute;
    my $plugin_lookup = {};
    for my $o (@{$sth->fetchall_arrayref()}) { $plugin_lookup->{$o->[1]} = $o->[0]; }
    return $plugin_lookup;
}

##########################################################
sub _plugin_lookup {
    my($hash, $look, $dbh, $prefix) = @_;
    my $id = $hash->{$look};
    return $id if $id;

    # check database first
    unless($Thruk::Backend::Provider::Mysql::skip_plugin_db_lookup) {
        my @ids = @{$dbh->selectall_arrayref('SELECT output_id FROM `'.$prefix.'_plugin_output` WHERE output = '.$dbh->quote($look).' LIMIT 1')};
        if(scalar @ids > 0) {
            $id = $ids[0]->[0];
            $hash->{$look} = $id;
            return $id;
        }
    }

    $dbh->do("INSERT INTO `".$prefix."_plugin_output` (output) VALUES(".$dbh->quote($look).")");
    $id = $dbh->last_insert_id(undef, undef, undef, undef);
    $hash->{$look} = $id;
    return $id;
}

##########################################################
sub _host_lookup {
    my($host_lookup, $host_name, $dbh, $prefix) = @_;
    return 'NULL' unless $host_name;

    my $id = $host_lookup->{$host_name};
    return $id if $id;

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
    my($service_lookup, $host_lookup, $host_name, $service_description, $dbh, $prefix) = @_;
    return 'NULL' unless $service_description;

    my $id = $service_lookup->{$host_name}->{$service_description};
    return $id if $id;

    my $host_id = &_host_lookup($host_lookup, $host_name, $dbh, $prefix);

    $dbh->do("INSERT INTO `".$prefix."_service` (host_id, service_description) VALUES(".$host_id.", ".$dbh->quote($service_description).")");
    $id = $dbh->last_insert_id(undef, undef, undef, undef);
    $service_lookup->{$host_name}->{$service_description} = $id;

    return $id;
}

##########################################################
sub _contact_lookup {
    my($contact_lookup, $contact_name, $dbh, $prefix) = @_;
    return 'NULL' unless $contact_name;

    my $id = $contact_lookup->{$contact_name};
    return $id if $id;

    $dbh->do("INSERT INTO `".$prefix."_contact` (name) VALUES(".$dbh->quote($contact_name).")");
    $id = $dbh->last_insert_id(undef, undef, undef, undef);
    $contact_lookup->{$contact_name} = $id;

    return $id;
}

##########################################################
sub _trim_log_entry {
    my($l) = @_;
    # strip time
    $l->{'message'} =~ s/^\[$l->{'time'}\]\ //mx;

    # strip type
    $l->{'message'} =~ s/^\Q$l->{'type'}\E:\ //mx;

    # strip contact_name
    if($l->{'contact_name'}) {
        $l->{'message'} =~ s/^\Q$l->{'contact_name'}\E;//mx;
    }

    # strip host_name
    if($l->{'host_name'}) {
        $l->{'message'} =~ s/^\Q$l->{'host_name'}\E;//mx;
    }

    # strip service description
    if($l->{'service_description'}) {
        $l->{'message'} =~ s/^\Q$l->{'service_description'}\E;//mx;
    }

    # strip plugin output from the end
    if($l->{'plugin_output'}) {
        my $length = length $l->{'plugin_output'};
        $l->{'message'} = substr($l->{'message'}, 0, -$length);
    }
    return;
}

##########################################################
sub _fill_lookup_logs {
    my($self,$peer,$start,$end) = @_;
    my $lookup = {};
    my($mlogs) = $peer->{'class'}->get_logs(
                                        filter  => [{ '-and' => [
                                                                { time => { '>=' => $start } },
                                                                { time => { '<=' => $end } }
                                                   ]}]
                              );
    for my $l (@{$mlogs}) {
        $lookup->{$l->{'message'}} = 1;
    }
    return $lookup;
}

##########################################################
sub _import_peer_logfiles {
    my($self,$c,$mode,$peer,$blocksize,$dbh,$stm,$host_lookup,$service_lookup,$plugin_lookup,$verbose,$prefix,$contact_lookup) = @_;

    # get start / end timestamp
    my($mstart, $mend);
    my $filter = [];
    if($mode eq 'update') {
        $c->stats->profile(begin => "get last mysql timestamp");
        # get last timestamp from Mysql
        ($mstart, $mend) = @{$peer->{'logcache'}->_get_logs_start_end(collection => $prefix)};
        if(defined $mend) {
            print "latest entry in logcache: ", scalar localtime $mend, "\n" if $verbose;
            push @{$filter}, {time => { '>=' => $mend }};
        }
        $c->stats->profile(end => "get last mysql timestamp");
    }

    my $log_count = 0;
    $c->stats->profile(begin => "get livestatus timestamp");
    my($start, $end) = @{$peer->{'class'}->_get_logs_start_end(filter => $filter)};
    print "latest entry in logfile:  ", scalar localtime $end, "\n" if $verbose;
    $c->stats->profile(end => "get livestatus timestamp");
    print "importing ", scalar localtime $start, " till ", scalar localtime $end, "\n" if $verbose;
    my $time = $start;

    # increase plugin output lookup performance for larger updates
    if($end - $start > 86400) {
        $plugin_lookup = _get_plugin_lookup($dbh,$peer,$prefix);
        $Thruk::Backend::Provider::Mysql::skip_plugin_db_lookup = 1;
    }

    while($time <= $end) {
        my $stime = scalar localtime $time;
        $c->stats->profile(begin => $stime);
        my $duplicate_lookup = {};
        print scalar localtime $time if $verbose;
        my $logs = [];
        eval {
            # get logs from peer
            ($logs) = $peer->{'class'}->get_logs(nocache => 1,
                                                 filter  => [{ '-and' => [
                                                                    { time => { '>=' => $time } },
                                                                    { time => { '<'  => $time + $blocksize } }
                                                            ]}],
                                                 columns => [qw/
                                                                class time type state host_name service_description plugin_output message state_type contact_name
                                                           /],
                                                );
            if($mode eq 'update') {
                # get already stored logs to filter duplicates
                $duplicate_lookup = $self->_fill_lookup_logs($peer,$time,($time+$blocksize));
            }
        };
        if($@) {
            my $err = $@;
            chomp($err);
            print $err;
        }

        $time = $time + $blocksize;

        # increase plugin output lookup performance for larger updates
        if($Thruk::Backend::Provider::Mysql::skip_plugin_db_lookup == 0 and scalar @{$logs} > 500) {
            $plugin_lookup = _get_plugin_lookup($dbh,$peer,$prefix);
            $Thruk::Backend::Provider::Mysql::skip_plugin_db_lookup = 1;
        }

        $log_count += $self->_insert_logs($dbh,$stm,$mode,$logs,$host_lookup,$service_lookup,$plugin_lookup,$duplicate_lookup,$verbose,$prefix,$contact_lookup);

        $c->stats->profile(end => $stime);
        print "\n" if $verbose;
    }
    return $log_count;
}

##########################################################
sub _import_logcache_from_file {
    my($self,$mode,$dbh,$files,$stm,$host_lookup,$service_lookup,$plugin_lookup,$verbose,$prefix,$peer,$contact_lookup) = @_;

    # increase plugin output lookup performance for larger updates
    if($Thruk::Backend::Provider::Mysql::skip_plugin_db_lookup == 0) {
        $plugin_lookup = _get_plugin_lookup($dbh,$peer,$prefix);
        $Thruk::Backend::Provider::Mysql::skip_plugin_db_lookup = 1;
    }

    my $log_count = 0;
    for my $f (@{$files}) {
        print $f if $verbose;
        my $duplicate_lookup = {};
        if($mode eq 'update') {
            my($fstart,$fend) = _get_start_end_from_logfile($f);
            # get already stored logs to filter duplicates
            $duplicate_lookup = $self->_fill_lookup_logs($peer,$fstart,$fend);
        }

        my @values;
        open(my $fh, '<', $f) or die("cannot open ".$f.": ".$!);
        while(my $line = <$fh>) {
            chomp($line);
            &Thruk::Utils::decode_any($line);
            if($mode eq 'update') {
                next if defined $duplicate_lookup->{$line};
            }
            $log_count++;
            my $l = &Monitoring::Availability::Logs::parse_line($line);
            next unless $l->{'time'};
            $l->{'state_type'} = '';
            if(exists $l->{'hard'}) {
                if($l->{'hard'}) {
                    $l->{'state_type'} = 'HARD';
                } else {
                    $l->{'state_type'} = 'SOFT';
                }
            }
            $l->{'state_type'}    = '' unless defined $l->{'state_type'};
            $l->{'state'}         = '' unless defined $l->{'state'};
            $l->{'plugin_output'} = '' unless defined $l->{'plugin_output'};
            $l->{'message'}       = $line;
            my $state             = $l->{'state'};
            my $state_type        = $l->{'state_type'};
            &_set_class($l);
            if($state eq '')      { $state      = 'NULL'; }
            if($state_type eq '') { $state_type = 'NULL'; }
            my $host    = &_host_lookup($host_lookup, $l->{'host_name'}, $dbh, $prefix);
            my $svc     = &_service_lookup($service_lookup, $host_lookup, $l->{'host_name'}, $l->{'service_description'}, $dbh, $prefix);
            my $contact = 'NULL';
            $contact    = &_contact_lookup($contact_lookup, $l->{'contact_name'}, $dbh, $prefix) if $l->{'contact_name'};
            &_trim_log_entry($l);
            my $plugin  = &_plugin_lookup($plugin_lookup, $l->{'plugin_output'}, $dbh, $prefix);
            my $message = &_plugin_lookup($plugin_lookup, $l->{'message'}, $dbh, $prefix);

            push @values, '('.$l->{'time'}.','.$l->{'class'}.','.$dbh->quote($l->{'type'}).','.$state.','.$dbh->quote($state_type).','.$contact.','.$host.','.$svc.','.$plugin.','.$message.')';

            # commit every 1000th to avoid to large blocks
            if($log_count%1000) {
                $self->_safe_insert($dbh, $stm, \@values, $verbose);
                @values = ();
            }
            print '.' if $log_count%100 == 0 and $verbose;
        }
        $self->_safe_insert($dbh, $stm, \@values, $verbose) if scalar @values > 0;
        CORE::close($fh);
        print "\n" if $verbose;
    }

    print "it is recommended to run logcacheoptimize after importing logfiles.\n" if $verbose;

    return $log_count;
}

##########################################################
sub _get_start_end_from_logfile {
    my($file) = @_;
    my($start,$end);
    open(my $fh, '<', $file) or die("cannot open ".$file.": ".$!);
    my $first_line = <$fh>;
    my $pos = -1;
    my $char;
    my $already_nonblank = 0;
    while(seek($fh,$pos--,2)) {
        read $fh,$char,1;
        last if ($char eq "\n" and $already_nonblank == 1);
        $already_nonblank = 1 if ($char ne "\n");
    }
    my $last_line = <$fh>;
    CORE::close($fh);

    if($first_line =~ m/^\[(\d+)\]/mx) { $start = $1; }
    if($last_line  =~ m/^\[(\d+)\]/mx) { $end   = $1; }
    return($start,$end);
}

##########################################################
sub _insert_logs {
    my($self,$dbh,$stm,$mode,$logs,$host_lookup,$service_lookup,$plugin_lookup,$duplicate_lookup,$verbose,$prefix,$contact_lookup) = @_;
    my $log_count = 0;
    my @values;
    for my $l (@{$logs}) {
        if($mode eq 'update') {
            next if defined $duplicate_lookup->{$l->{'message'}};
        }
        $log_count++;
        print '.' if $log_count%100 == 0 and $verbose;
        my $type    = $l->{'type'};
        $type = 'TIMEPERIOD TRANSITION' if $type =~ m/^TIMEPERIOD\ TRANSITION/mxo;
        if($type eq 'TIMEPERIOD TRANSITION') {
            $l->{'plugin_output'} = '';
        }
        if($type eq 'SERVICE NOTIFICATION' or $type eq 'HOST NOTIFICATION') {
            $l->{'plugin_output'} = ''; # would result in duplicate output otherwise
        }
        my $state       = $l->{'state'};
        $state          = 'NULL' if $state eq '';
        my $state_type  = $l->{'state_type'};
        $state_type     = 'NULL' if $state_type eq '';
        my $host        = &_host_lookup($host_lookup, $l->{'host_name'}, $dbh, $prefix);
        my $svc         = &_service_lookup($service_lookup, $host_lookup, $l->{'host_name'}, $l->{'service_description'}, $dbh, $prefix);
        my $contact     = 'NULL';
        $contact        = &_contact_lookup($contact_lookup, $l->{'contact_name'}, $dbh, $prefix) if $l->{'contact_name'};
        &_trim_log_entry($l);
        my $plugin      = &_plugin_lookup($plugin_lookup, $l->{'plugin_output'}, $dbh, $prefix);
        my $message     = &_plugin_lookup($plugin_lookup, $l->{'message'}, $dbh, $prefix);
        push @values, '('.$l->{'time'}.','.$l->{'class'}.','.$dbh->quote($type).','.$state.','.$dbh->quote($state_type).','.$contact.','.$host.','.$svc.','.$plugin.','.$message.')';

        # commit every 1000th to avoid to large blocks
        if($log_count%1000 == 0) {
            $self->_safe_insert($dbh, $stm, \@values, $verbose);
            @values = ();
        }
    }
    $self->_safe_insert($dbh, $stm, \@values, $verbose) if scalar @values > 0;
    print '. '.$log_count . " entries added" if $verbose;
    return $log_count;
}

##########################################################
sub _create_tables {
    my($self, $dbh, $prefix) = @_;
    for my $stm (@{_get_create_statements($prefix)}) {
        $dbh->do($stm);
    }
    $dbh->commit or die $dbh->errstr;
    return;
}

##########################################################
sub _drop_tables {
    my($self, $dbh, $prefix) = @_;
    for my $table (qw/contact contact_host_rel contact_service_rel host log plugin_output service status/) {
        $dbh->do("DROP TABLE IF EXISTS `".$prefix."_".$table.'`');
    }
    $dbh->commit or die $dbh->errstr;
    return;
}

##########################################################
sub _safe_insert {
    my($self, $dbh, $stm, $values, $verbose) = @_;
    eval {
        $dbh->do($stm.join(',', @{$values}));
    };
    if($@) {
        print "ERROR: ".$@."\n" if $verbose;

        # insert failed for some reason, try them one by one to see which one breaks
        for my $v (@{$values}) {
            eval {
                $dbh->do($stm.$v);
            };
            print "ERROR: ".$@."\n"                    if $verbose;
            print "ERROR: insert failed for: ".$v."\n" if $verbose;
        }
    }
    $dbh->commit or die $dbh->errstr;
    return;
}

##########################################################
sub _set_class {
    my($l) = @_;
    my $type = $l->{'type'};
    $l->{'class'} = $Thruk::Backend::Provider::Mysql::db_types->{$type} if defined $type;
    return if defined $l->{'class'};
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
       or $l->{'message'} =~ m/LOG\ VERSION:/mxo
    ) {
        $l->{'class'} = 2; # LOGCLASS_PROGRAM
        $l->{'message'} = $l->{'type'}.': '.$l->{'message'} if $l->{'type'};
        $l->{'type'}    = '';
        return;
    }

    if($type =~ m/^TIMEPERIOD\ TRANSITION/mxo) {
        $l->{'type'}          = 'TIMEPERIOD TRANSITION';
        $l->{'plugin_output'} = '';
        $l->{'class'}         = 6; # LOGCLASS_STATE
        return;
    }

    $l->{'message'} = $l->{'type'}.': '.$l->{'message'} if $l->{'type'};
    $l->{'type'}    = '';
    $l->{'class'}   = 0; # LOGCLASS_INFO
    return;
}

##########################################################
sub _get_create_statements {
    my($prefix) = @_;
    my @statements = (
    # contact
        "DROP TABLE IF EXISTS `".$prefix."_contact`",
        "CREATE TABLE `".$prefix."_contact` (
          contact_id mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
          name varchar(150) NOT NULL,
          PRIMARY KEY (contact_id)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin",

    # contact_host_rel
        "DROP TABLE IF EXISTS `".$prefix."_contact_host_rel`",
        "CREATE TABLE `".$prefix."_contact_host_rel` (
          contact_id mediumint(8) unsigned NOT NULL,
          host_id mediumint(8) unsigned NOT NULL,
          PRIMARY KEY (contact_id,host_id)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin",

    # contact_service_rel
        "DROP TABLE IF EXISTS `".$prefix."_contact_service_rel`",
        "CREATE TABLE `".$prefix."_contact_service_rel` (
          contact_id mediumint(8) unsigned NOT NULL,
          service_id mediumint(8) unsigned NOT NULL,
          PRIMARY KEY (contact_id,service_id)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin",

    # host
        "DROP TABLE IF EXISTS `".$prefix."_host`",
        "CREATE TABLE `".$prefix."_host` (
          host_id mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
          host_name varchar(150) NOT NULL,
          PRIMARY KEY (host_id)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin",

    # log
        "DROP TABLE IF EXISTS `".$prefix."_log`",
        "CREATE TABLE IF NOT EXISTS `".$prefix."_log` (
          time int(10) unsigned NOT NULL,
          class tinyint(3) unsigned NOT NULL,
          type enum('CURRENT SERVICE STATE','CURRENT HOST STATE','SERVICE NOTIFICATION','HOST NOTIFICATION','SERVICE ALERT','HOST ALERT','SERVICE EVENT HANDLER','HOST EVENT HANDLER','EXTERNAL COMMAND','PASSIVE SERVICE CHECK','PASSIVE HOST CHECK','SERVICE FLAPPING ALERT','HOST FLAPPING ALERT','SERVICE DOWNTIME ALERT','HOST DOWNTIME ALERT','LOG ROTATION','INITIAL HOST STATE','INITIAL SERVICE STATE','TIMEPERIOD TRANSITION') DEFAULT NULL,
          state tinyint(2) unsigned DEFAULT NULL,
          state_type enum('HARD','SOFT') NOT NULL,
          contact_id mediumint(8) unsigned DEFAULT NULL,
          host_id mediumint(8) unsigned DEFAULT NULL,
          service_id mediumint(8) unsigned DEFAULT NULL,
          plugin_output mediumint(8) NOT NULL,
          message mediumint(8) NOT NULL,
          KEY time (time),
          KEY host_id (host_id)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin PACK_KEYS=1",

    # plugin_output
        "DROP TABLE IF EXISTS `".$prefix."_plugin_output`",
        "CREATE TABLE `".$prefix."_plugin_output` (
          output_id mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
          output mediumtext NOT NULL,
          PRIMARY KEY (output_id)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin",

    # service
        "DROP TABLE IF EXISTS `".$prefix."_service`",
        "CREATE TABLE `".$prefix."_service` (
          service_id mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
          host_id mediumint(8) unsigned NOT NULL,
          service_description varchar(150) NOT NULL,
          PRIMARY KEY (service_id),
          KEY host_id (host_id)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin",

    # status
        "DROP TABLE IF EXISTS `".$prefix."_status`",
        "CREATE TABLE `".$prefix."_status` (
          status_id smallint(4) unsigned NOT NULL AUTO_INCREMENT,
          name varchar(150) NOT NULL,
          value varchar(150) DEFAULT NULL,
          PRIMARY KEY (status_id)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin",

        "INSERT INTO `".$prefix."_status` (status_id, name, value) VALUES(1, 'last_update', '')",
        "INSERT INTO `".$prefix."_status` (status_id, name, value) VALUES(2, 'update_pid', '')",
        "INSERT INTO `".$prefix."_status` (status_id, name, value) VALUES(3, 'last_reorder', '')",
        "INSERT INTO `".$prefix."_status` (status_id, name, value) VALUES(4, 'cache_version', '".$Thruk::Backend::Provider::Mysql::cache_version."')",
    );
    return \@statements;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2013, <sven.nierlein@consol.de>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
