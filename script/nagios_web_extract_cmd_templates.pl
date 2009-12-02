#!/usr/bin/env perl

=head1 NAME

nagios_web_extract_cmd_templates.pl - extract cmd templates

=head1 SYNOPSIS

./nagios_web_extract_cmd_templates.pl [ -h ] [ -v ] <file[s]>

=head1 DESCRIPTION

this script opens templates and extracts the needed information and writes out new templates

=head1 ARGUMENTS

script has the following arguments

=over 4

=item help

    -h

print help and exit

=item verbose

    -v

verbose output

=item files

    files    path to files to parse

=back

=head1 EXAMPLE

./nagios_web_extract_cmd_templates.pl -c <path_to_nagios_cgi_cmd.c> -H <path_to_nagios_include_common.h> templates/cmd_type_*.tt

=head1 AUTHOR

2009, Sven Nierlein, <nierlein@cpan.org>


=head1 EXAMPLE

create cmd templates like this:
x=1; while [ $x -lt 169 ]; do QUERY_STRING="cmd_typ=$x" REMOTE_USER=nagiosadmin REQUEST_METHOD=GET ./cmd.cgi | tidy -config ~/.tidyrc > /tmp/cmd_typ_$x.tt; x=$((x+1)); done

use a ~/.tidyrc like this:

    indent: autouppercase-tags: no
    clean: no
    numeric-entities: no
    markup: yes
    quiet: yes
    output-html: yes
    language: en

 then use this script to clean up the templates

=cut

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;

$Data::Dumper::Sortkeys = 1;

#########################################################################
# parse and check cmd line arguments
my ($opt_h, $opt_v, @opt_files, $opt_c, $opt_H);
Getopt::Long::Configure('no_ignore_case');
if(!GetOptions (
   "h"              => \$opt_h,
   "v"              => \$opt_v,
   "c=s"            => \$opt_c,
   "H=s"            => \$opt_H,
   "<>"             => \&add_files,
)) {
    pod2usage( { -verbose => 1, -message => 'error in options' } );
    exit 3;
}

if(defined $opt_h) {
    pod2usage( { -verbose => 1 } );
    exit 3;
}
my $verbose = 0;
if(defined $opt_v) {
    $verbose = 1;
}

if(scalar @opt_files <= 0) {
    pod2usage( { -verbose => 1, -message => 'no files specified' } );
    exit 3;
}

if(!defined $opt_c or !-f $opt_c) {
    pod2usage( { -verbose => 1, -message => $opt_c.":".$! } );
    exit 3;
}

if(!defined $opt_H or !-f $opt_H) {
    pod2usage( { -verbose => 1, -message => $opt_H.":".$! } );
    exit 3;
}

my $cmd_numbers = parse_cmds_from_common_h($opt_H);
my $cmd_order   = parse_cmds_from_cmd_c($opt_c);

