package Thruk::Utils;

=head1 NAME

Thruk::Utils - Utilities Collection for Thruk

=head1 DESCRIPTION

Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Carp qw/confess croak/;
use Data::Dumper qw/Dumper/;
use Date::Calc qw/Localtime Mktime Monday_of_Week Week_of_Year Today Normalize_DHMS/;
use File::Slurp qw/read_file/;
use Encode qw/encode encode_utf8 decode is_utf8/;
use File::Copy qw/move copy/;
use File::Temp qw/tempfile/;
use Time::HiRes qw/gettimeofday tv_interval/;
use Thruk::Utils::IO ();
use Digest::MD5 qw(md5_hex);
use POSIX ();

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
    confess("no format") unless defined $format;
    my $date = POSIX::strftime($format, localtime($timestamp));
    return decode("utf-8", $date);
}


##############################################

=head2 format_number

  my $string = format_number($number)

return number with thousands seperator

=cut
sub format_number {
    my($number) = @_;
    for ($number) {
        /\./mx
        ? s/(?<=\d)(?=(\d{3})+(?:\.))/,/gmx
        : s/(?<=\d)(?=(\d{3})+(?!\d))/,/gmx;
    }
    return $number;
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
            if(defined $lastconcated->[1]) {
                push @days, $lastconcated->[0].'-'.$lastconcated->[1];
            }
            elsif(defined $lastconcated->[0]) {
                push @days, $lastconcated->[0];
            }
            $cron = sprintf("%s at %02s:%02s", join(', ', @days), $cr->{'hour'}, $cr->{'minute'});
        } else {
            $cron = 'never';
        }
    }
    elsif($cr->{'type'} eq 'day') {
        $cron = sprintf("daily at %02s:%02s", $cr->{'hour'}, $cr->{'minute'});
    }
    elsif($cr->{'type'} eq 'monthday') {
        my $month_day = lcfirst $cr->{'month_day'};
        $month_day =~ s/_/ /gmx;
        $cron = sprintf("every %s at %02s:%02s", $month_day, $cr->{'hour'}, $cr->{'minute'});
    }
    elsif($cr->{'type'} eq 'cust') {
        my @tst = split/\s+/mx, $cr->{'cust'};
        if(scalar @tst == 5) {
            $cron = $cr->{'cust'};
        } else {
            $cron = '<font color="red" title="invalid cron syntax">'.$cr->{'cust'}.'</font>';
        }
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
    my($c, $config) = @_;
    if(defined $c) {
        $config = $c->config;
    }

    $c->stats->profile(begin => "Utils::read_cgi_cfg()") if defined $c;

    # read only if its changed
    my $file = $config->{'cgi.cfg'};
    if(!defined $file || $file eq '') {
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
       || $last_stat->[1] != $cgi_cfg_stat[1] # inode changed
       || $last_stat->[9] != $cgi_cfg_stat[9] # modify time changed
      ) {
        $c->log->info("cgi.cfg has changed, updating...") if defined $last_stat;
        $c->log->debug("reading $file") if defined $c;
        $config->{'cgi_cfg_stat'}      = \@cgi_cfg_stat;
        $config->{'cgi.cfg_effective'} = $file;
        $config->{'cgi_cfg'}           = Thruk::Config::read_config_file($file);
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
    my($pi, $selected) = @_;
    my $return = {};

    # if no backend is available
    return($return) if ref $pi ne 'HASH';

    for my $peer (@{$selected}) {
        for my $key (keys %{$pi->{$peer}}) {
            my $value = $pi->{$peer}->{$key};
            if(defined $value and ($value eq "0" or $value eq "1")) {
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
        if($c->config->{'first_day_of_week'} == 1) {
            $start = Mktime(@monday,  0,0,0);
        } else {
            $start = Mktime(@monday,  0,0,0) - 86400;
        }
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
        if($c->config->{'first_day_of_week'} == 1) {
            $end   = Mktime(@monday,  0,0,0);
        } else {
            $end   = Mktime(@monday,  0,0,0) - 86400;
        }
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
    elsif($timeperiod eq 'last12months' or $timeperiod eq 'last12month') {
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

    if(!defined $start || !defined $end) {
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
    my $timeperiod   = $c->req->parameters->{'timeperiod'};
    my $smon         = $c->req->parameters->{'smon'};
    my $sday         = $c->req->parameters->{'sday'};
    my $syear        = $c->req->parameters->{'syear'};
    my $shour        = $c->req->parameters->{'shour'}  || 0;
    my $smin         = $c->req->parameters->{'smin'}   || 0;
    my $ssec         = $c->req->parameters->{'ssec'}   || 0;
    my $emon         = $c->req->parameters->{'emon'};
    my $eday         = $c->req->parameters->{'eday'};
    my $eyear        = $c->req->parameters->{'eyear'};
    my $ehour        = $c->req->parameters->{'ehour'}  || 0;
    my $emin         = $c->req->parameters->{'emin'}   || 0;
    my $esec         = $c->req->parameters->{'esec'}   || 0;
    my $t1           = $c->req->parameters->{'t1'};
    my $t2           = $c->req->parameters->{'t2'};

    $timeperiod = 'last24hours' if(!defined $timeperiod && !defined $t1 && !defined $t2);
    return Thruk::Utils::get_start_end_for_timeperiod($c, $timeperiod,$smon,$sday,$syear,$shour,$smin,$ssec,$emon,$eday,$eyear,$ehour,$emin,$esec,$t1,$t2);
}

########################################

=head2 get_dynamic_roles

  get_dynamic_roles($c, $user)

gets the authorized_for_read_only role and group based roles

=cut
sub get_dynamic_roles {
    my($c, $username, $user) = @_;

    $user = Thruk::Authentication::User->new($c, $username) if $username;
    $user = $c->user unless defined $user;

    # is the contact allowed to send commands?
    my($can_submit_commands,$alias,$data);
    my $cached_data = defined $username ? $c->cache->get->{'users'}->{$username} : {};
    if(defined $cached_data->{'can_submit_commands'}) {
        # got cached data
        $data = $cached_data->{'can_submit_commands'};
    }
    else {
        $data = $c->{'db'}->get_can_submit_commands($username);
        $cached_data->{'can_submit_commands'} = $data;
        $c->cache->set('users', $username, $cached_data) if defined $username;
    }

    if(defined $data) {
        for my $dat (@{$data}) {
            $alias               = $dat->{'alias'}               if defined $dat->{'alias'};
            $can_submit_commands = $dat->{'can_submit_commands'} if defined $dat->{'can_submit_commands'};
        }
    }

    if(!defined $can_submit_commands) {
        $can_submit_commands = Thruk->config->{'can_submit_commands'} || 0;
    }

    # set initial roles from user
    my $roles = [];
    for my $r (@{$user->{'roles'}}) {
        push @{$roles}, $r;
    }

    # override can_submit_commands from cgi.cfg
    if(grep /authorized_for_all_host_commands/mx, @{$roles}) {
        $can_submit_commands = 1;
    }
    elsif(grep /authorized_for_all_service_commands/mx, @{$roles}) {
        $can_submit_commands = 1;
    }
    elsif(grep /authorized_for_system_commands/mx, @{$roles}) {
        $can_submit_commands = 1;
    }

    $c->log->debug("can_submit_commands: $can_submit_commands");
    if($can_submit_commands != 1) {
        push @{$roles}, 'authorized_for_read_only';
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
    my $roles_by_group = {};
    for my $key (keys %{$possible_roles}) {
        my $role = $possible_roles->{$key};
        if(defined $c->config->{'cgi_cfg'}->{$key}) {
            my %contactgroups = map { $_ => 1 } split/\s*,\s*/mx, $c->config->{'cgi_cfg'}->{$key};
            for my $contactgroup (keys %contactgroups) {
                if(defined $groups->{$contactgroup} or $contactgroup eq '*' ) {
                    $roles_by_group->{$role} = [] unless defined $roles_by_group->{$role};
                    push @{$roles_by_group->{$role}}, $contactgroup;
                    push @{$roles}, $role;
                }
            }
        }
    }

    # roles could be duplicated
    $roles = array_uniq($roles);

    return($roles, $can_submit_commands, $alias, $roles_by_group);
}

########################################

=head2 set_dynamic_roles

  set_dynamic_roles($c)

sets the authorized_for_read_only role and group based roles

=cut
sub set_dynamic_roles {
    my $c = shift;

    return unless $c->user_exists;
    my $username = $c->user->{'username'};
    return unless defined $username;

    $c->stats->profile(begin => "Thruk::Utils::set_dynamic_roles");

    #my($roles, $can_submit_commands, $alias)...
    my($roles, undef, $alias) = get_dynamic_roles($c, $username, $c->user);

    if(defined $alias) {
        $c->user->{'alias'} = $alias;
    }

    for my $role (@{$roles}) {
        push @{$c->user->{'roles'}}, $role;
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

    $c->cookie('thruk_message' => $style.'~~'.$message, { path  => $c->stash->{'cookie_path'} });
    $c->stash->{'thruk_message'}         = $style.'~~'.$message;
    $c->stash->{'thruk_message_details'} = $details;
    $c->res->code($code) if defined $code;

    return 1;
}


########################################

=head2 append_message

  append_message($text)

append text to current message

=cut
sub append_message {
    my($c, $txt) = @_;
    if(defined $c->res->cookies->{'thruk_message'}) {
        $c->res->cookies->{'thruk_message'}->{'value'} .= ' '.$txt;
    }
    if(defined $c->stash->{'thruk_message'}) {
        $c->stash->{'thruk_message'} .= ' '.$txt;
    }
    return 1;
}


########################################

=head2 ssi_include

  ssi_include($c)

puts the ssi templates into the stash

=cut
sub ssi_include {
    my($c, $page) = @_;
    $page = $c->stash->{'page'} unless defined $page;
    my $global_header_file = "common-header.ssi";
    my $header_file        = $page."-header.ssi";
    my $global_footer_file = "common-footer.ssi";
    my $footer_file        = $page."-footer.ssi";

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
    # retun if file is executable
    if( -x $c->config->{'ssi_path'}."/".$file ){
       open(my $ph, '-|', $c->config->{'ssi_path'}."/".$file.' 2>&1') or carp("cannot execute ssi: $!");
       my $output = '';
       while(my $line = <$ph>) { $output .= $line; }
       CORE::close($ph);
       return $output;
    }
    elsif( -r $c->config->{'ssi_path'}."/".$file ){
        return(read_file($c->config->{'ssi_path'}."/".$file) || carp("cannot open ssi: $!"));
    }
    $c->log->warn($c->config->{'ssi_path'}."/".$file." is no longer accessible, please restart thruk to initialize ssi information");
    return "";
}

########################################

=head2 read_resource_file

  read_resource_file($file, [ $macros ], [$with_comments])

returns a hash with all USER1-32 macros. macros can
be a predefined hash.

=cut

sub read_resource_file {
    my($file, $macros, $with_comments) = @_;
    my $comments    = {};
    my $lastcomment = "";
    return unless defined $file;
    return unless -f $file;
    $macros   = {} unless defined $macros;
    open(my $fh, '<', $file) or die("cannot read file ".$file.": ".$!);
    while(my $line = <$fh>) {
        if($line =~ m/^\s*(\$[A-Z0-9]+\$)\s*=\s*(.*)$/mx) {
            $macros->{$1}   = $2;
            $comments->{$1} = $lastcomment;
            $lastcomment    = "";
        }
        elsif($line =~ m/^(\#.*$)/mx) {
            $lastcomment .= $1;
        }
        elsif($line =~ m/^\s*$/mx) {
            $lastcomment = '';
        }
    }
    CORE::close($fh) or die("cannot close file ".$file.": ".$!);
    return($macros) unless $with_comments;
    return($macros, $comments);
}


########################################

=head2 version_compare

  version_compare($version1, $version2)

compare too version strings and return 1 if v1 >= v2

=cut
sub version_compare {
    my($v1,$v2) = @_;
    confess("version_compare() needs two params") unless defined $v2;

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

    if(!defined $operator && $operator ne '-or' && $operator ne '-and') {
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
}


########################################

=head2 array2hash

  array2hash($data, [ $key, [ $key2 ]])

create a hash by key

=cut
sub array2hash {
    my($data, $key, $key2) = @_;

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

=head2 get_custom_vars

  get_custom_vars($c, $obj, [$prefix])

return custom variables in a hash

=cut
sub get_custom_vars {
    my($c, $data,$prefix) = @_;
    $prefix = '' unless defined $prefix;

    my %hash;

    if(   defined $data
      and defined $data->{$prefix.'custom_variable_names'}
      and defined $data->{$prefix.'custom_variable_values'})
    {
        # merge custom variables into a hash
        @hash{@{$data->{$prefix.'custom_variable_names'}}} = @{$data->{$prefix.'custom_variable_values'}};
    }

    # add action menu from apply rules
    if($c && $c->config->{'action_menu_apply'} && !$hash{'THRUK_ACTION_MENU'}) {
        APPLY:
        for my $menu (keys %{$c->config->{'action_menu_apply'}}) {
            for my $pattern (ref $c->config->{'action_menu_apply'}->{$menu} eq 'ARRAY' ? @{$c->config->{'action_menu_apply'}->{$menu}} : ($c->config->{'action_menu_apply'}->{$menu})) {
                if(!$prefix && $data->{'description'}) {
                    my $test = $data->{'host_name'}.';'.$data->{'description'};
                    ## no critic
                    if($test =~ m/$pattern/) {
                    ## use critic
                        $hash{'THRUK_ACTION_MENU'} = $menu;
                        last APPLY;
                    }
                }
                elsif($data->{$prefix.'name'}) {
                    my $test = $data->{$prefix.'name'}.';';
                    ## no critic
                    if($test =~ m/$pattern/) {
                    ## use critic
                        $hash{'THRUK_ACTION_MENU'} = $menu;
                        last APPLY;
                    }
                }
            }
        }
    }

    return \%hash;
}


########################################

=head2 set_custom_vars

  set_custom_vars($c)

set stash value for all allowed custom variables

=cut
sub set_custom_vars {
    my $c      = shift;
    my $args   = shift;

    my $prefix  = $args->{'prefix'} || '';
    my $search  = $args->{'search'} || 'show_custom_vars';
    my $dest    = $args->{'dest'}   || 'custom_vars';
    my $host    = $args->{'host'};
    my $service = $args->{'service'};
    my $data;

    if (defined $host and defined $service) {
        $data = $service;
    } elsif (defined $host) {
        $data = $host;
    } else {
        return;
    }

    $c->stash->{$dest} = [];

    return unless defined $data;
    return unless defined $data->{$prefix.'custom_variable_names'};
    return unless defined $c->config->{$search};

    my $vars = ref $c->config->{$search} eq 'ARRAY' ? $c->config->{$search} : [ $c->config->{$search} ];

    my $custom_vars = get_custom_vars($c, $data, $prefix);

    my $already_added = {};
    for my $test (@{$vars}) {
        for my $cust_name (keys %{$custom_vars}) {
            next if defined $already_added->{$cust_name};
            my $cust_value = $custom_vars->{$cust_name};
            my $found      = 0;
            if($test eq $cust_name or $test eq '_'.$cust_name) {
                $found = 1;
            } else {
                my $v = "".$test;
                next if CORE::index($v, '*') == -1;
                $v =~ s/\*/.*/gmx;
                if($cust_name =~ m/^$v$/mx or ('_'.$cust_name) =~ m/^$v$/mx) {
                    $found = 1;
                }
            }
            if($found) {
                # expand macros in custom vars
                if (defined $host and defined $service) {
                        #($cust_value, $rc)...
                        ($cust_value, undef) = $c->{'db'}->_replace_macros({
                            string  => $cust_value,
                            host    => $host,
                            service => $service,
                        });
                } elsif (defined $host) {
                        #($cust_value, $rc)...
                        ($cust_value, undef) = $c->{'db'}->_replace_macros({
                            string  => $cust_value,
                            host    => $host,
                        });
                }

                # add to dest
                push @{$c->stash->{$dest}}, [ $cust_name, $cust_value ];
            }
        }
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

    return $c->stash->{'user_data_cached'} if $c->stash->{'user_data_cached'};

    if(!defined $c->stash->{'remote_user'} || $c->stash->{'remote_user'} eq '?') {
        return {};
    }

    my $file = $c->config->{'var_path'}."/users/".$c->stash->{'remote_user'};
    if(-s $file) {
        $c->stash->{'user_data_cached'} = read_data_file($file);
    } else {
        $c->stash->{'user_data_cached'} = {};
    }
    return $c->stash->{'user_data_cached'};
}


########################################

=head2 store_user_data

  store_user_data($c, $data)

store user data for section

=cut

sub store_user_data {
    my($c, $data) = @_;

    # don't store in demo mode
    if($c->config->{'demo_mode'}) {
        Thruk::Utils::set_message( $c, 'fail_message', 'saving user settings is disabled in demo mode');
        return;
    }

    if(!defined $c->stash->{'remote_user'} || $c->stash->{'remote_user'} eq '?') {
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

    # update cached data
    $c->stash->{'user_data_cached'} = $data;

    my $file = $c->config->{'var_path'}."/users/".$c->stash->{'remote_user'};
    my $rc;
    eval {
        $rc = write_data_file($file, $data);
    };
    if($@ || !$rc) {
        Thruk::Utils::set_message( $c, 'fail_message', 'Saving Data failed: '.$file.' '.$@ );
        return;
    }

    return 1;
}


########################################

=head2 get_global_user_data

  get_global_user_data($c)

returns global user data

=cut

sub get_global_user_data {
    my($c) = @_;

    my $file = $c->config->{'var_path'}."/global_user_data";
    return {} unless -s $file;
    return read_data_file($file);
}


########################################

=head2 store_global_user_data

  store_global_user_data($c, $data)

store global user data for section

=cut

sub store_global_user_data {
    my($c, $data) = @_;

    # don't store in demo mode
    if($c->config->{'demo_mode'}) {
        Thruk::Utils::set_message( $c, 'fail_message', 'saving global settings disabled in demo mode');
        return;
    }

    my $dir = $c->config->{'var_path'};
    if(! -d $dir) {
        Thruk::Utils::IO::mkdir($dir) or do {
            Thruk::Utils::set_message( $c, 'fail_message', 'Saving Data failed: mkdir '.$dir.': '.$! );
            return;
        };
    }

    my $file = $c->config->{'var_path'}."/global_user_data";
    my $rc;
    eval {
        $rc = write_data_file($file, $data);
    };
    if($@ || !$rc) {
        Thruk::Utils::set_message( $c, 'fail_message', 'Saving Data failed: '.$file.' '.$@ );
        return;
    }
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
    my($c) = @_;
    Thruk::Utils::Status::set_selected_columns($c);
    $c->stash->{'data'} = $c->{'db'}->get_logs(%{$c->stash->{'log_filter'}});
    savexls($c);
    return;
}

########################################

=head2 savexls

  savexls($c)

save excel file by background job

=cut

sub savexls {
    my($c) = @_;
    $c->stash->{'res_header'} = [ 'Content-Disposition', qq[attachment; filename="] .  $c->stash->{'file_name'} . q["] ];
    $c->stash->{'res_ctype'}  = 'application/x-msexcel';

    my $template = $c->stash->{'template'};
    require Thruk::Views::ExcelRenderer;
    my $output = Thruk::Views::ExcelRenderer::render($c, $template);
    if($c->config->{'no_external_job_forks'}) {
        #my($fh, $filename)...
        my(undef, $filename)     = tempfile();
        $c->stash->{'file_name'} = $filename;
        $c->stash->{job_dir}     = '';
        $c->stash->{cleanfile}   = 1;
    }
    Thruk::Utils::IO::write($c->stash->{job_dir}.$c->stash->{'file_name'}, $output);
    return;
}

########################################

=head2 get_pnp_url

  get_pnp_url($c, $object)

return pnp url for object (host/service)

=cut

sub get_pnp_url {
    my($c, $obj, $force) = @_;

    return '' unless $c->config->{'shown_inline_pnp'} || $force;

    for my $type (qw/action_url_expanded notes_url_expanded/) {
        next unless defined $obj->{$type};
        for my $regex (qw|/pnp[^/]*/|) {
            return($1.'/index.php') if $obj->{$type} =~ m|(^.*?$regex)|mx;
        }
    }

    return '';
}

########################################

=head2 get_graph_url

  get_graph_url($c, $object)

return graph url for object (host/service)

=cut

sub get_graph_url {
    my($c, $obj, $force) = @_;

    my $graph_word = $c->config->{'graph_word'};
    my $action_url = '';

    if ($graph_word && ($c->config->{'shown_inline_pnp'} || $force)) {
        for my $type (qw/action_url_expanded notes_url_expanded/) {
            next unless defined $obj->{$type};
            for my $regex (@{list($graph_word)}) {
                if ($obj->{$type} =~ m|$regex|mx){
                    $action_url = $obj->{$type};
                    last;
                }
            }
        }
    }

    if(defined $obj->{'name'}) {
        #host obj
        return get_action_url($c, 1, 0, $action_url, $obj->{'name'});
    }
    elsif(defined $obj->{'host_name'} && defined $obj->{'description'}) {
        #service obj
        return get_action_url($c, 1, 0, $action_url, $obj->{'host_name'}, $obj->{'description'});
    }
    else {
        #unknown host
        return '';
    }
}


########################################

=head2 get_action_url

  get_action_url($c, $escape_fun, $remove_render, $action_url, $host, $svc)

return action_url modified for object (host/service) if we use graphite
escape_fun is use to escape special char (html or quotes)
remove_render remove /render in action url

=cut

sub get_action_url {
    my($c, $escape_fun, $remove_render, $action_url, $host, $svc) = @_;

    my $new_action_url = $action_url;
    my $graph_word = $c->config->{'graph_word'};

    # don't escape pnp links, they often contain quotes on purpose
    if($action_url =~ m/\/pnp(|4nagios)\//mx) {
        # add theme
        if($action_url !~ m/theme=/mx) {
            $action_url =~ s/(index.php.*?)'/$1&theme=smoothness'/mx;
        }
        $action_url =~ s/&amp;/&/gmx;
        $action_url =~ s/&/&amp;/gmx;
        return($action_url);
    }

    if ($graph_word) {
        for my $regex (@{list($graph_word)}) {
            if ($action_url =~ m|$regex|mx){
                my $new_host = $host;
                $new_host =~ s/[^\w\-]/_/gmx;
                $new_action_url =~ s/\Q$host\E/$new_host/gmx;

                if ($svc) {
                    my $new_svc = $svc;
                    $new_svc =~ s/[^\w\-]/_/gmx;
                    $new_action_url =~ s/\Q$svc\E/$new_svc/gmx;
                }

                last;
            }
        }
    }

    if ($escape_fun == 2) {
        $new_action_url = Thruk::Utils::Filter::escape_html($new_action_url);
    }
    elsif($escape_fun == 1) {
        $new_action_url = Thruk::Utils::Filter::escape_quotes($new_action_url);
    }

    if ($remove_render != 0) {
        $new_action_url =~ s|/render||gmx;
    }

    return $new_action_url;
}


########################################

=head2 list

  list($ref)

return list of ref unless it is already a list

=cut

sub list {
    my($d) = @_;
    return [] unless defined $d;
    return $d if ref $d eq 'ARRAY';
    return([$d]);
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

    return unless defined $c->req->header('user-agent');
    my $found = 0;
    for my $agent (split(/\s*,\s*/mx, $c->config->{'mobile_agent'})) {
        $found++ if $c->req->header('user-agent') =~ m/$agent/mx;
    }
    return unless $found;

    my $choose_mobile;
    if(defined $c->cookie('thruk_mobile')) {
        my $cookie = $c->cookie('thruk_mobile');
        $choose_mobile = $cookie->value;
        return if $choose_mobile == 0;
    }

    $c->stash->{'title'}     = $c->config->{'name'};
    $c->stash->{'template'} = 'mobile_choose.tt';
    $c->stash->{'redirect'}  = $url;
    if(defined $choose_mobile and $choose_mobile == 1) {
        return $c->redirect_to($c->stash->{'redirect'});
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

    if($c->config->{'cron_pre_edit_cmd'}) {
        my($fh2, $tmperror) = tempfile();
        Thruk::Utils::IO::close($fh2, $tmperror);
        my $cmd = $c->config->{'cron_pre_edit_cmd'}." 2>>".$tmperror;
        my $output = `$cmd`;
        my $rc     = $?;
        my $errors = read_file($tmperror);
        unlink($tmperror);
        print $fh $errors;
        if ($rc == -1) {
            die("cron_pre_edit_cmd (".$cmd.") failed: ".$!);
        } elsif ($rc & 127) {
            die(sprintf("cron_pre_edit_cmd (%s) died with signal %d: %s\n%s\n", $cmd, ($rc & 127), $output, $errors));
        } else {
            $rc = $rc >> 8;
            # override know error with initial crontab
            if($rc != 1 or $errors !~ m/no\ crontab\ for/mx) {
                die(sprintf("cron_pre_edit_cmd (".$cmd.") exited with value %d: %s\n%s\n", $rc, $output, $errors)) if $rc != 0;
            }
        }
    }
    Thruk::Utils::IO::close($fh, $errorlog);

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

            if($line =~ m/^\#\ ([\w\s]+)$/mx) {
                $lastsection = $1;
                next;
            }
            next if $line =~ m/^\#/mx;
            next if $line =~ m/^\s*$/mx;
            next unless defined $lastsection;
            $sections->{$lastsection} = [] unless defined $sections->{$lastsection};
            push @{$sections->{$lastsection}}, $line;
        }
        CORE::close($fh) or die("cannot close file ".$c->config->{'cron_file'}.": ".$!);
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
            next unless $entry->[0];
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
    }
    elsif($cr->{'type'} eq 'monthday') {
        my($t, $d) = split(/_/mx, $cr->{'month_day'}, 2);
        my $weeks;
        $weeks = 1 if $t eq '1st';
        $weeks = 2 if $t eq '2nd';
        $weeks = 3 if $t eq '3rd';
        $weeks = 4 if $t eq '4th';
        $weeks = 1 if $t eq 'Last';
        my $daycheck = '[ $(date +"\%m") -ne $(date -d "-'.(7*$weeks).'days" +"\%m") ] && ';
        if($t eq 'Last') {
            $daycheck = '[ $(date +"\%m") -ne $(date -d "'.(7*$weeks).'days" +"\%m") ] && ';
        }
        my $day;
        $day = 1 if $d eq 'Monday';
        $day = 2 if $d eq 'Tuesday';
        $day = 3 if $d eq 'Wednesday';
        $day = 4 if $d eq 'Thursday';
        $day = 5 if $d eq 'Friday';
        $day = 6 if $d eq 'Saturday';
        $day = 0 if $d eq 'Sunday';
        $cron = sprintf("% 2s % 2s *  *  % 2s %s", $cr->{'minute'}, $cr->{'hour'}, $day, $daycheck);
    }
    elsif($cr->{'type'} eq 'cust') {
        my @tst = split/\s+/mx, $cr->{'cust'};
        if(scalar @tst == 5) {
            $cron = $cr->{'cust'};
        }
    } else {
        confess("unknown cron type: ".$cr->{'type'});
    }
    return $cron;
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
    set_dynamic_roles($c);
    return;
}


##############################################

=head2 switch_realuser

  switch_realuser($uid, $groups)

switch real user and groups

=cut

sub switch_realuser {
    ## no critic
    if($< != $>) {
        $< = $> or confess("setuid failed: ".$!);
    }
    if($) != $() {
        $( = $) or confess("setgid failed: ".$!);
    }
    ## use critic
    return;
}

##############################################

=head2 check_pid_file

  check_pid_file($c)

check and write pid file if none exists

=cut

sub check_pid_file {
    my($c) = @_;
    my $pidfile  = $c->config->{'tmp_path'}.'/thruk.pid';
    if(defined $ENV{'THRUK_SRC'} && $ENV{'THRUK_SRC'} eq 'FastCGI' && ! -f $pidfile) {
        open(my $fh, '>', $pidfile) || warn("cannot write $pidfile: $!");
        print $fh $$."\n";
        Thruk::Utils::IO::close($fh, $pidfile);
    }
    return;
}

##############################################

=head2 restart_later

  restart_later($c, $redirect_url)

restart fcgi process and redirects to given page

=cut

sub restart_later {
    my($c, $redirect) = @_;
    if(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'FastCGI') {
        my $pidfile  = $c->config->{'tmp_path'}.'/thruk.pid';
        if(-f $pidfile) {
            my $pids = [split(/\s/mx, read_file($pidfile))];
            for my $pid (@{$pids}) {
                next unless($pid and $pid =~ m/^\d+$/mx);
                system("sleep 1 && kill -HUP $pid &");
            }
        } else {
            my $pid = $$;
            system("sleep 1 && kill -HUP $pid &");
        }
        Thruk::Utils::append_message($c, ' Thruk has been restarted.');
        return $c->redirect_to($c->stash->{'url_prefix'}.'startup.html?wait#'.$redirect);
    } else {
        Thruk::Utils::append_message($c, ' Changes take effect after Restart.');
        return $c->redirect_to($redirect);
    }
    return;
}


##############################################

=head2 wait_after_reload

  wait_after_reload($c, [$backend], [$timestamp])

wait up to 60 seconds till the core responds

=cut

sub wait_after_reload {
    my($c, $pkey, $time) = @_;
    $pkey = $c->stash->{'param_backend'} unless $pkey;
    if(!$pkey && !$time) { sleep 5; }

    # wait until core responds again
    my $start    = time();
    my $procinfo = {};
    my $done     = 0;
    while($start > time() - 60) {
        $procinfo = {};
        eval {
            local $SIG{ALRM}   = sub { die "alarm\n" };
            local $SIG{'PIPE'} = sub { die "pipe error\n" };
            alarm(10);
            $c->{'db'}->reset_failed_backends();
            $procinfo = $c->{'db'}->get_processinfo(backend => $pkey);
        };
        alarm(0);
        if($@) {
            $c->log->debug('still waiting for core reload for '.(time()-$start).'s: '.$@);
        }
        elsif($pkey && $c->stash->{'failed_backends'}->{$pkey}) {
            $c->log->debug('still waiting for core reload for '.(time()-$start).'s: '.$c->stash->{'failed_backends'}->{$pkey});
        }
        elsif($pkey and $time) {
            # not yet restarted
            if($procinfo and $procinfo->{$pkey} and $procinfo->{$pkey}->{'program_start'} and $procinfo->{$pkey}->{'program_start'} < $time) {
                $c->log->debug('still waiting for core reload for '.(time()-$start).'s, last restart: '.(scalar localtime($procinfo->{$pkey}->{'program_start'})));
            } else {
                $done = 1;
                last;
            }
        }
        elsif($time) {
            my $newest_core = 0;
            if($procinfo) {
                for my $key (keys %{$procinfo}) {
                    if($procinfo->{$key}->{'program_start'} > $newest_core) { $newest_core = $procinfo->{$key}->{'program_start'}; }
                }
                if($newest_core > $time) {
                    $done = 1;
                    last;
                } else {
                    $c->log->debug('still waiting for core reload for '.(time()-$start).'s, last restart: '.(scalar localtime($newest_core)));
                }
            }
        } else {
            $done = 1;
            last;
        }
        sleep(1);
    }
    if(!$done) {
        $c->log->error('waiting for core reload failed');
    }
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
            my $type = $params->{'send_type_'.$x} || '';
            my $cust = $params->{'send_cust_'.$x} || '';
            push @{$cron_entries}, {
                'type'      => $type,
                'hour'      => defined $params->{'send_hour_'.$x}     ? $params->{'send_hour_'.$x}     : '',
                'minute'    => defined $params->{'send_minute_'.$x}   ? $params->{'send_minute_'.$x}   : '',
                'week_day'  => join(',', @weekdays),
                'day'       => defined $params->{'send_day_'.$x}      ? $params->{'send_day_'.$x}      : '',
                'month_day' => defined $params->{'send_monthday_'.$x} ? $params->{'send_monthday_'.$x} : '',
                'cust'      => $cust,
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

    # just wrap the json writer and keep the rest to read old data files
    my $res;
    eval {
        $res = Thruk::Utils::IO::json_lock_retrieve($filename);
    };
    if(!$@ && $res) {
        return($res);
    }

    # REMOVE AFTER: 01.01.2018
    my $cont = read_file($filename);
    if($cont =~ /\A(.*)\z/msx) { $cont = $1; } # make it untainted

    # ensure right encoding
    decode_any($cont);

    $cont =~ s/^\$VAR1\ =\ //mx;

    # replace broken escape sequences
    $cont =~ s/\\x\{[\w]{5,}\}/\x{fffd}/gmxi;

    my $VAR1;
    ## no critic
    eval('$VAR1 = '.$cont.';');
    ## use critic

    warn($@) if $@;

    return $VAR1;
}

##############################################

=head2 write_data_file

  write_data_file($filename, $data, [$changed_only])

write data to datafile

=cut

sub write_data_file {
    my($filename, $data, $changed_only) = @_;

    # store new data files in json format
    return(Thruk::Utils::IO::json_lock_store($filename, $data, 1, $changed_only));
}

##############################################

=head2 backup_data_file

  backup_data_file($filename, $mode, $max_backups, [$save_interval], [$force])

write data to datafile

=cut

sub backup_data_file {
    my($filename, $mode, $max_backups, $save_interval, $force) = @_;

    my @backups     = sort glob($filename.'.*.'.$mode);
    @backups        = grep(!/\.runtime$/mx, @backups);
    my $num         = scalar @backups;
    my $last_backup = $backups[$num-1];
    my $now         = time();

    if($save_interval && $last_backup && $last_backup =~ m/\.(\d+)\.\w$/mx) {
        my $ts = $1;
        if($save_interval > $now - $ts) {
            return;
        }
    }

    my $old_md5 = $last_backup ? md5_hex(read_file($last_backup)) : '';
    my $new_md5 = md5_hex(read_file($filename));
    if($force || $new_md5 ne $old_md5) {
        copy($filename, $filename.'.'.$now.'.'.$mode);

        # cleanup old backups
        while($num > $max_backups) {
            unlink(shift(@backups));
            $num--;
        }
    }

    return;
}

##########################################################

=head2 decode_any

read and decode string from either utf-8 or iso-8859-1

=cut
sub decode_any {
    eval { $_[0] = decode( "utf8", $_[0], Encode::FB_CROAK ) };
    if($@) { # input was not utf8
        return($_[0]) if $@ =~ m/\QCannot decode string with wide characters\E/mxo; # since Encode.pm 2.53 decode_utf8 no longer noops when utf8 is already on
        $_[0] = decode( "iso-8859-1", $_[0], Encode::FB_WARN );
    }
    return $_[0];
}

########################################

=head2 ensure_utf8

    ensure_utf8($str)

makes sure the given string is utf8

=cut
sub ensure_utf8 {
    $_[0] = decode_any($_[0]);
    return($_[0]) if is_utf8($_[0]); # since Encode.pm 2.53 decode_utf8 no longer noops when utf8 is already on
    return(encode_utf8($_[0]));
}

########################################

=head2 which

    which($prog)

returns path to program or undef

=cut
sub which {
    my($prog) = @_;
    my $path = `which $prog 2>/dev/null`;
    return unless $path;
    chomp($path);
    return($path);
}

########################################

=head2 reduce_number

  reduce_number($number, $unit, [$divisor])

return reduced number, ex 1024B -> 1KB

=cut

sub reduce_number {
    my($number, $unit, $divisor) = @_;
    $divisor = 1000 unless defined $divisor;
    my $unitprefix = '';

    my $divs = [
        [ 'T', 4 ],
        [ 'G', 3 ],
        [ 'M', 2 ],
        [ 'K', 1 ],
    ];
    for my $div (@{$divs}) {
        my $pow   = $div->[1];
        my $limit = $divisor ** $pow;
        if($number > $limit) {
            $unitprefix = $div->[0];
            $number     = $number / $limit;
            last;
        }
    }
    return($number, $unitprefix.$unit);
}

########################################

=head2 get_template_variable

  get_template_variable($c, $template, $variable)

return variable defined from template

=cut

sub get_template_variable {
    my($c, $template, $var, $stash, $noerror) = @_;

    # more stash variables to set?
    $stash = {} unless defined $stash;
    for my $key (keys %{$stash}) {
        $c->stash->{$key} = $stash->{$key};
    }

    $c->stash->{'temp'}  = $template;
    $c->stash->{'var'}   = $var;
    my $data;
    eval {
        Thruk::Views::ToolkitRenderer::render($c, 'get_variable.tt', undef, \$data);
    };
    if($@) {
        return "" if $noerror;
        Thruk::Utils::CLI::_error($@);
        return $c->detach('/error/index/13');
    }

    my $VAR1;
    ## no critic
    eval($data);
    ## use critic
    return $VAR1;
}

##############################################

=head2 precompile_templates

  precompile_templates($c)

precompile and load templates into memory

=cut

sub precompile_templates {
    my($c) = @_;
    return if $c->config->{'precompile_templates'} == 2;
    my $t0 = [gettimeofday];
    my @includes;
    push @includes, @{$c->config->{templates_paths}} if $c->config->{templates_paths};
    push @includes, $c->config->{'View::TT'}->{'INCLUDE_PATH'} if $c->config->{'View::TT'}->{'INCLUDE_PATH'};
    my $uniq     = {};
    for my $path (@includes) {
        next unless -d $path;
        my $files = find_files($path, '\.tt$');
        for my $file (@{$files}) {
            $file =~ s|^$path/||gmx;
            $uniq->{$file} = 1;
        }
    }

    # no backends required
    $c->{'db'}->disable_backends() if $c->{'db'};

    my $stderr_output;
    # First, save away STDERR
    open my $savestderr, ">&STDERR";
    eval {
        # breaks on fastcgi server with strange error
        close STDERR;
        open(STDERR, ">", \$stderr_output);
    };
    $c->log->error($@) if $@;

    my $num = 0;
    for my $file (keys %{$uniq}) {
        next if $file eq 'error.tt';
        next if $file =~ m|^cmd/cmd_typ_|mx;
        eval {
            $c->view("TT")->render($c, $file);
        };
        $num++;
    }
    # Now close and restore STDERR to original condition.
    eval {
        # breaks on fastcgi server with strange error
        close STDERR;
        ## no critic
        open STDERR, ">&".$savestderr;
        ## use critic
    };
    $c->log->error($@) if $@;

    $c->config->{'precompile_templates'} = 2;
    my $elapsed = tv_interval ( $t0 );
    my $result = sprintf("%s templates precompiled in %.2fs\n", $num, $elapsed);
    $c->log->info($result) if(!defined $ENV{'THRUK_SRC'} || ($ENV{'THRUK_SRC'} ne 'CLI' and $ENV{'THRUK_SRC'} ne 'SCRIPTS'));
    return $result;
}

##########################################################

=head2 find_files

  find_files($folder, $pattern)

return list of files for folder and pattern

=cut

sub find_files {
    my ( $dir, $match ) = @_;
    my @files;
    $dir =~ s/\/$//gmxo;

    my @tmpfiles;
    opendir(my $dh, $dir) or confess("cannot open directory $dir: $!");
    while(my $file = readdir $dh) {
        next if $file eq '.';
        next if $file eq '..';
        push @tmpfiles, $file;
    }
    closedir $dh;

    for my $file (@tmpfiles) {
        # follow sub directories
        if(-d $dir."/".$file."/.") {
            push @files, @{find_files($dir."/".$file, $match)};
        }

        # if its a file, make sure it matches our pattern
        if(defined $match) {
            my $test = $dir."/".$file;
            next unless $test =~ m/$match/mx;
        }

        push @files, $dir."/".$file;
    }

    return \@files;
}

##########################################################

=head2 beautify_diff

  beautify_diff($text)

make diff output beauty

=cut

sub beautify_diff {
    my($text) = @_;
    $text =~ s/^\-\-\-(.*)$/<font color="#0776E8"><b>---$1<\/b><\/font>/gmx;
    $text =~ s/^\+\+\+(.*)$//gmx;
    $text =~ s/^index\ .*$//gmx;
    $text =~ s/^diff\ .*$//gmx;
    $text =~ s/^\@\@(.*)$/<font color="#0776E8"><b>\@\@$1<\/b><\/font>/gmx;
    $text =~ s/^\-(.*)$/<font color="red">-$1<\/font>/gmx;
    $text =~ s/^\+(.*)$/<font color="green">+$1<\/font>/gmx;
    return $text;
}

##########################################################

=head2 check_memory_usage

  check_memory_usage($c)

check if memory limit is above the threshold

=cut

sub check_memory_usage {
    my($c) = @_;
    my $mem = Thruk::Backend::Pool::get_memory_usage();
    $c->log->debug("checking memory limit: ".$mem.' (limit: '.$c->config->{'max_process_memory'}.')');
    if($mem > $c->config->{'max_process_memory'}) {
        $c->log->debug("exiting process due to memory limit: ".$mem.' (limit: '.$c->config->{'max_process_memory'}.')');
        $c->env->{'psgix.harakiri.commit'} = 1;
        kill(15, $$); # send SIGTERM to ourselves which should be used in the FCGI::ProcManager::pm_post_dispatch then
    }
    return;
}

##########################################################

=head2 base_folder

    base_folder($c)

return base etc folder

=cut
sub base_folder {
    my($c) = @_;
    if($ENV{'THRUK_CONFIG'}) {
        return($ENV{'THRUK_CONFIG'});
    }
    return($c->config->{'home'});
}

########################################

=head2 is_post

    is_post($c)

make sure this is a post request

=cut
sub is_post {
    my($c) = @_;
    return(1) if $c->req->method eq 'POST';
    $c->log->error("insecure request, post method required: ".Dumper($c->req));
    $c->detach('/error/index/24');
    return;
}

########################################

=head2 check_csrf

    check_csrf($c)

ensure valid cross site request forgery token

=cut
sub check_csrf {
    my($c) = @_;
    return 1 if($ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'CLI');
    return unless is_post($c);
    for my $addr (@{$c->config->{'csrf_allowed_hosts'}}) {
        return 1 if $c->req->address eq $addr;
        if(CORE::index( $addr, '*' ) >= 0) {
            # convert wildcards into real regexp
            my $search = $addr;
            $search =~ s/\.\*/*/gmx;
            $search =~ s/\*/.*/gmx;
            return 1 if $c->req->address =~ m/$search/mx;
        }
    }
    my $post_token  = $c->req->parameters->{'token'};
    my $valid_token = Thruk::Utils::Filter::get_user_token($c);
    if($valid_token and $post_token and $valid_token eq $post_token) {
        return(1);
    }
    $c->log->error("possible csrf, no or invalid token: ".Dumper($c->req));
    $c->detach('/error/index/24');
    return;
}


########################################

=head2 get_plugin_name

    get_plugin_name(__FILE__, __PACKAGE__)

returns the name of the plugin

=cut
sub get_plugin_name {
    my($file, $pkg) = @_;
    $pkg =~ s|::|/|gmx;
    $pkg .= '.pm';
    $file =~ s|/lib/\Q$pkg\E$||gmx;
    $file =~ s|^.*/||gmx;
    return($file);
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
    my($c, $string) = @_;
    my $timestamp;

    # just a timestamp?
    if($string =~ m/^(\d+)$/mx) {
        $timestamp = $1;
    }

    # real date (YYYY-MM-DD HH:MM:SS)
    elsif($string =~ m/(\d{1,4})\-(\d{1,2})\-(\d{1,2})\ (\d{1,2}):(\d{1,2}):(\d{1,2})/mx) {
        $timestamp = Mktime($1,$2,$3, $4,$5,$6);
    }

    # real date without seconds (YYYY-MM-DD HH:MM)
    elsif($string =~ m/(\d{1,4})\-(\d{1,2})\-(\d{1,2})\ (\d{1,2}):(\d{1,2})/mx) {
        $timestamp = Mktime($1,$2,$3, $4,$5,0);
    }

    # US date format (MM-DD-YYYY HH:MM:SS)
    elsif($string =~ m/(\d{1,2})\-(\d{1,2})\-(\d{2,4})\ (\d{1,2}):(\d{1,2}):(\d{1,2})/mx) {
        $timestamp = Mktime($3,$1,$2, $4,$5,$6);
    }

    # everything else
    else {
        # Date::Manip increases start time, so load it here upon request
        require Date::Manip;
        Date::Manip->import(qw/UnixDate/);
        $timestamp = UnixDate($string, '%s');
        $c->log->debug("not a valid date: ".$string) if $c;
        if(!defined $timestamp) {
            return;
        }
    }
    return $timestamp;
}

##############################################

1;

__END__

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
