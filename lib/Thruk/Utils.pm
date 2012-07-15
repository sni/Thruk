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
use Date::Calc qw/Localtime Mktime Monday_of_Week Week_of_Year Today Normalize_DHMS/;
use Date::Manip;
use File::Slurp;
use Encode qw/decode/;
use Template::Plugin::Date;
use File::Copy;
use File::Temp qw/tempfile/;
use Excel::Template::Plus;

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
        $timestamp = Thruk::Utils::_parse_date($c, $string);
        if(defined $timestamp) {
            $c->log->debug("parse_date: '".$string."' to -> '".(scalar localtime $timestamp)."'");
        } else {
            $c->log->error("error parsing data: '".$string."'");
            return $c->detach('/error/index/19');
        }
    };
    if($@) {
        $c->log->error($@);
        return $c->detach('/error/index/19');
    }
    return $timestamp;
}


##############################################

=head2 format_date

  my $date_string = format_date($string, $format)

return date from timestamp in given format

=cut
sub format_date {
    my($timestamp, $format) = @_;
    our($tpd);
    $tpd = Template::Plugin::Date->new() unless defined $tpd;
    my $date = $tpd->format($timestamp, $format);
    return decode("utf-8", $date);
}


##############################################

=head2 format_cronentry

  my $cron_string = format_cronentry($cron_entry)

return cron entry as string

=cut
sub format_cronentry {
    my($c, $cr) = @_;
    my $cron;
    if($cr->{'type'} eq 'month') {
        my $app = 'th';
        if($cr->{'day'} == 1) { $app = 'st'; }
        if($cr->{'day'} == 2) { $app = 'nd'; }
        if($cr->{'day'} == 3) { $app = 'rd'; }
        $cron = sprintf("every %s%s at %02s:%02s", $cr->{'day'}, $app, $cr->{'hour'}, $cr->{'minute'});
    }
    elsif($cr->{'type'} eq 'week') {
        if(defined $cr->{'week_day'} and $cr->{'week_day'} ne '') {
            my @days;
            my @daynr = split/,/mx, $cr->{'week_day'};
            my $lastconcated = [];
            for my $x (0..$#daynr) {
                my $nr = $daynr[$x];
                $nr = 7 if $nr == 0;
                my $next = $daynr[$x+1] || 0;
                $next = 7 if $next == 0;
                if($next == $nr+1) {
                    if(!defined $lastconcated->[0]) {
                        $lastconcated->[0] = $c->config->{'weekdays'}->{$nr};
                    } else {
                        $lastconcated->[1] = $c->config->{'weekdays'}->{$nr};
                    }
                } else {
                    if(defined $lastconcated->[0]) {
                        push @days, $lastconcated->[0].'-'.$c->config->{'weekdays'}->{$nr};
                        $lastconcated = [];
                    } else {
                        push @days, $c->config->{'weekdays'}->{$nr};
                    }
                }
            }
            if(defined $lastconcated->[0]) {
                push @days, $lastconcated->[0].'-'.$lastconcated->[1];
            }
            $cron = sprintf("%s at %02s:%02s", join(', ', @days), $cr->{'hour'}, $cr->{'minute'});
        } else {
            $cron = 'never';
        }
    }
    elsif($cr->{'type'} eq 'day') {
        $cron = sprintf("daily at %02s:%02s", $cr->{'hour'}, $cr->{'minute'});
    } else {
        confess("unknown cron type: ".$cr->{'type'});
    }
    return $cron;
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
            return $c->detach('/error/index/4');
        }
        print STDERR "cgi.cfg option must be set in thruk.conf or thruk_local.conf\n\n";
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
            return $c->detach('/error/index/4');
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
        $config->{'cgi.cfg_effective'} = $file;
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
    local $SIG{__DIE__} = '';
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

=head2 calculate_overall_processinfo

  my $process_info = calculate_overall_processinfo($process_info)

computes a combined status for process infos