#########################################################################
for my $file (sort @opt_files) {
    open(my $fh, '<', $file) or die("cannot open file $file: $!");
    my $text = "";
    while(my $line = <$fh>) {
        $text .= $line;
    }
    close($fh);

    my $number;
    if($file =~ m/cmd_typ_(\d+)\.tt/mx) {
        $number = $1;
    } else {
        die("got no number from $file");
    }

    $text =~ s/>\s+</></gmx;
    $text =~ s/\n/ /gmx;

    if($text =~ m/You\ are\ requesting\ to\ execute\ an\ unknown\ command/mx) {
        unlink($file);
        next;
    }

    #print Dumper($text);

    my($commandDescription, $commandRequest, $commandForm);
    my $date = '';
    if($text =~ m/<td\ class='commandDescription'>(.*?)<\/td>/gmx) {
        $commandDescription = $1;
    }

    if($text =~ m/(You\ are\ requesting.*?)\s*</mx) {
        $commandRequest = $1;
    }

    if($text =~ m/<input\s*type=\s*'hidden'\s*name='cmd_mod'\s*value='2'>\s*<\/td>\s*<\/tr>(.*)<tr>\s*<td\s*class='optBoxItem'\s*colspan="2">\s*<\/td>\s*<\/tr>.*?<input\s*type='submit'/mx) {
        $commandForm = $1;
        $commandForm =~ s/<\/tr>/<\/tr>\n/gmx;
        $commandForm =~ s/name=\s+/name=/gmx;

        # replace some default values
        my $replace_cgi_vars = {
            'down_id'       => 'down_id',
            'com_id'        => 'com_id',
            'host'          => 'host',
            'service'       => 'service',
            'servicegroup'  => 'servicegroup',
            'hostgroup'     => 'hostgroup',
        };
        for my $name (keys %{$replace_cgi_vars}) {
            $commandForm =~ s/type='text'\s+name='$name'\s+value='[^']*'/type='text'\ name='$name'\ value='[%\ c.request.parameters.$replace_cgi_vars->{$name} %]'/gmx;
        }

        # replace start time
        if($commandForm =~ s/type='text'\s+name='start_time'\s+value=\s*'[^']+'/type='text'\ name='start_time'\ value='[%\ date.format(date.now,\ '%Y-%m-%d\ %H:%M:%S')\ %]'/gmx) {
            $date = "[% USE date %]\n";
        }

        # replace end time
        if($commandForm =~ s/type='text'\s+name='end_time'\s+value=\s*'[^']+'/type='text'\ name='end_time'\ value='[%\ date.format(date.now+7200,\ '%Y-%m-%d\ %H:%M:%S')\ %]'/gmx) {
            $date = "[% USE date %]\n";
        }

        # replace (locked) author
        $commandForm =~ s/type='text'\ name='com_author'\ value='nagiosadmin'\ readonly\ disabled/type='text'\ name='com_author'\ value='[%\ comment_author\ %]'[%\ IF\ c.cgi_cfg.lock_author_names\ %]\ readonly\ disabled[%\ END\ %]/gmx;

        # replace downtime trigger
        if($commandForm =~ s/<tr><td\ class='optBoxItem'>Triggered\ By:<\/td>.*?<\/option><\/select><\/td><\/tr>/<tr><td\ class='optBoxItem'>Triggered\ By:<\/td><td><select\ name='trigger'><option\ value='0'>\ N\/A\ <\/option>[%\ FOREACH\ d\ =\ hostdowntimes\ %]<option\ value='[%\ d.id\ %]'>\ ID:\ [%\ d.id\ %],\ Host\ '[%\ d.host_name %]'\ starting\ @\ [%\ date.format(d.start_time,\ '%Y-%m-%d\ %H:%M:%S')\ %]\ <\/option>[%\ END\ %][%\ FOREACH\ d\ =\ servicedowntimes\ %]<option\ value='[% d.id %]'>\ ID:\ [%\ d.id\ %],\ Service\ '[%\ d.service_description\ %]'\ on\ host\ '[%\ d.host_name\ %]'\ starting\ @\ [%\ date.format(d.start_time,\ '%Y-%m-%d\ %H:%M:%S') %]\ <\/option>[%\ END\ %]<\/select><\/td><\/tr>/gmx) {
            $date = "[% USE date %]\n";
        }

        #print $commandForm;
    }

    if(!defined $commandDescription or !defined $commandRequest or !defined $commandForm) {
        die("error in $file");
    }

    # authorization types
    my $authorization;
    if($commandForm =~ m/name='service'/gmx) {
        $authorization = "!c.check_user_roles('authorized_for_all_service_commands') && !c.check_permissions('service', c.request.parameters.service)";
    }
    elsif($commandForm =~ m/name='host'/gmx) {
        $authorization = "!c.check_user_roles('authorized_for_all_host_commands') && !c.check_permissions('host', c.request.parameters.host)";
    }
    elsif($commandForm =~ m/name='hostgroup'/gmx) {
        $authorization = "!c.check_user_roles('authorized_for_all_host_commands') && !c.check_permissions('hostgroup', c.request.parameters.hostgroup)";
    }
    elsif($commandForm =~ m/name='servicegroup'/gmx) {
        $authorization = "!c.check_user_roles('authorized_for_all_service_commands') && !c.check_permissions('servicegroup', c.request.parameters.servicegroup)";
    }
    else {
        $authorization = "!c.check_user_roles('authorized_for_system_commands')";
    }

    die("no command for number $number") if !defined $cmd_numbers->{$number};

    my $command_args = '';
    my $replacements = '';
    my $cmd = $cmd_numbers->{$number};
    if($commandForm =~ m/There\s+are\s+no\s+options\s+for\s+this\s+command/mx) {
    } else {
        my $form = $commandForm;
        if(my @matches = $form =~ m/name='(\w+)'/gmx) {
            my %matches = map { $_ => $_ } @matches;
            my %has_keys;

            die('got no command for: '.$cmd) if !defined $cmd_order->{$cmd};
            $command_args = '[% '.$cmd_order->{$cmd}.' %]';

            # check if we have all needed variable
            my %needed;
            if($command_args =~ m/sprintf\(".*"(.*)\)/mx) {
                my @needed = split/,/, $1;
                shift @needed;
                for my $need (@needed) {
                    $needed{$need} = 1;
                }
            } else {
                warn("args: ".$command_args." didnt match");
            }

            # replace checkbox values
            my $checkboxes = {
                'persistent'             => 'persistent_comment',
                'sticky_ack'             => 'sticky_ack',
                'force_notification'     => 'force_notification',
                'broadcast_notification' => 'broadcast_notification',
                'fixed'                  => 'fixed',
                'send_notification'      => 'send_notification',
            };
            for my $key (keys %{$checkboxes}) {
                if(defined $matches{$key}) {
                    $has_keys{$checkboxes->{$key}} = 1;
                    $replacements .= "\n    [% IF c.request.parameters.$key %][% $checkboxes->{$key} = 1 %][% ELSE %][% $checkboxes->{$key} = 0 %][% END %]";
                }
            }

            # replace delay
            for my $key (qw{not_dly}) {
                if(defined $matches{$key}) {
                    $has_keys{'notification_time'} = 1;
                    $date = "[% USE date %]\n";
                    $replacements .= "\n    [% ".sprintf("%-20s",'notification_time')." = date.now() + c.request.parameters.$key * 60 %]";
                }
            }

            # scheduled time
            if(defined $needed{'scheduled_time'} and defined $matches{'start_time'}) {
                $has_keys{'scheduled_time'} = 1;
                delete $matches{'start_time'};
                $replacements .= "\n    [% ".sprintf("%-20s",'scheduled_time')." = date.format( c.request.parameters.start_time, '%s') %]";
                $date = "[% USE date %]\n";
            }

            # replace times
            for my $key (qw{start_time end_time}) {
                if(defined $matches{$key}) {
                    $has_keys{$key} = 1;
                    $replacements .= "\n    [% ".sprintf("%-20s",$key)." = date.format( c.request.parameters.$key, '%s') %]";
                    $date = "[% USE date %]\n";
                }
            }

            # hours/minutes
            if(defined $matches{'hours'}) {
                $has_keys{'duration'} = 1;
                $replacements .= "\n    [% ".sprintf("%-20s",'duration')." = c.request.parameters.hour * 3600 + c.request.parameters.minutes * 60 %]";
                $date = "[% USE date %]\n";
            }

            # other replacements
            my $to_replace = {
                'host'              => 'host_name',
                'service'           => 'service_desc',
                'com_author'        => 'comment_author',
                'com_data'          => 'comment_data',
                'hostgroup'         => 'hostgroup_name',
                'servicegroup'      => 'servicegroup_name',
                'plugin_state'      => 'plugin_state',
                'plugin_output'     => 'plugin_output',
                'performance_data'  => 'performance_data',
                'down_id'           => 'downtime_id',
                'trigger'           => 'triggered_by',
                'com_id'            => 'comment_id',
            };
            for my $key (keys %{$to_replace}) {
                if(defined $matches{$key}) {
                    $has_keys{$to_replace->{$key}} = 1;
                    $replacements .= "\n    [% ".sprintf("%-20s",$to_replace->{$key})." = c.request.parameters.$key %]";
                }
            }

            if($command_args =~ s/\(force_notification\ \|\ broadcast_notification\)/options/mx) {
                $has_keys{'options'} = 1;
                $replacements .= "\n    [% ".sprintf("%-20s",'options')." = 0 + force_notification * 2 + broadcast_notification * 1 %]";
            }

            if($command_args =~ s/\(sticky_ack==TRUE\)\?ACKNOWLEDGEMENT_STICKY:ACKNOWLEDGEMENT_NORMAL/options/mx) {
                $has_keys{'options'} = 1;
                $replacements .= "\n    [% IF c.request.parameters.sticky_ack %][% options = 2 %][% ELSE %][% options = 1 %][% END %]";
            }

            # check if we have all needed variable
            if($command_args =~ m/sprintf\(".*"(.*)\)/mx) {
                my @needed = split/,/, $1;
                shift @needed;
                for my $need (@needed) {
                    print Dumper \%has_keys unless defined $has_keys{$need};
                    warn("missing key: '$need' in $number") unless defined $has_keys{$need};
                }
            }

            # affect_host_and_services
            if(defined $matches{'ahas'}) {
                my @choice;
                if($number == 15) {
                    @choice = qw{ENABLE_HOST_CHECK ENABLE_HOST_SVC_CHECKS};
                } elsif($number == 16) {
                    @choice = qw{DISABLE_HOST_CHECK DISABLE_HOST_SVC_CHECKS};
                } elsif($number == 28) {
                    @choice = qw{ENABLE_HOST_NOTIFICATIONS ENABLE_HOST_SVC_NOTIFICATIONS};
                } elsif($number == 29) {
                    @choice = qw{DISABLE_HOST_NOTIFICATIONS DISABLE_HOST_SVC_NOTIFICATIONS};
                } elsif($number == 63) {
                    @choice = qw{ENABLE_HOSTGROUP_HOST_NOTIFICATIONS ENABLE_HOSTGROUP_SVC_NOTIFICATIONS};
                } elsif($number == 64) {
                    @choice = qw{DISABLE_HOSTGROUP_HOST_NOTIFICATIONS DISABLE_HOSTGROUP_SVC_NOTIFICATIONS};
                } elsif($number == 67) {
                    @choice = qw{ENABLE_HOSTGROUP_HOST_CHECKS ENABLE_HOSTGROUP_SVC_CHECKS};
                } elsif($number == 68) {
                    @choice = qw{DISABLE_HOSTGROUP_HOST_CHECKS DISABLE_HOSTGROUP_SVC_CHECKS};
                } elsif($number == 85) {
                    @choice = qw{SCHEDULE_HOSTGROUP_HOST_DOWNTIME SCHEDULE_HOSTGROUP_SVC_DOWNTIME};
                } elsif($number == 109) {
                    @choice = qw{ENABLE_SERVICEGROUP_HOST_NOTIFICATIONS ENABLE_SERVICEGROUP_SVC_NOTIFICATIONS};
                } elsif($number == 110) {
                    @choice = qw{DISABLE_SERVICEGROUP_HOST_NOTIFICATIONS DISABLE_SERVICEGROUP_SVC_NOTIFICATIONS};
                } elsif($number == 113) {
                    @choice = qw{ENABLE_SERVICEGROUP_HOST_CHECKS ENABLE_SERVICEGROUP_SVC_CHECKS};
                } elsif($number == 114) {
                    @choice = qw{DISABLE_SERVICEGROUP_HOST_CHECKS DISABLE_SERVICEGROUP_SVC_CHECKS};
                } elsif($number == 122) {
                    @choice = qw{SCHEDULE_SERVICEGROUP_HOST_DOWNTIME SCHEDULE_SERVICEGROUP_SVC_DOWNTIME};
                } else {
                    warn("commands with 'ahas' checkbox have to be defined explicitly ($number)");
                }
                $cmd = "[% IF c.request.parameters.ahas %]".$choice[0]."[% ELSE %]".$choice[1]."[% END %]" if defined $choice[0];
            }

            # propagate_to_children
            if(defined $matches{'ptc'}) {
                my @choice;
                if($number == 24) {
                    @choice = qw{ENABLE_HOST_AND_CHILD_NOTIFICATIONS ENABLE_HOST_NOTIFICATIONS};
                } elsif($number == 25) {
                    @choice = qw{DISABLE_HOST_AND_CHILD_NOTIFICATIONS DISABLE_HOST_NOTIFICATIONS};
                } else {
                    warn("commands with 'ptc' checkbox have to be defined explicitly ($number)");
                }
                $cmd = "[% IF c.request.parameters.ptc %]".$choice[0]."[% ELSE %]".$choice[1]."[% END %]" if defined $choice[0];
            }

            # force_check
            if(defined $matches{'force_check'}) {
                my @choice;
                if($number == 7) {
                    @choice = qw{SCHEDULE_FORCED_SVC_CHECK SCHEDULE_SVC_CHECK};
                } elsif($number == 17) {
                    @choice = qw{SCHEDULE_FORCED_HOST_SVC_CHECKS SCHEDULE_HOST_SVC_CHECKS};
                } elsif($number == 96) {
                    @choice = qw{SCHEDULE_FORCED_HOST_CHECK SCHEDULE_HOST_CHECK};
                } else {
                    warn("commands with 'force_check' checkbox have to be defined explicitly ($number)");
                }
                $cmd = "[% IF c.request.parameters.force_check %]".$choice[0]."[% ELSE %]".$choice[1]."[% END %]" if defined $choice[0];
            }

            $command_args = ';'.$command_args if $command_args ne '';
        }
    }

    my $newContent = $date.
