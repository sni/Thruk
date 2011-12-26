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
    my $timestamp = shift;
    my $format    = shift;
    my $tpd  = Template::Plugin::Date->new();
    my $date = $tpd->format($timestamp, $format);
    return decode("utf-8", $date);
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

    # is the contact allowed to send commands?
    my($can_submit_commands,$alias,$data);
    my $cache = $c->cache;
    my $cached_data = $cache->get($username);
    if(defined $cached_data->{'can_submit_commands'}) {
        # got cached data
        $data = $cached_data->{'can_submit_commands'};
    }
    else {
        $data = $c->{'db'}->get_can_submit_commands($username);
        $cached_data->{'can_submit_commands'} = $data;
        $cache->set($username, $cached_data);
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
    my $c       = shift;
    my $style   = shift;
    my $message = shift;
    my $details = shift;

    $c->res->cookies->{'thruk_message'} = {
        value => $style.'~~'.$message,
    };
    $c->stash->{'thruk_message'}         = $style.'~~'.$message;
    $c->stash->{'thruk_message_details'} = $details;

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
       close($ph);
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

compare too version strings

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
        next if !defined $v2[$x];
        my $cmp = 0;
        if($v2[$x] =~ m/^(\d+)/gmx) { $cmp = $1; }
        return 0 unless $v1[$x] <= $cmp;
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

  array2hash($data, $key)

create a hash by key

=cut
sub array2hash {
    my $data = shift;
    my $key  = shift;

    return {} unless defined $data;
    confess("not an array") unless ref $data eq 'ARRAY';

    my %hash;
    if(defined $key) {
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
        unless(defined $test->{'_'.$data->{'custom_variable_names'}->[$x]}) {
            $x++;
            next;
        }
        $c->stash->{'custom_vars'}->{$data->{'custom_variable_names'}->[$x]} = $data->{'custom_variable_values'}->[$x];
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

  get_user_data()

returns user data

=cut

sub get_user_data {
    my($c) = @_;

    return {} unless defined $c->stash->{'remote_user'};

    my $file = $c->config->{'var_path'}."/users/".$c->stash->{'remote_user'};
    return {} unless -f $file;

    my $dump = read_file($file) or carp("cannot open file $file: $!");
    my $VAR1 = {};

    ## no critic
    eval($dump);
    ## use critic

    carp("error in file $file: $@") if $@;

    return($VAR1);
}


########################################

=head2 store_user_data

  store_user_data($section, $data)

store user data for section

=cut

sub store_user_data {
    my($c, $data) = @_;

    for my $dir ($c->config->{'var_path'}, $c->config->{'var_path'}."/users") {
        if(! -d $dir) {
            mkdir($dir) or do {
                Thruk::Utils::set_message( $c, 'fail_message', 'Saving Bookmarks failed: mkdir '.$dir.': '.$! );
                return;
            };
            chmod 0770, $dir;
        }
    }

    my $file = $c->config->{'var_path'}."/users/".$c->stash->{'remote_user'};
    open(my $fh, '>', $file.'.new') or do {
        Thruk::Utils::set_message( $c, 'fail_message', 'Saving Bookmarks failed: open '.$file.'.new : '.$! );
        return;
    };
    print $fh Dumper($data);
    close($fh);

    move($file.'.new', $file) or do {
        Thruk::Utils::set_message( $c, 'fail_message', 'Saving Bookmarks failed: move '.$file.'.new '.$file.': '.$! );
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
    $template->write_file($c->stash->{job_dir}."/".$c->stash->{'file_name'});
    return 1;
}

########################################

=head2 get_pnp_url

  get_pnp_url($c, $object)

return pnp url for object (host/service)

=cut

sub get_pnp_url {
    my $c   = shift;
    my $obj = shift;

    return '' unless $c->config->{'shown_inline_pnp'};

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
    return unless $c->{'request'}->{'headers'}->{'user-agent'} =~ m/(iPhone|Android|)/mx;

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

    if($string =~ m/(\d{4})\-(\d{2})\-(\d{2})\ (\d{2}):(\d{2}):(\d{2})/mx) {
        $timestamp = Mktime($1,$2,$3, $4,$5,$6);
    }
    else {
        $timestamp = UnixDate($string, '%s');
        if(!defined $timestamp) {
            return;
        }
    }
    return $timestamp;
}



1;

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