=cut
sub calculate_overall_processinfo {
    my $pi = shift;
    my $return = {};

    # if no backend is available
    return($return) if ref $pi ne 'HASH';

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
    my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
    if($timeperiod eq 'today') {
        $start = Mktime($year,$month,$day,  0,0,0);
        $end   = time();
    }
    elsif($timeperiod eq 'last24hours') {
        $end   = time();
        $start = $end - 86400;
    }
    elsif($timeperiod eq 'yesterday') {
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
        $start = Mktime($year,$month,1,  0,0,0);
        $end   = time();
    }
    elsif($timeperiod eq 'last31days') {
        $end   = time();
        $start = $end - 31 * 86400;
    }
    elsif($timeperiod eq 'lastmonth') {
        $end   = Mktime($year,$month,1,  0,0,0);
        my $lastmonth = $month - 1;
        if($lastmonth <= 0) { $lastmonth = $lastmonth + 12; $year--;}
        $start = Mktime($year,$lastmonth,1,  0,0,0);
    }
    elsif($timeperiod eq 'last12months') {
        $start = Mktime($year-1,$month,1,  0,0,0);
        $end   = Mktime($year,$month,1,  0,0,0);
    }
    elsif($timeperiod eq 'thisyear') {
        $start = Mktime($year,1,1,  0,0,0);
        $end   = time();
    }
    elsif($timeperiod eq 'lastyear') {
        $start = Mktime($year-1,1,1,  0,0,0);
        $end   = Mktime($year,1,1,  0,0,0);
    }
    else {
        if(defined $t1) {
            $start = $t1;
        } else {
            $start = normal_mktime($syear,$smon,$sday, $shour,$smin,$ssec);
        }

        if(defined $t2) {
            $end   = $t2;
        } else {
            $end   = normal_mktime($eyear,$emon,$eday, $ehour,$emin,$esec);
        }
    }

    if(!defined $start or !defined $end) {
        return(undef, undef);
    }

    $c->log->debug("start: ".$start." - ".(scalar localtime($start)));
    $c->log->debug("end  : ".$end." - ".(scalar localtime($end)));

    if($end >= $start) {
        return($start, $end);
    }
    return($end, $start);
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
    my $shour        = $c->{'request'}->{'parameters'}->{'shour'}  || 0;
    my $smin         = $c->{'request'}->{'parameters'}->{'smin'}   || 0;
    my $ssec         = $c->{'request'}->{'parameters'}->{'ssec'}   || 0;
    my $emon         = $c->{'request'}->{'parameters'}->{'emon'};
    my $eday         = $c->{'request'}->{'parameters'}->{'eday'};
    my $eyear        = $c->{'request'}->{'parameters'}->{'eyear'};
    my $ehour        = $c->{'request'}->{'parameters'}->{'ehour'}  || 0;
    my $emin         = $c->{'request'}->{'parameters'}->{'emin'}   || 0;
    my $esec         = $c->{'request'}->{'parameters'}->{'esec'}   || 0;
    my $t1           = $c->{'request'}->{'parameters'}->{'t1'};
    my $t2           = $c->{'request'}->{'parameters'}->{'t2'};

    $timeperiod = 'last24hours' if(!defined $timeperiod and !defined $t1 and !defined $t2);
    return Thruk::Utils::get_start_end_for_timeperiod($c, $timeperiod,$smon,$sday,$syear,$shour,$smin,$ssec,$emon,$eday,$eyear,$ehour,$emin,$esec,$t1,$t2);
}

########################################

=head2 set_dynamic_roles

  set_dynamic_roles($c)

sets the authorized_for_read_only role and group based roles