"[%# which one is authorized? #%]
[% IF c.check_user_roles('is_authorized_for_read_only')
   || (".$authorization.")
%]
[% ELSE %]

[%# description used by the commands page #%]
[% WRAPPER \$cmd_tt
   request     = '".$commandRequest."'
   description = '".$commandDescription."'
%]

[%# definition of the command send to nagios #%]
[% BLOCK action%]$replacements

    ".$cmd.$command_args."
[% END %]

[%# definition of the html form data #%]
$commandForm
[% END %]
[% END %]";

    open($fh, '>', $file) or die("cannot write file $file: $!");
    print $fh $newContent;
    close($fh);
    print "$file written\n";
}

#########################################################################
sub add_files {
    my $file = shift;
    push @opt_files, $file;
}

#########################################################################
sub parse_cmds_from_common_h {
    my $common_h = shift;

    my $cmd_numbers;
    open(my $fh, '<', $common_h) or die('failed to open '.$common_h." :".$!);
    while(my $line = <$fh>) {
        if($line =~ m/\s*\#define\s+CMD_(\w+)\s+(\d+)\s*/mx) {
            $cmd_numbers->{$2} = $1;
        }
    }
    close($fh);

    return($cmd_numbers);
}

#########################################################################

sub parse_cmds_from_cmd_c {
    my $common_h = shift;

    my $cmd_order;
    open(my $fh, '<', $common_h) or die('failed to open '.$common_h." :".$!);
    my @current_commands;
    my $current_result;
    while(my $line = <$fh>) {
        if($line =~ m/case\s+CMD_(\w+):/mx) {
            push @current_commands, $1;
        }

        if($line =~ m/result.*?=\s+(.*);/mx) {
            my $tmp = $1;
            $tmp =~ s/cmd_submitf\(\w+\s*,\s*/sprintf(/mx;
            if(defined $current_result and $current_result ne $tmp) {
                warn("got more results:\n".Dumper($current_result)."\n".Dumper($tmp));
            }
            $current_result = $tmp;
        }

        if($line =~ m/break;/mx) {
            if(defined $current_result) {
                #print "###################################\n";
                #print Dumper(\@current_commands);
                #print Dumper($current_result);
                for my $cur (@current_commands) {
                    $cmd_order->{$cur} = $current_result;
                }
            }
            undef @current_commands;
            undef $current_result;
        }
    }
    close($fh);

    return($cmd_order);
}