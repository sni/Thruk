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
use Module::Load qw/load/;

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
    elsif($timeperiod =~ /last(\d+)months?/mx) {
        my $months = $1;
        $end   = Mktime($year,$month,1,  0,0,0);
        my $lastmonth = $month - $months;
        while($lastmonth <= 0) { $lastmonth = $lastmonth + 12; $year--;}
        $start = Mktime($year,$lastmonth,1,  0,0,0);
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
    my($can_submit_commands,$alias,$data,$email);
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
            $alias = $dat->{'alias'} if defined $dat->{'alias'};
            $email = $dat->{'email'} if defined $dat->{'email'};
            if(defined $dat->{'can_submit_commands'} && (!defined $can_submit_commands || $dat->{'can_submit_commands'} == 0)) {
                $can_submit_commands = $dat->{'can_submit_commands'};
            }
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

    return($roles, $can_submit_commands, $alias, $roles_by_group, $email);
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

    my($roles, undef, $alias, undef, $email) = get_dynamic_roles($c, $username, $c->user);

    if(defined $alias) {
        $c->user->{'alias'} = $alias;
    }
    if(defined $email) {
        $c->user->{'email'} = $email;
    }

    for my $role (@{$roles}) {
        push @{$c->user->{'roles'}}, $role;
    }

    $c->user->{'roles'} = array_uniq($c->user->{'roles'});

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

    $c->stash->{ssi_header}  = Thruk::Utils::read_ssi($c, 'common', 'header');
    $c->stash->{ssi_header} .= Thruk::Utils::read_ssi($c, $page, 'header');
    $c->stash->{ssi_footer}  = Thruk::Utils::read_ssi($c, 'common', 'footer');
    $c->stash->{ssi_footer} .= Thruk::Utils::read_ssi($c, $page, 'footer');

    return 1;
}


########################################

=head2 read_ssi

  read_ssi($c, $page, $type)

finds all ssi files for a page of the specified type and returns the ssi content.
Executable ssi files are executed and the output is appended to the ssi content.
Otherwise the content of the ssi file is appende to the ssi content.