=cut
sub set_dynamic_roles {
    my $c = shift;

    $c->stats->profile(begin => "Thruk::Utils::set_dynamic_roles");
    my $username = $c->request->{'user'}->{'username'};

    return unless defined $username;

    # is the contact allowed to send commands?
    my($can_submit_commands,$alias,$data);
    my $cache = $c->cache;
    my $cached_data = defined $username ? $cache->get($username) : {};
    if(defined $cached_data->{'can_submit_commands'}) {
        # got cached data
        $data = $cached_data->{'can_submit_commands'};
    }
    else {
        $data = $c->{'db'}->get_can_submit_commands($username);
        $cached_data->{'can_submit_commands'} = $data;
        $cache->set($username, $cached_data) if defined $username;
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
        push @{$c->request->{'user'}->{'roles'}}, 'authorized_for_read_only';
    }

    my $groups = $cached_data->{'contactgroups'};

    # add roles from groups in cgi.cfg
    my $possible_roles = {
                      'authorized_contactgroup_for_all_host_commands'         => 'authorized_for_all_host_commands',
                      'authorized_contactgroup_for_all_hosts'                 => 'authorized_for_all_hosts',
                      'authorized_contactgroup_for_all_service_commands'      => 'authorized_for_all_service_commands',
                      'authorized_contactgroup_for_all_services'              => 'authorized_for_all_services',
                      'authorized_contactgroup_for_configuration_information' => 'authorized_for_configuration_information',
                      'authorized_contactgroup_for_system_commands'           => 'authorized_for_system_commands',
                      'authorized_contactgroup_for_system_information'        => 'authorized_for_system_information',
                      'authorized_contactgroup_for_read_only'                 => 'authorized_for_read_only',
                    };
    for my $key (keys %{$possible_roles}) {
        my $role = $possible_roles->{$key};
        if(defined $c->config->{'cgi_cfg'}->{$key}) {
            my %contactgroups = map { $_ => 1 } split/\+*,\*s/mx, $c->config->{'cgi_cfg'}->{$key};
            for my $contactgroup (keys %{contactgroups}) {
                push @{$c->request->{'user'}->{'roles'}}, $role if ( defined $groups->{$contactgroup} or $contactgroup eq '*' );
            }
        }
    }


    $c->stats->profile(end => "Thruk::Utils::set_dynamic_roles");
    return 1;
}


########################################

=head2 set_message

  set_message($c, $style, $text, [ $details ])

set a message in an cookie for later display

=cut
sub set_message {
    my $c   = shift;
    my $dat = shift;
    my($style, $message, $details, $code);

    if(ref $dat eq 'HASH') {
        $style   = $dat->{'style'};
        $message = $dat->{'msg'};
        $details = $dat->{'details'};
        $code    = $dat->{'code'};
    } else {
        $style   = $dat;
        $message = shift;
        $details = shift;
        $code    = shift;
    }

    $c->res->cookies->{'thruk_message'} = {
        value => $style.'~~'.$message,
    };
    $c->stash->{'thruk_message'}         = $style.'~~'.$message;
    $c->stash->{'thruk_message_details'} = $details;
    $c->response->status($code) if defined $code;

    return 1;
}


########################################

=head2 ssi_include

  ssi_include($c)

puts the ssi templates into the stash

=cut
sub ssi_include {
    my $c = shift;
    my $global_header_file = "common-header.ssi";
    my $header_file        = $c->stash->{'page'}."-header.ssi";
    my $global_footer_file = "common-footer.ssi";
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
    if( -x $c->config->{'ssi_path'}."/".$file ){
       open(my $ph, '-|', $c->config->{'ssi_path'}."/".$file.' 2>&1') or carp("cannot execute ssi: $!");
       local $/=undef;
       my $output = <$ph>;
       Thruk::Utils::IO::close($ph, undef, 1);
       return $output;
    }
    elsif( -r $c->config->{'ssi_path'}."/".$file ){
        return read_file($c->config->{'ssi_path'}."/".$file) or carp("cannot open ssi: $!");
    }
    $c->log->warn($c->config->{'ssi_path'}."/".$file." is no longer accessible, please restart thruk to initialize ssi information");
    return "";
}


########################################

=head2 version_compare

  version_compare($version1, $version2)

compare too version strings and return 1 if v1 >= v2

=cut
sub version_compare {
    my($v1,$v2) = @_;
    confess("version_compare() needs two params, got: ".Dumper(\@_)) unless defined $v2;

    # replace non-numerical characters
    $v1 =~ s/[^\d\.]/./gmx;
    $v2 =~ s/[^\d\.]/./gmx;

    my @v1 = split/\./mx,$v1;
    my @v2 = split/\./mx,$v2;

    for(my $x = 0; $x < scalar @v1; $x++) {
        my $cmp1 = 0;
        my $cmp2 = 0;
        if(defined $v1[$x] and $v1[$x] =~ m/^(\d+)/gmx) { $cmp1 = $1; }
        if(defined $v2[$x] and $v2[$x] =~ m/^(\d+)/gmx) { $cmp2 = $1; }
        if ($cmp1 > $cmp2) {
            return 1;
        }
        if ($cmp1 < $cmp2) {
            return 0;
        }
    }
    return 1;
}


########################################

=head2 combine_filter

  combine_filter($operator, $filter)

combine filter by operator

=cut
sub combine_filter {
    my $operator = shift;
    my $filter   = shift;

    my $return;
    if(!defined $operator and $operator ne '-or' and $operator ne '-and') {
        confess("unknown operator: ".Dumper($operator));
    }

    return unless defined $filter;

    if(ref $filter ne 'ARRAY') {
        confess("expected arrayref, got: ".Dumper(ref $filter));
    }

    return if scalar @{$filter} == 0;

    if(scalar @{$filter} == 1) {
        return $filter->[0];
    }

    return { $operator => $filter };

    return $return;
}


########################################

=head2 array2hash

  array2hash($data, [ $key, [ $key2 ]])

create a hash by key

=cut
sub array2hash {
    my $data = shift;
    my $key  = shift;
    my $key2 = shift;

    return {} unless defined $data;
    confess("not an array") unless ref $data eq 'ARRAY';

    my %hash;
    if(defined $key2) {
        for my $d (@{$data}) {
            $hash{$d->{$key}}->{$d->{$key2}} = $d;
        }
    } elsif(defined $key) {
        %hash = map { $_->{$key} => $_ } @{$data};
    } else {
        %hash = map { $_ => $_ } @{$data};
    }

    return \%hash;
}


########################################

=head2 set_paging_steps

  set_paging_steps($c, $data)

sets the pagins stepts, needs string like:

  *100, 500, 1000, all

=cut
sub set_paging_steps {
    my $c    = shift;
    my $data = shift;

    $c->stash->{'paging_steps'}      = [ '100', '500', '1000', '5000', 'all' ];
    $c->stash->{'default_page_size'} = 100;

    return unless defined $data;

    # we need an array
    $data = ref $data eq 'ARRAY' ? $data : [split(/\s*,\s*/mx, $data)];

    $c->stash->{'paging_steps'}      = [];
    $c->stash->{'default_page_size'} = undef;

    for my $step (@{$data}) {
        if($step =~ m/^\*(.*)$/mx) {
            $step                            = $1;
            $c->stash->{'default_page_size'} = $step;
        }
        push @{$c->stash->{'paging_steps'}}, $step;
    }

    # no default yet?
    unless(defined $c->stash->{'default_page_size'}) {
        $c->stash->{'default_page_size'} = $c->stash->{'paging_steps'}->[0];
    }

    return;
}


########################################

=head2 set_custom_vars

  set_custom_vars($c)

set stash value for all allowed custom variables

=cut
sub set_custom_vars {
    my $c    = shift;
    my $data = shift;

    $c->stash->{'custom_vars'} = {};

    return unless defined $data;
    return unless defined $data->{'custom_variable_names'};
    return unless defined $c->config->{'show_custom_vars'};

    my $vars = ref $c->config->{'show_custom_vars'} eq 'ARRAY' ? $c->config->{'show_custom_vars'} : [ $c->config->{'show_custom_vars'} ];
    my $test = array2hash($vars);

    my $x = 0;
    while(defined $data->{'custom_variable_names'}->[$x]) {
        my $cust_name  = '_'.$data->{'custom_variable_names'}->[$x];
        my $cust_value = '_'.$data->{'custom_variable_values'}->[$x];
        my $found      = 0;
        if(defined $test->{$cust_name}) {
            $found = 1;
        } else {
            for my $v (keys %{$test}) {
                next if CORE::index($v, '*') == -1;
                $v =~ s/\*/.*/gmx;
                if($cust_name =~ m/^$v$/mx) {
                    $found = 1;
                    last;
                }
            }
        }
        if($found) {
            $c->stash->{'custom_vars'}->{$cust_name} = $cust_value;
        }
        $x++;
    }
    return;
}


########################################

=head2 normal_mktime

  normal_mktime($year,$mon,$day,$hour,$min,$sec)

returns normalized timestamp for given date

=cut