=cut
sub read_ssi {
    my $c    = shift;
    my $page = shift;
    my $type = shift;
    my $dir  = $c->config->{ssi_path};
    my @files = sort grep { /\A${page}-${type}(-.*)?.ssi\z/mx } keys %{ $c->config->{ssi_includes} };
    my $output = "";
    for my $inc (@files) {
        $output .= "\n<!-- BEGIN SSI $dir/$inc -->\n" if Thruk->verbose;
        if ( -x "$dir/$inc" ) {
          if(open(my $ph, '-|', "$dir/$inc 2>&1")) {
            while(defined(my $line = <$ph>)) { $output .= $line; }
            CORE::close($ph);
          } else {
            carp("cannot execute ssi $dir/$inc: $!");
          }
        } elsif ( -r "$dir/$inc" ) {
            my $content = read_file("$dir/$inc");
            unless(defined $content) { carp("cannot open ssi $dir/$inc: $!") }
            $output .= $content;
        } else {
            $c->log->warn("$dir/$inc is no longer accessible, please restart thruk to initialize ssi information");
        }
        $output .= "\n<!-- END SSI $dir/$inc -->\n" if Thruk->verbose;
    }
    return $output;
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

  get_custom_vars($c, $obj, [$prefix], [$add_host])

return custom variables in a hash

=cut
sub get_custom_vars {
    my($c, $data, $prefix, $add_host) = @_;
    $prefix = '' unless defined $prefix;

    my %hash;

    if(   defined $data
      and defined $data->{$prefix.'custom_variable_names'}
      and defined $data->{$prefix.'custom_variable_values'}
      and ref $data->{$prefix.'custom_variable_names'} eq 'ARRAY')
    {
        # merge custom variables into a hash
        @hash{@{$data->{$prefix.'custom_variable_names'}}} = @{$data->{$prefix.'custom_variable_values'}};
    }

    if($add_host
      and defined $data
      and defined $data->{'host_custom_variable_names'}
      and defined $data->{'host_custom_variable_values'}
      and ref $data->{'host_custom_variable_names'} eq 'ARRAY')
    {
        for(my $x = 0; $x < scalar @{$data->{'host_custom_variable_names'}}; $x++) {
            my $key = $data->{'host_custom_variable_names'}->[$x];
            $hash{"HOST".$key} = $data->{'host_custom_variable_values'}->[$x];
        }
    }

    # add action menu from apply rules
    if($c && $c->config->{'action_menu_apply'} && !$hash{'THRUK_ACTION_MENU'}) {
        APPLY:
        for my $menu (sort keys %{$c->config->{'action_menu_apply'}}) {
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

    my $prefix   = $args->{'prefix'} || '';
    my $search   = $args->{'search'} || 'show_custom_vars';
    my $dest     = $args->{'dest'}   || 'custom_vars';
    my $host     = $args->{'host'};
    my $service  = $args->{'service'};
    my $add_host = $args->{'add_host'};
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
    return unless ref $data->{$prefix.'custom_variable_names'} eq 'ARRAY';
    return unless defined $c->config->{$search};

    my $vars        = ref $c->config->{$search} eq 'ARRAY' ? $c->config->{$search} : [ $c->config->{$search} ];
    my $custom_vars = get_custom_vars($c, $data, $prefix, $add_host);

    my $already_added = {};
    for my $test (@{$vars}) {
        for my $cust_name (sort keys %{$custom_vars}) {
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
            next unless $found;

            # expand macros in custom vars
            my $cust_value = $custom_vars->{$cust_name};
            if(defined $host and defined $service) {
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
            my $is_host = defined $service ? 0 : 1;
            if($add_host) {
                if($cust_name =~ s/^HOST//gmx) {
                    $is_host = 1;
                }
            }
            next if $already_added->{$cust_name};
            $already_added->{$cust_name} = 1;
            push @{$c->stash->{$dest}}, [ $cust_name, $cust_value, $is_host ];
        }
    }
    return;
}

########################################

=head2 check_custom_var_list

  check_custom_var_list($varname, $allowed)

returns true if custom variable name is in the list of allowed variable names

=cut

sub check_custom_var_list {
    my($varname, $allowed) = @_;

    $varname =~ s/^_//gmx;

    for my $cust_name (@{$allowed}) {
        $cust_name =~ s/^_//gmx;
        if($varname eq $cust_name) {
            return(1);
        } else {
            my $v = "".$varname;
            next if CORE::index($v, '*') == -1;
            $v =~ s/\*/.*/gmx;
            if($cust_name =~ m/^$v$/mx) {
                return(1);
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
    my($c, $type) = @_;
    Thruk::Utils::Status::set_selected_columns($c, [''], ($type || 'log'));
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

=head2 get_histou_url

  get_histou_url($c, $object)

return histou url for object (host/service)

=cut

sub get_histou_url {
    my($c, $obj, $force) = @_;

    return '' unless $c->config->{'shown_inline_pnp'} || $force;

    for my $type (qw/action_url_expanded notes_url_expanded/) {
        next unless defined $obj->{$type};
        if($obj->{$type} =~ m%histou\.js\?|/grafana/%mx) {
            return($obj->{$type});
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

##########################################################

=head2 get_perf_image

  get_perf_image($c, {
    host           => $hst,
    service        => $svc,
    start          => $start,
    end            => $end,
    width          => $width,
    height         => $height,
    source         => $source,
    resize_grafana => $resize_grafana_images,
    format         => $format,
    show_title     => $showtitle,
  })

return raw pnp/grafana image if possible.
An empty string will be returned if no graph can be exported.

=cut
sub get_perf_image {
    my($c, $options) = @_;
    my $pnpurl     = "";
    my $grafanaurl = "";
    $options->{'format'}     = 'png'  unless $options->{'format'};
    $options->{'service'}    = ''     unless defined $options->{'service'};
    $options->{'show_title'} = 1      unless defined $options->{'show_title'};
    $options->{'end'}        = time() unless defined $options->{'end'};
    $options->{'start'}      = $options->{'end'} - 86400 unless defined $options->{'start'};

    my $custvars;
    if($options->{'service'}) {
        my $svcdata = $c->{'db'}->get_services(filter => [{ host_name => $options->{'host'}, description => $options->{'service'} }]);
        if(scalar @{$svcdata} == 0) {
            $c->log->error("no such service ".$options->{'service'}." on host ".$options->{'host'});
            return("");
        }
        $pnpurl     = get_pnp_url($c, $svcdata->[0], 1);
        $grafanaurl = get_histou_url($c, $svcdata->[0], 1);
        $custvars   = Thruk::Utils::get_custom_vars($c, $svcdata->[0]);
    } else {
        my $hstdata = $c->{'db'}->get_hosts(filter => [{ name => $options->{'host'}}]);
        if(scalar @{$hstdata} == 0) {
            $c->log->error("no such host ".$options->{'host'});
            return("");
        }
        $pnpurl                = get_pnp_url($c, $hstdata->[0], 1);
        $grafanaurl            = get_histou_url($c, $hstdata->[0], 1);
        $options->{'service'}  = '_HOST_' if $pnpurl;
        $custvars              = Thruk::Utils::get_custom_vars($c, $hstdata->[0]);
    }

    if(!$options->{'show_title'}) {
        $grafanaurl .= '&disablePanelTitle';
    }

    $c->stash->{'last_graph_type'} = 'pnp';
    if($grafanaurl) {
        $c->stash->{'last_graph_type'} = 'grafana';
        $grafanaurl =~ s|/dashboard/|/dashboard-solo/|gmx;
        # grafana panel ids usually start at 1 (or 2 with old versions)
        delete $options->{'source'} if(defined $options->{'source'} && $options->{'source'} eq 'null');
        $options->{'source'} = ($custvars->{'GRAPH_SOURCE'} || $c->config->{'grafana_default_panelId'} || '1') unless defined $options->{'source'};
        $grafanaurl .= '&panelId='.$options->{'source'};
        if($options->{'resize_grafana'}) {
            $options->{'width'}  = $options->{'width'} * 1.3;
            $options->{'height'} = $options->{'height'} * 2;
        }
        $grafanaurl .= '&legend=false' if $options->{'height'} < 200;
        if($grafanaurl !~ m|^https?:|mx) {
            my $uri = Thruk::Utils::Filter::full_uri($c, 1);
            $uri    =~ s|(https?://[^/]+?)/.*$|$1|gmx;
            $uri    =~ s|&amp;|&|gmx;
            $grafanaurl = $uri.$grafanaurl;
        }
    } else {
        $options->{'source'} = ($custvars->{'GRAPH_SOURCE'} || '0') unless defined $options->{'source'};
    }

    my $exporter = $c->config->{home}.'/script/pnp_export.sh';
    $exporter    = $c->config->{'Thruk::Plugin::Reports2'}->{'pnp_export'} if $c->config->{'Thruk::Plugin::Reports2'}->{'pnp_export'};
    if($grafanaurl) {
        $exporter = $c->config->{home}.'/script/grafana_export.sh';
        $exporter = $c->config->{'Thruk::Plugin::Reports2'}->{'grafana_export'} if $c->config->{'Thruk::Plugin::Reports2'}->{'grafana_export'};
    }

    # create fake session
    my $sessionid = get_fake_session($c);
    local $ENV{PHANTOMJSSCRIPTOPTIONS} = '--cookie=thruk_auth,'.$sessionid.' --format='.$options->{'format'};

    # call login hook, because it might transfer our sessions to remote graphers
    if($c->config->{'cookie_auth_login_hook'}) {
        Thruk::Utils::IO::cmd($c, $c->config->{'cookie_auth_login_hook'});
    }

    my($fh, $filename) = tempfile();
    CORE::close($fh);
    my $cmd = $exporter.' "'.$options->{'host'}.'" "'.$options->{'service'}.'" "'.$options->{'width'}.'" "'.$options->{'height'}.'" "'.$options->{'start'}.'" "'.$options->{'end'}.'" "'.($pnpurl||'').'" "'.$filename.'" "'.$options->{'source'}.'"';
    if($grafanaurl) {
        if($ENV{'OMD_ROOT'}) {
            my $site = $ENV{'OMD_SITE'};
            if($grafanaurl =~ m|^https?://localhost/$site(/grafana/.*)$|mx) {
                $grafanaurl = $c->config->{'omd_local_site_url'}.$1;
            }
        }
        $cmd = $exporter.' "'.$options->{'width'}.'" "'.$options->{'height'}.'" "'.$options->{'start'}.'" "'.$options->{'end'}.'" "'.$grafanaurl.'" "'.$filename.'"';
    }
    Thruk::Utils::IO::cmd($c, $cmd);
    unlink($c->stash->{'fake_session_file'});
    if(-s $filename) {
        my $imgdata  = read_file($filename);
        unlink($filename);
        if($options->{'format'} eq 'png') {
            return '' if substr($imgdata, 0, 10) !~ m/PNG/mx; # check if this is a real image
        }
        return $imgdata;
    }
    return "";
}

##############################################

=head2 get_fake_session

  get_fake_session($c)

create and return fake session id for current user

=cut

sub get_fake_session {
    my($c) = @_;
    my $sdir        = $c->config->{'var_path'}.'/sessions';
    my $sessionid   = md5_hex(rand(1000).time());
    my $sessionfile = $sdir.'/'.$sessionid;
    Thruk::Utils::IO::mkdir_r($sdir);
    Thruk::Utils::IO::write($sessionfile, "none~~~127.0.0.1~~~".$c->stash->{'remote_user'});
    push @{$c->stash->{'tmp_files_to_delete'}}, $sessionfile;
    $c->stash->{'fake_session_id'}   = $sessionid;
    $c->stash->{'fake_session_file'} = $sessionfile;
    return($sessionid);
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
    elsif($action_url =~ m/\/histou\.js\?/mx) {
        $action_url =~ s/&amp;/&/gmx;
        $action_url =~ s/&/&amp;/gmx;
        my $popup_url = $action_url;
        $popup_url =~ s|/dashboard/|/dashboard-solo/|gmx;
        $popup_url .= '&amp;panelId='.$c->config->{'grafana_default_panelId'};
        $action_url .= "' class='histou_tips' rel='".$popup_url;
        return($action_url);
    }

    if ($graph_word) {
        for my $regex (@{list($graph_word)}) {
            if ($action_url =~ m|$regex|mx){
                my $new_host = $host;
                for my $regex (@{$c->config->{'graph_replace'}}) {
                    ## no critic
                    eval('$new_host =~ '.$regex);
                    ## use critic
                }

                if ($svc) {
                    my $new_svc = $svc;
                    for my $regex (@{$c->config->{'graph_replace'}}) {
                        ## no critic
                        eval('$new_svc =~ '.$regex);
                        ## use critic
                    }
                    $new_action_url =~ s/\Q$svc\E/$new_svc/gmx;
                }
                $new_action_url =~ s/\Q$host\E/$new_host/gmx;

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

=head2 array_chunk

  array_chunk($list, $number)

return list of <number> evenly chunked parts

=cut

sub array_chunk {
    my($list, $number) = @_;
    my $chunks = [];
    my $size = POSIX::floor(scalar @{$list} / $number);
    while(my @chunk = splice( @{$list}, 0, $size+1 ) ) {
        push @{$chunks}, \@chunk;
    }
    return($chunks);
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

=head2 expand_duration

  expand_duration($value)

returns expanded seconds from given abbreviation

possible conversions are
1w => 604800
1d => 86400
1h => 3600
1m => 60

=cut
sub expand_duration {
    my($value) = @_;
    if($value =~ m/^(\d+)(y|w|d|h|m|s)/gmx) {
        if($2 eq 'y') { return $1 * 86400*365; }# year
        if($2 eq 'w') { return $1 * 86400*7; }  # weeks
        if($2 eq 'd') { return $1 * 86400; }    # days
        if($2 eq 'h') { return $1 * 3600; }     # hours
        if($2 eq 'm') { return $1 * 60; }       # minutes
        if($2 eq 's') { return $1 }             # seconds
    }
    return $value;
}

##############################################

=head2 choose_mobile

  choose_mobile($c, $url)

let the user choose a mobile page or not

=cut

sub choose_mobile {
    my($c,$url) = @_;

    return unless defined $c->config->{'use_feature_mobile'};
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
        local $< = $> if $< == 0; # set real and effective uid to user, crontab will still be run as root on some systems otherwise
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
        local $< = $> if $< == 0; # set real and effective uid to user, crontab will still be run as root on some systems otherwise
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
    $c->stats->profile(begin => "wait_after_reload ($time)");
    $pkey = $c->stash->{'param_backend'} unless $pkey;
    my $start = time();
    if(!$pkey && !$time) { sleep 3; }

    # wait until core responds again
    my $procinfo = {};
    my $done     = 0;
    while($start > time() - 30) {
        $procinfo = {};
        eval {
            local $SIG{ALRM}   = sub { die "alarm\n" };
            local $SIG{'PIPE'} = sub { die "pipe error\n" };
            alarm(5);
            $c->{'db'}->reset_failed_backends();
            $procinfo = $c->{'db'}->get_processinfo(backend => $pkey);
        };
        alarm(0);
        if($@) {
            $c->stats->profile(comment => "get_processinfo: ".$@);
            $c->log->debug('still waiting for core reload for '.(time()-$start).'s: '.$@);
        }
        elsif($pkey && $c->stash->{'failed_backends'}->{$pkey}) {
            $c->stats->profile(comment => "get_processinfo: ".$c->stash->{'failed_backends'}->{$pkey});
            $c->log->debug('still waiting for core reload for '.(time()-$start).'s: '.$c->stash->{'failed_backends'}->{$pkey});
        }
        elsif($pkey and $time) {
            # not yet restarted
            if($procinfo and $procinfo->{$pkey} and $procinfo->{$pkey}->{'program_start'}) {
                $c->stats->profile(comment => "core program_start: ".$procinfo->{$pkey}->{'program_start'});
                if($procinfo->{$pkey}->{'program_start'} > $time) {
                    $done = 1;
                    last;
                } else {
                    $c->log->debug('still waiting for core reload for '.(time()-$start).'s, last restart: '.(scalar localtime($procinfo->{$pkey}->{'program_start'})));
                }
            }
        }
        elsif($time) {
            my $newest_core = 0;
            if($procinfo) {
                for my $key (keys %{$procinfo}) {
                    if($procinfo->{$key}->{'program_start'} > $newest_core) { $newest_core = $procinfo->{$key}->{'program_start'}; }
                }
                $c->stats->profile(comment => "core program_start: ".$newest_core);
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
        if(time() - $start <= 5) {
            Time::HiRes::sleep(0.3);
        } else {
            sleep(1);
        }
    }
    $c->stats->profile(end => "wait_after_reload ($time)");
    if($done) {
        # clean up cached groups which may have changed
        $c->cache->clear();
    } else {
        $c->log->error('waiting for core reload failed');
        return(0);
    }
    return(1);
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

  read_data_file($filename, [$c])

return data for datafile

=cut

sub read_data_file {
    my($filename, $c) = @_;

    my $res;
    eval {
        $res = Thruk::Utils::IO::json_lock_retrieve($filename);
    };
    if(!$@ && $res) {
        return($res);
    }
    if($c) {
        $c->log->warn("error loading $filename - ".$@);
    } else {
        warn("error loading $filename - ".$@);
    }
    return;
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

  backup_data_file($filename, $targetfile, $mode, $max_backups, [$save_interval], [$force])

write data to datafile

=cut

sub backup_data_file {
    my($filename, $targetfile, $mode, $max_backups, $save_interval, $force) = @_;

    my @backups     = sort glob($targetfile.'.*.'.$mode);
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
        copy($filename, $targetfile.'.'.$now.'.'.$mode);

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
        return($_[0]) if $@ =~ m/\QWide character at\E/mxo;                         # since Encode.pm ~2.90 message changed
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
    return($c->config->{'etc_path'});
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

=head2 backends_list_to_hash

    backends_list_to_hash($c, $list)

returns array of backend ids converted as list of hashes

=cut
sub backends_list_to_hash {
    my($c, $backends) = @_;
    my $hashlist = [];
    for my $back (@{list($backends)}) {
        my $name;
        if(ref $back eq 'HASH') {
            my $key  = (keys %{$back})[0];
            $name    = $back->{$key};
            $back    = $key;
        }
        my $backend = $c->{'db'}->get_peer_by_key($back);
        $name = $backend->{'name'} if $backend;
        push @{$hashlist}, { $back => $name };
    }
    return($hashlist);
}

########################################

=head2 backends_hash_to_list

    backends_hash_to_list($c, $hashlist)

returns array of backends (inverts backends_list_to_hash function)

=cut
sub backends_hash_to_list {
    my($c, $hashlist) = @_;
    my $backends = [];
    for my $b (@{list($hashlist)}) {
        if(ref $b eq '') {
            my $backend = $c->{'db'}->get_peer_by_key($b) || $c->{'db'}->get_peer_by_name($b);
            push @{$backends}, ($backend ? $backend->peer_key() : $b);
        } else {
            for my $key (keys %{$b}) {
                my $backend = $c->{'db'}->get_peer_by_key($key);
                if(!defined $backend && defined $b->{$key}) {
                    $backend = $c->{'db'}->get_peer_by_key($b->{$key});
                }
                if($backend) {
                    push @{$backends}, $backend->peer_key();
                } else {
                    push @{$backends}, $key;
                }
            }
        }
    }
    return($backends);
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

########################################

=head2 convert_wildcards_to_regex

    convert_wildcards_to_regex($string)

returns regular expression with wildcards replaced

=cut
sub convert_wildcards_to_regex {
    my($str) = @_;
    $str =~ s/^\*/.*/gmx;
    return($str);
}

##############################################

=head2 find_modules

    find_modules($pattern)

returns list of found modules

=cut
sub find_modules {
    my($pattern) = @_;
    my $modules = {};
    for my $folder (@INC) {
        next unless -d $folder;
        for my $file (glob($folder.$pattern)) {
            $file =~ s|^\Q$folder/\E||gmx;
            $modules->{$file} = 1;
        }
    }
    return([sort keys %{$modules}]);
}

##############################################

=head2 get_cli_modules

    get_cli_modules()

returns list of cli modules

=cut
sub get_cli_modules {
    my $modules = find_modules('/Thruk/Utils/CLI/*.pm');
    @{$modules} = sort map {
            my $mod = $_;
            if($mod =~ s/.*\/([^\/]+)\.pm/$1/gmx) {
                $mod = lc($1);
            }
            $mod;
        } @{$modules};
    return($modules);
}

##############################################

=head2 clean_regex

    clean_regex()

returns cleaned regular expression, ex.: removes trailing .*

=cut
sub clean_regex {
    my($regex) = @_;

    # trim leading and trailing whitespace
    $regex =~ s/^\s+//mx;
    $regex =~ s/\s+$//mx;

    # trim leading and trailing .*(?)
    $regex =~ s/^\.\*\??//mx;
    $regex =~ s/\.\*\??$//mx;

    return($regex);
}

##############################################

=head2 get_timezone_data

    get_timezone_data()

returns list of available timezones

=cut
sub get_timezone_data {
    my($c, $add_server) = @_;

    my $timezones = [];
    my $cache = Thruk::Utils::Cache->new($c->config->{'var_path'}.'/timezones.cache');
    my $data  = $cache->get('timezones');
    my $timestamp = Thruk::Utils::format_date(time(), "%Y-%m-%d %H");
    if(defined $data && $data->{'timestamp'} eq $timestamp) {
        $timezones = $data->{'timezones'};
    } else {
        load "DateTime";
        load "DateTime::TimeZone";
        my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
        for my $name (DateTime::TimeZone->all_names) {
            my $dt = DateTime->new(
                year      => $year+1900,
                month     => $mon+1,
                day       => $mday,
                hour      => $hour,
                minute    => $min,
                second    => $sec,
                time_zone => $name,
            );
            push @{$timezones}, {
                text   => $name,
                abbr   => $dt->time_zone()->short_name_for_datetime($dt),
                offset => $dt->offset(),
                isdst  => $dt->is_dst() ? Cpanel::JSON::XS::true : Cpanel::JSON::XS::false,
            };
        }
        $cache->set('timezones', {
            timestamp => $timestamp,
            timezones => $timezones,
        });
    }

    unshift @{$timezones}, {
        text   => 'Local Browser',
        abbr   => '',
        offset => 0,
    };
    if($add_server) {
        unshift @{$timezones}, {
            text   => 'Server Setting',
            abbr   => '',
            offset => 0,
        };
    }
    return($timezones);
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