sub normal_mktime {
    my($year,$mon,$day,$hour,$min,$sec) = @_;

    # calculate borrow
    my $add_time = 0;
    if($hour == 24) {
        $add_time = 86400;
        $hour = 0;
    }

    ($day, $hour, $min, $sec) = Normalize_DHMS($day, $hour, $min, $sec);
    my $timestamp = Mktime($year,$mon,$day, $hour,$min,$sec);
    $timestamp += $add_time;
    return $timestamp;
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

=head2 get_user_data

  get_user_data($c)

returns user data

=cut

sub get_user_data {
    my($c) = @_;

    if(!defined $c->stash->{'remote_user'} or $c->stash->{'remote_user'} eq '?') {
        return {};
    }

    my $file = $c->config->{'var_path'}."/users/".$c->stash->{'remote_user'};
    return {} unless -f $file;

    my $dump = read_file($file) or carp("cannot open file $file");
    my $VAR1 = {};

    ## no critic
    eval($dump);
    ## use critic

    carp("error in file $file: $@") if $@;

    return($VAR1);
}


########################################

=head2 store_user_data

  store_user_data($c, $data)

store user data for section

=cut

sub store_user_data {
    my($c, $data) = @_;

    if(!defined $c->stash->{'remote_user'} or $c->stash->{'remote_user'} eq '?') {
        return 1;
    }

    for my $dir ($c->config->{'var_path'}, $c->config->{'var_path'}."/users") {
        if(! -d $dir) {
            Thruk::Utils::IO::mkdir($dir) or do {
                Thruk::Utils::set_message( $c, 'fail_message', 'Saving Data failed: mkdir '.$dir.': '.$! );
                return;
            };
        }
    }

    my $file = $c->config->{'var_path'}."/users/".$c->stash->{'remote_user'};
    open(my $fh, '>', $file.'.new') or do {
        Thruk::Utils::set_message( $c, 'fail_message', 'Saving Data failed: open '.$file.'.new : '.$! );
        return;
    };
    print $fh Dumper($data);
    Thruk::Utils::IO::close($fh, $file.'.new');
    Thruk::Utils::IO::ensure_permissions('file', $file);

    move($file.'.new', $file) or do {
        Thruk::Utils::set_message( $c, 'fail_message', 'Saving Data failed: move '.$file.'.new '.$file.': '.$! );
        return;
    };

    return 1;
}


########################################

=head2 array_uniq

  array_uniq($array)

return uniq elements of array

=cut

sub array_uniq {
    my $array = shift;

    my %seen = ();
    my @unique = grep { ! $seen{ $_ }++ } @{$array};

    return \@unique;
}


########################################

=head2 logs2xls

  logs2xls($c)

save excel file by background job

=cut

sub logs2xls {
    my $c = shift;
    $c->stash->{'res_header'} = [ 'Content-Disposition', qq[attachment; filename="] . $c->stash->{'file_name'} . q["] ];
    $c->stash->{'res_ctype'}  = 'application/x-msexcel';
    Thruk::Utils::Status::set_selected_columns($c);
    $c->stash->{'data'} = $c->{'db'}->get_logs(%{$c->stash->{'log_filter'}});

    my $template = Excel::Template::Plus->new(
        engine   => 'TT',
        template => $c->stash->{'template'},
        config   => $c->config->{'View::TT'},
        params   => {},
    );
    $template->param(%{ $c->stash });
    if($c->config->{'no_external_job_forks'}) {
        my($fh, $filename) = tempfile();
        $c->stash->{'file_name'} = $filename;
        $c->stash->{job_dir}     = '';
        $c->stash->{cleanfile}   = 1;
    }
    $template->write_file($c->stash->{job_dir}.$c->stash->{'file_name'});
    return;
}

########################################

=head2 get_pnp_url

  get_pnp_url($c, $object)

return pnp url for object (host/service)

=cut

sub get_pnp_url {
    my $c     = shift;
    my $obj   = shift;
    my $force = shift;

    return '' unless $c->config->{'shown_inline_pnp'} || $force;

    for my $type (qw/action_url_expanded notes_url_expanded/) {
        for my $regex (qw/pnp4nagios pnp/) {
            if(defined $obj->{$type} and $obj->{$type} =~ m|(^.*?/$regex/)|mx) {
                return($1.'index.php');
            }
        }
    }

    return '';
}

########################################

=head2 expand_numeric_list

  expand_numeric_list($c, $txt)

return expanded list.
ex.: converts '3,7-9,15' -> [3,7,8,9,15]

=cut

sub expand_numeric_list {
    my $c    = shift;
    my $txt  = shift;
    my $list = {};
    return [] unless defined $txt;

    for my $item (ref $txt eq 'ARRAY' ? @{$txt} : $txt) {
        for my $block (split/\s*,\s*/mx, $item) {
            if($block =~ m/(\d+)\s*\-\s*(\d+)/gmx) {
                for my $nr ($1..$2) {
                    $list->{$nr} = 1;
                }
            } elsif($block =~ m/^(\d+)$/gmx) {
                    $list->{$1} = 1;
            } else {
                $c->log->error("'$block' is not a valid number or range");
            }
        }
    }

    my @arr = sort keys %{$list};
    return \@arr;
}

########################################

=head2 translate_host_status

  translate_host_status($status)

return name for status

=cut

sub translate_host_status {
    my $status = shift;
    return 'UP'          if $status == 0;
    return 'DOWN'        if $status == 1;
    return 'UNREACHABLE' if $status == 2;
    return 'UNKNOWN';
}


##############################################

=head2 choose_mobile

  choose_mobile($c, $url)

let the user choose a mobile page or not

=cut

sub choose_mobile {
    my($c,$url) = @_;

    return unless defined $c->{'request'}->{'headers'}->{'user-agent'};
    my $found = 0;
    for my $agent (split(/\s*,\s*/mx, $c->config->{'mobile_agent'})) {
        $found++ if $c->{'request'}->{'headers'}->{'user-agent'} =~ m/$agent/mx;
    }
    return unless $found;

    my $choose_mobile;
    if(defined $c->request->cookie('thruk_mobile')) {
        my $cookie = $c->request->cookie('thruk_mobile');
        $choose_mobile = $cookie->value;
        return if $choose_mobile == 0;
    }

    $c->{'canceled'}        = 1;
    $c->stash->{'title'}    = $c->config->{'name'};
    $c->stash->{'template'} = 'mobile_choose.tt';
    $c->stash->{'redirect'} = $url;
    if(defined $choose_mobile and $choose_mobile == 1) {
        return $c->response->redirect($c->stash->{'redirect'});
    }
    return 1;
}


##############################################

=head2 update_cron_file

  update_cron_file($c, $section, $entries)

write crontab section

=cut

sub update_cron_file {
    my($c, $section, $entries) = @_;

    if(!$c->config->{'cron_file'}) {
        set_message($c, 'fail_message', 'no \'cron_file\' set, check your settings!');
        return;
    }

    # prevents 'No child processes' error
    local $SIG{CHLD} = 'DEFAULT';

    my $errorlog = $c->config->{'var_path'}.'/cron.log';
    # ensure proper cron.log permission
    open(my $fh, '>>', $errorlog);
    Thruk::Utils::IO::close($fh, $errorlog);

    if($c->config->{'cron_pre_edit_cmd'}) {
        my $cmd = $c->config->{'cron_pre_edit_cmd'}." 2>>".$errorlog;
        my $output = `$cmd`;
        if ($? == -1) {
            die("cron_pre_edit_cmd (".$cmd.") failed: ".$!);
        } elsif ($? & 127) {
            die(sprintf("cron_pre_edit_cmd (".$cmd.") died with signal %d:\n", ($? & 127), $output));
        } else {
            my $rc = $? >> 8;
            die(sprintf("cron_pre_edit_cmd (".$cmd.") exited with value %d: %s\n", $rc, $output)) if $rc != 0;
        }
    }

    # read complete file
    my $sections = {};
    my @orig_cron;
    my $thruk_started = 0;
    if(-e $c->config->{'cron_file'}) {
        open(my $fh, '<', $c->config->{'cron_file'}) or die('cannot read '.$c->config->{'cron_file'}.': '.$!);
        my $lastsection;
        while(my $line = <$fh>) {
            chomp($line);
            $thruk_started = 1 if $line =~ m/^\#\ THIS\ PART\ IS\ WRITTEN\ BY\ THRUK/mx;
            unless($thruk_started) {
                push @orig_cron, $line;
                next;
            }
            $thruk_started = 0 if $line =~ m/^\#\ END\ OF\ THRUK/mx;

            if($line =~ m/^\#\ (\w+)$/mx) {
                $lastsection = $1;
                next;
            }
            next if $line =~ m/^\#/mx;
            next if $line =~ m/^\s*$/mx;
            next unless defined $lastsection;
            $sections->{$lastsection} = [] unless defined $sections->{$lastsection};
            push @{$sections->{$lastsection}}, $line;
        }
        Thruk::Utils::IO::close($fh, undef, 1);
    }

    # write out new file
    if(defined $section) {
        delete $sections->{$section};
        my $user = '';
        if(substr($c->config->{'cron_file'}, 0, 12) eq '/etc/cron.d/') {
            $user = ' root ';
        }
        $sections->{$section} = [];
        for my $entry (@{$entries}) {
            next unless defined $entry->[0];
            push @{$sections->{$section}}, $entry->[0]." ".$user.$entry->[1];
        }
    }

    open($fh, '>', $c->config->{'cron_file'}) or die('cannot write '.$c->config->{'cron_file'}.': '.$!);
    for my $line (@orig_cron) {
        print $fh $line, "\n";
    }

    if(defined $section) {
        my $header_printed = 0;
        for my $s (sort keys %{$sections}) {
            next if scalar @{$sections->{$s}} == 0;
            unless($header_printed) {
                print $fh "# THIS PART IS WRITTEN BY THRUK, CHANGES WILL BE OVERWRITTEN\n";
                print $fh "##############################################################\n";
                $header_printed = 1;
            }
            print $fh '# '.$s."\n";
            for my $line (@{$sections->{$s}}) {
                print $fh $line, "\n";
            }
        }
        if($header_printed) {
            print $fh "##############################################################\n";
            print $fh "# END OF THRUK\n";
        }
    }
    Thruk::Utils::IO::close($fh, $c->config->{'cron_file'});

    if($c->config->{'cron_post_edit_cmd'}) {
        my $cmd = $c->config->{'cron_post_edit_cmd'}." 2>>".$errorlog;
        my $output = `$cmd`;
        if ($? == -1) {
            die("cron_post_edit_cmd (".$cmd.") failed: ".$!);
        } elsif ($? & 127) {
            die(sprintf("cron_post_edit_cmd (".$cmd.") died with signal %d:\n", ($? & 127), $output));
        } else {
            my $rc = $? >> 8;
            die(sprintf("cron_post_edit_cmd (".$cmd.") exited with value %d: %s\n", $rc, $output)) if $rc != 0;
        }
    }
    return 1;
}

##############################################

=head2 get_cron_time_entry

  get_cron_time_entry($cronentry)

return time part of crontab entry

=cut

sub get_cron_time_entry {
    my($cr) = @_;
    my $cron;
    if($cr->{'type'} eq 'month') {
        $cron = sprintf("% 2s % 2s % 2s  *  *", $cr->{'minute'}, $cr->{'hour'}, $cr->{'day'});
    }
    elsif($cr->{'type'} eq 'week') {
        if(defined $cr->{'week_day'} and $cr->{'week_day'} ne '') {
            $cron = sprintf("% 2s % 2s  *  * % 2s", $cr->{'minute'}, $cr->{'hour'}, $cr->{'week_day'});
        }
    }
    elsif($cr->{'type'} eq 'day') {
        $cron = sprintf("% 2s % 2s  *  *  *", $cr->{'minute'}, $cr->{'hour'});
    } else {
        confess("unknown cron type: ".$cr->{'type'});
    }
    return $cron;
}

##############################################

=head2 get_user

  get_user($from_folder)

return user and groups thruk runs with

=cut

sub get_user {
    my($from_folder) = @_;
    confess($from_folder." ".$!) unless -d $from_folder;
    my $uid = (stat $from_folder)[4];
    my($name,$gid) = (getpwuid($uid))[0, 3];
    my @groups = ( $gid );
    while ( my ( $gid, $users ) = ( getgrent )[ 2, -1 ] ) {
        $users =~ /\b$name\b/mx and push @groups, $gid;
    }
    return($uid, \@groups);
}

##############################################

=head2 set_user

  set_user($c, $username)

set and authenticate a user

=cut

sub set_user {
    my($c, $username) = @_;
    $c->stash->{'remote_user'} = $username;
    $c->authenticate({});
    $c->stash->{'remote_user'}= $c->user->get('username');
    return;
}

##############################################

=head2 switch_user

  switch_user($uid, $groups)

switch real user and groups

=cut

sub switch_user {
    my($uid, $groups) = @_;
    $) = join(" ", @{$groups});
    # using POSIX::setuid here leads to
    # 'Insecure dependency in eval while running setgid'
    $> = $uid or confess("setuid failed: ".$!);
    return;
}

##############################################

=head2 get_cron_entries_from_param

  get_cron_entries_from_param($cronentry)

return array of cron entries from param

=cut

sub get_cron_entries_from_param {
    my($params) = @_;

    my $cron_entries = [];
    for my $x (1..99) {
        if(defined $params->{'send_type_'.$x}) {
            $params->{'week_day_'.$x} = [] unless defined $params->{'week_day_'.$x};
            my @weekdays = ref $params->{'week_day_'.$x} eq 'ARRAY' ? @{$params->{'week_day_'.$x}} : ($params->{'week_day_'.$x});
            @weekdays = grep {!/^$/mx} @weekdays;
            push @{$cron_entries}, {
                'type'      => $params->{'send_type_'.$x},
                'hour'      => $params->{'send_hour_'.$x},
                'minute'    => $params->{'send_minute_'.$x},
                'week_day'  => join(',', @weekdays),
                'day'       => $params->{'send_day_'.$x},
            };
        }
    }
    return $cron_entries;
}

##############################################

=head2 read_data_file

  read_data_file($filename)

return data for datafile

=cut

sub read_data_file {
    my($filename) = @_;

    my $cont = read_file($filename);
    my $data;
    ## no critic
    eval('$data = '.$cont.';');
    ## use critic

    return $data;
}

##############################################

=head2 write_data_file

  write_data_file($filename, $data)

write data to datafile

=cut

sub write_data_file {
    my($filename, $data) = @_;

    my $d = Dumper($data);
    $d    =~ s/^\$VAR1\ =\ //mx;
    $d    =~ s/^\ \ \ \ \ \ \ \ //gmx;
    open(my $fh, '>'.$filename) or confess('cannot write to '.$filename.": ".$!);
    print $fh $d;
    Thruk::Utils::IO::close($fh, $filename);

    return;
}
##############################################

=head2 get_git_name

  get_git_name()

write data to datafile

=cut

sub get_git_name {
    my $project_root = $INC{'Thruk/Utils.pm'};
    $project_root =~ s/\/Utils\.pm$//gmx;
    if(-d $project_root.'/../../.git') {
        my $branch = `cd $project_root && git branch --no-color 2> /dev/null | grep ^\*`;
        chomp($branch);
        $branch =~ s/^\*\s+//gmx;
        my $hash = `cd $project_root && git log -1 --no-color --pretty=format:%h 2> /dev/null`;
        chomp($hash);
        if($branch eq 'master') {
            return $hash;
        }
        return $branch.'.'.$hash;
    }
    return '';
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


##############################################
sub _parse_date {
    my $c      = shift;
    my $string = shift;
    my $timestamp;

    # just a timestamp?
    if($string =~ m/^(\d{9,12})$/mx) {
        $timestamp = $1;
    }

    # real date?
    elsif($string =~ m/(\d{4})\-(\d{2})\-(\d{2})\ (\d{2}):(\d{2}):(\d{2})/mx) {
        $timestamp = Mktime($1,$2,$3, $4,$5,$6);
    }

    # real date without seconds?
    elsif($string =~ m/(\d{4})\-(\d{2})\-(\d{2})\ (\d{2}):(\d{2})/mx) {
        $timestamp = Mktime($1,$2,$3, $4,$5,0);
    }

    # everything else
    else {
        $timestamp = UnixDate($string, '%s');
        $c->log->debug("not a valid date: ".$string);
        if(!defined $timestamp) {
            return;
        }
    }
    return $timestamp;
}

##########################################################
# return default recurring downtime
sub _get_default_recurring_downtime {
    my($c, $host, $service) = @_;
    my $default_rd = {
            host         => $host,
            service      => $service,
            backends     => $c->{'db'}->peer_key(),
            schedule     => [],
            duration     => 120,
            comment      => 'automatic downtime',
            childoptions => 0,
            fixed        => 1,
            flex_range   => 720,
    };
    return($default_rd);
}

##############################################

1;

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
