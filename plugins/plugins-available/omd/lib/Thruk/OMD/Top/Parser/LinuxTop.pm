package Thruk::OMD::Top::Parser::LinuxTop;

use warnings;
use strict;
use Carp;
use IPC::Open3 qw/open3/;
use POSIX ();

use Thruk::Base ();
use Thruk::Utils::IO ();

=head1 NAME

Thruk::OMD::Top::Parser::LinuxTop - Parser for Linux Top Data

=head1 DESCRIPTION

Parses Linux Top data.

=head1 METHODS

=cut

##########################################################

=head2 new

    create new parser

=cut
sub new {
    my ( $class, $folder ) = @_;
    my $self = {
        'folder' => $folder,
    };
    bless $self, $class;
    return($self);
}

##########################################################

=head2 top_graph

    entry page with overview graph

=cut
sub top_graph {
    my ( $self, $c ) = @_;

    $c->stats->profile(begin => "top_graph");

    $c->stash->{template} = 'omd_top.tt';
    my $load_series = [
        { label => "load 1",  data =>  [] },
        { label => "load 5",  data =>  [] },
        { label => "load 15", data =>  [] },
    ];

    my $index = $self->_update_index($c);

    for my $line (@{$index}) {
        if(my @m = $line =~ m/(\d+)\.log.*?:\s*top\s+\-\s+(\d+):(\d+):(\d+)\s+up.*?average:\s*([\.\d]+),\s*([\.\d]+),\s*([\.\d]+)/gmxo) {
            my($time,$hour,$min,$sec,$l1,$l5,$l15) = (@m);
            $time = (($time - $time%60) + $sec)*1000;
            push @{$load_series->[0]->{'data'}}, [$time, $l1];
            push @{$load_series->[1]->{'data'}}, [$time, $l5];
            push @{$load_series->[2]->{'data'}}, [$time, $l15];
        }
    }
    $c->stash->{load_series} = $load_series;

    $c->stats->profile(end => "top_graph");
    return;
}

##########################################################

=head2 top_graph_details

    details graph for given timeperiod

=cut
sub top_graph_details {
    my ( $self, $c ) = @_;
    $c->stats->profile(begin => "top_graph_details");

    $c->stash->{template} = 'omd_top_details.tt';
    my @files = sort glob($self->{'folder'}.'/*.log '.$self->{'folder'}.'/*.gz');

    my $t1  = $c->req->parameters->{'t1'};
    my $t2  = $c->req->parameters->{'t2'};
    my $pid = $c->req->parameters->{'pid'};
    my $pattern = _get_pattern($c);

    if($pid) {
        $pattern = [
            [$pid, "Pid: $pid"],
        ];
    }

    # get all files which are matching the timeframe
    my $truncated  = 0;
    my $files_read = 0;
    my @file_list;
    if($pid && $c->req->parameters->{'expand'}) {
        # get all files with that pid, expand time range to start and end of that pid
        my $min   = 0;
        my $max   = scalar @files - 1;
        my $time  = $c->req->parameters->{'time'};
        my $start = 0;
        for my $file (@files) {
            $file =~ m/\/(\d+)\./mxo;
            if(defined $1) {
                last if $1 > $time;
                $start++;
            }
        }

        my $file = $files[$start];
        my($rc, $out) = Thruk::Utils::IO::cmd("LC_ALL=C zgrep -H -F -m 1 '$pid ' $file 2>/dev/null");
        if(!$out) {
            $start--;
        }

        my $x = $start;
        # find first occurance of pid
        while(1) {
            my $file = $files[$x];
            $file =~ m/\/(\d+)\./mxo;
            if(defined $1) {
                $x++;
                next;
            } else {
                my $time = $1;
                my($rc, $out) = Thruk::Utils::IO::cmd("LC_ALL=C zgrep -H -F -m 1 '$pid ' $file 2>/dev/null");
                if($out) {
                    $max = $x;
                } else {
                    $min = $x;
                }
                $x = $min + int(($max-$min) / 2);
                if($min == $x || $max == $x) {
                    if($min > 0) { $min--; }
                    $files[$min] =~ m/\/(\d+)\./mxo;
                    if($1) {
                        $t1 = $1;
                    }
                    last;
                }
            }
        }

        # find last occurance of pid
        $min = 0;
        $max = scalar @files - 1;
        $x   = $start;
        while(1) {
            my $file = $files[$x];
            $file =~ m/\/(\d+)\./mxo;
            if(!defined $1) {
                $x++;
                next;
            } else {
                my $time = $1;
                my($rc, $out) = Thruk::Utils::IO::cmd("LC_ALL=C zgrep -H -F -m 1 '$pid ' $file 2>/dev/null");
                if($out) {
                    $min = $x;
                } else {
                    $max = $x;
                }
                $x = $min + int(($max-$min) / 2);
                if($min == $x || $max == $x) {
                    if($max < scalar @files -1) { $max++; }
                    $files[$max] =~ m/\/(\d+)\./mxo;
                    if(defined $1) {
                        $t2 = $1;
                    }
                    last;
                }
            }
        }
        $c->stash->{'t1'} = $t1;
        $c->stash->{'t2'} = $t2;
    }

    for my $file (@files) {
        $file =~ m/\/(\d+)\./mxo;
        if(defined $1) {
            my $time = $1;
            if($time < $t1 || $time > $t2) {
                next;
            }
            push @file_list, $file;
            $files_read++;
        }
    }
    my $num = scalar @file_list;
    if($num > 500) {
        $truncated = 1;
        my $keep = int($num / 500);
        my @newfiles;
        my $x = 0;
        for my $file (@file_list) {
            $x++;
            if($x == 1 || $x == $num || $x % $keep == 0) {
                push @newfiles, $file;
            }
        }
        @file_list = @newfiles;
    }

    # now read all zip files at once
    my $proc_found = {};
    my $data       = _extract_top_data($c, \@file_list, undef, $pattern, $proc_found, $truncated, $pid);

    # create series to draw
    my $mem_series = [
        { label => "memory total",  data =>  [], color => "#000000"  },
        { label => "memory used",   data =>  [], stack => undef, lines => { fill => 1 } },
        { label => "buffers",       data =>  [], stack => 1, lines => { fill => 1 } },
        { label => "cached",        data =>  [], stack => 1, lines => { fill => 1 } },
    ];
    my $cpu_series = [
        { label => "user",      data =>  [], stack => 1, lines => { fill => 1 } },
        { label => "system",    data =>  [], stack => 1, lines => { fill => 1 } },
        { label => "nice",      data =>  [], stack => 1, lines => { fill => 1 } },
        { label => "wait",      data =>  [], stack => 1, lines => { fill => 1 } },
        #{ label => "high",      data =>  [], stack => undef },
        #{ label => "si",        data =>  [], stack => undef },
        #{ label => "st",        data =>  [], stack => undef },
    ];
    my $load_series = [
        { label => "load 1",  data =>  [] },
        { label => "load 5",  data =>  [] },
        { label => "load 15", data =>  [] },
    ];
    my $swap_series = [
        { label => "swap total",  color => "#000000", data =>  [] },
        { label => "swap used",   color => "#edc240", data =>  [], lines => { fill => 1 } },
    ];
    my $gearman_series = [
        { label => "checks running", color => "#0354E4", data =>  [] },
        { label => "checks waiting", color => "#F46312", data =>  [] },
        { label => "worker",         color => "#00C600", data =>  [] },
    ];
    my $proc_cpu_series = [];
    my $proc_mem_series = [];
    for my $key (sort keys %{$proc_found}) {
        push @{$proc_cpu_series}, { label => $key, data => [], stack => undef };
        push @{$proc_mem_series}, { label => $key, data => [], stack => undef };
    }
    for my $time (sort keys %{$data}) {
        my $js_time = $time*1000;
        my $d       = $data->{$time};
        push @{$mem_series->[0]->{'data'}}, [$js_time, $d->{mem}];
        push @{$mem_series->[1]->{'data'}}, [$js_time, $d->{mem_used}];
        push @{$mem_series->[2]->{'data'}}, [$js_time, $d->{buffers}];
        push @{$mem_series->[3]->{'data'}}, [$js_time, $d->{cached}];

        push @{$swap_series->[0]->{'data'}}, [$js_time, $d->{swap}];
        push @{$swap_series->[1]->{'data'}}, [$js_time, $d->{swap_used}];

        push @{$cpu_series->[0]->{'data'}}, [$js_time, $d->{cpu_us}];
        push @{$cpu_series->[1]->{'data'}}, [$js_time, $d->{cpu_sy}];
        push @{$cpu_series->[2]->{'data'}}, [$js_time, $d->{cpu_ni}];
        push @{$cpu_series->[3]->{'data'}}, [$time*1000, $data->{$time}->{cpu_wa}];
        #push @{$cpu_series->[4]->{'data'}}, [$js_time, $d->{cpu_hi}];
        #push @{$cpu_series->[5]->{'data'}}, [$js_time, $d->{cpu_si}];
        #push @{$cpu_series->[6]->{'data'}}, [$js_time, $d->{cpu_st}];

        push @{$load_series->[0]->{'data'}}, [$js_time, $d->{load1}];
        push @{$load_series->[1]->{'data'}}, [$js_time, $d->{load5}];
        push @{$load_series->[2]->{'data'}}, [$js_time, $d->{load15}];

        if($d->{gearman}) {
            push @{$gearman_series->[0]->{'data'}}, [$js_time, $d->{gearman}->{service}->{running}];
            push @{$gearman_series->[1]->{'data'}}, [$js_time, $d->{gearman}->{service}->{waiting}];
            push @{$gearman_series->[2]->{'data'}}, [$js_time, $d->{gearman}->{service}->{worker}];
        }

        my $x = 0;
        for my $key (sort keys %{$proc_found}) {
            push @{$proc_cpu_series->[$x]->{'data'}}, [$js_time, $d->{procs}->{$key}->{'cpu'} || 0];
            push @{$proc_mem_series->[$x]->{'data'}}, [$js_time, $d->{procs}->{$key}->{'mem'} || 0];
            $x++;
        }
    }
    $c->stash->{truncated}       = $truncated;
    $c->stash->{mem_series}      = $mem_series;
    $c->stash->{swap_series}     = $swap_series;
    $c->stash->{cpu_series}      = $cpu_series;
    $c->stash->{load_series}     = $load_series;
    $c->stash->{proc_cpu_series} = $proc_cpu_series;
    $c->stash->{proc_mem_series} = $proc_mem_series;
    $c->stash->{gearman_series}  = $gearman_series;

    $c->stats->profile(end => "top_graph_details");
    return;
}

##########################################################

=head2 top_graph_data

=cut
sub top_graph_data {
    my ( $self, $c ) = @_;
    my @files = sort glob($self->{'folder'}.'/*.log '.$self->{'folder'}.'/*.gz');
    my $time = $c->req->parameters->{'time'};
    my $lastfile;
    for my $file (@files) {
        $file =~ m/\/(\d+)\./mxo;
        if(defined $1) {
            my $timestamp = $1;
            last if $timestamp > $time;
            $lastfile = $file;
        }
    }
    $lastfile = Thruk::Base::basename($lastfile);
    my $d    = _extract_top_data($c, [$self->{'folder'}."/".$lastfile], 1);
    my @times = sort keys %{$d};
    my $data = $d->{$time} // $d->{$times[0]};
    $data->{'file'} = $lastfile;
    if(defined $ENV{'OMD_ROOT'}) { my $root = $ENV{'OMD_ROOT'}; $data->{'file'} =~ s|$root||gmx; }
    return $c->render(json => $data);
}

##########################################################
sub _extract_top_data {
    my($c, $files, $with_raw, $pattern, $proc_found, $first_one_only, $filter) = @_;

    $c->stats->profile(begin => "_extract_top_data") if $c;

    my($pid, $wtr, $rdr, @lines);
    $pid = open3($wtr, $rdr, $rdr, 'zcat', @{$files});
    CORE::close($wtr);

    $files->[0] =~ m/\/(\d+)\./mxo;
    my @startdate;
    if(defined $1) {
        @startdate = localtime($1);
    } else {
        return;
    }

    my $proc_started    = 0;
    my $gearman_started = 0;
    my $skip_this_one   = 0;
    my $result          = {};
    my($cur, $gearman);
    my $last_hour = $startdate[2];
    my $last_min  = -1;
    my $last_line;
    eval {
        while(my $line = <$rdr>) {
            $last_line = $line;
            $line =~ s/^\s+//mxo; # way faster than calling trim millions of times
            $line =~ s/\s+$//mxo;

            if($line =~ m/^top\s+\-\s+(\d+):(\d+):(\d+)\s+up.*?average:\s*([\.\d]+),\s*([\.\d]+),\s*([\.\d]+)/mxo) {
                if($cur) { $result->{$cur->{time}} = $cur; }
                $cur = { procs => {} };
                $cur->{'raw'} = [] if $with_raw;
                $cur->{'load1'}  = $4;
                $cur->{'load5'}  = $5;
                $cur->{'load15'} = $6;
                $skip_this_one   = 0;
                my($hour,$min,$sec) = ($1,$2,$3);
                if($last_hour == 23 and $hour != 23) {
                    @startdate = localtime(POSIX::mktime(59, 59, 23, $startdate[3], $startdate[4], $startdate[5], $startdate[6], $startdate[7])+7500);
                }
                $cur->{'time'}   = POSIX::mktime($sec, $min, $hour, $startdate[3], $startdate[4], $startdate[5], $startdate[6], $startdate[7]);
                if($first_one_only) {
                    if($last_min == $min) {
                        $skip_this_one = 1;
                        $cur           = undef;
                        next;
                    }
                }
                $last_hour       = $hour;
                $last_min        = $min;
                $proc_started    = 0;
                $gearman_started = 0;
                if($gearman) {
                    $cur->{gearman} = $gearman;
                    $gearman        = undef;
                }
                next;
            }

            if($line =~ m/^Queue\ Name/mxo) {
                $gearman_started = 1;
                $gearman         = {};
                next;
            }

            if($gearman_started) {
                if($line =~ m/^(\w+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)/mxo) {
                    $gearman->{$1} = { worker => 0+$2, waiting => 0+$3, running => 0+$4 };
                }
                next;
            }

            next if $skip_this_one;

            if(!$proc_started) {
                if($line =~ m/^PID/mxo) {
                    $proc_started    = 1;
                    $gearman_started = 0;
                }
                elsif($line =~ m/^Tasks:\s*(\d+)\s*total,/mxo) {
                    $cur->{'num'} = $1;
                }
                # CPU %
                elsif($line =~ m/^%?Cpu\(s\):\s*([\.\d]+)[%\s]*us,\s*([\.\d]+)[%\s]*sy,\s*([\.\d]+)[%\s]*ni,\s*([\.\d]+)[%\s]*id,\s*([\.\d]+)[%\s]*wa,\s*([\.\d]+)[%\s]*hi,\s*([\.\d]+)[%\s]*si,\s*([\.\d]+)[%\s]*st/mxo) {
                    $cur->{'cpu_us'} = $1;
                    $cur->{'cpu_sy'} = $2;
                    $cur->{'cpu_ni'} = $3;
                    $cur->{'cpu_id'} = $4;
                    $cur->{'cpu_wa'} = $5;
                    $cur->{'cpu_hi'} = $6;
                    $cur->{'cpu_si'} = $7;
                    $cur->{'cpu_st'} = $8;
                }
                # Memory
                elsif($line =~ m/^(KiB|)\s*Mem:\s*([\.\w]+)\s*total,\s*([\.\w]+)\s*used,\s*([\.\w]+)\s*free,\s*([\.\w]+)\s*buffers/mxo) {
                    my $factor = $1 eq 'KiB' ? 1024 : 1;
                    $cur->{'mem'}      = &_normalize_mem($2, $factor);
                    $cur->{'mem_used'} = &_normalize_mem($3, $factor);
                    $cur->{'buffers'}  = &_normalize_mem($5, $factor);
                }
                # Memory rhel7 format
                elsif($line =~ m/^(MiB|KiB|)\s*Mem\s*:\s*([\.\w]+)\s*total,\s*([\.\w]+)\s*free,\s*([\.\w]+)\s*used,\s*([\.\w]+)\s*buf/mxo) {
                    my $unit = $1;
                    my $factor = 1;
                    $factor = 1024      if $unit eq 'KiB';
                    $factor = 1024*1024 if $unit eq 'MiB';
                    $cur->{'mem'}      = &_normalize_mem($2, $factor);
                    $cur->{'mem_used'} = &_normalize_mem($4, $factor);
                    $cur->{'buffers'}  = &_normalize_mem($5, $factor);
                }
                # Swap / Cached
                elsif($line =~ m/^(KiB|)\s*Swap:\s*([\.\w]+)\s*total,\s*([\.\w]+)\s*used,\s*([\.\w]+)\s*free(,|\.)\s*([\.\w]+)\s*cached/mxo) {
                    my $factor = $1 eq 'KiB' ? 1024 : 1;
                    $cur->{'swap'}      = &_normalize_mem($2, $factor);
                    $cur->{'swap_used'} = &_normalize_mem($3, $factor);
                    $cur->{'cached'}    = &_normalize_mem($6, $factor);
                }
                # Swap / Cached rhel7 format
                elsif($line =~ m/^(MiB|KiB|)\s*Swap:\s*([\.\w]+)\s*total,\s*([\.\w]+)\s*free,\s*([\.\w]+)\s*used(,|\.)/mxo) {
                    my $unit = $1;
                    my $factor = 1;
                    $factor = 1024      if $unit eq 'KiB';
                    $factor = 1024*1024 if $unit eq 'MiB';
                    $cur->{'swap'}      = &_normalize_mem($2, $factor);
                    $cur->{'swap_used'} = &_normalize_mem($4, $factor);
                }
            } else {
                #    0      1     2      3      4      5     6      7       8     9     10     11
                #my($pid, $user, $prio, $nice, $virt, $res, $shr, $status, $cpu, $mem, $time, $cmd) = ...
                my @proc = split(/\s+/mxo, $line, 12);
                next unless $proc[11];
                next if $proc[0] eq 'PID';
                next if $filter && $filter != $proc[0];
                next if $proc[0] !~ m/^\d+/mx;
                my $key = 'other';
                for my $p (@{$pattern}) {
                    if($line =~ m|$p->[0]|mx) {
                        $key = $p->[1];
                        last;
                    }
                }
                $cur->{procs}->{$key} = {} unless defined $cur->{procs}->{$key};
                my $procs = $cur->{procs}->{$key};
                $procs->{num}  += 1;
                $procs->{cpu}  += $proc[8];
                my $virt;
                if($proc[4] =~ m/^[\d\.]+$/mxo) {
                    $virt += int($proc[4]/1024); # inline is much faster than million function calls
                } else {
                    $virt += &_normalize_mem($proc[4]);
                }
                $procs->{virt} += $virt;
                my $res;
                if($proc[5] =~ m/^[\d\.]+$/mxo) {
                    $res += int($proc[5]/1024); # inline is much faster than million function calls
                } else {
                    $res += &_normalize_mem($proc[5]);
                }
                $procs->{res} += $res;
                $procs->{mem} += $proc[9]; # in percent
                if($with_raw) {
                    push(@proc, $virt, $res);
                    push @{$cur->{'raw'}}, \@proc;
                }
                $proc_found->{$key} = 1;
            }
        }
    };
    if($@) {
        die("error around timestamp ".($cur ? $cur->{time} : 'unknown')." in line: ".$last_line."\n".$@);
    }
    if($gearman && $cur) {
        $cur->{gearman} = $gearman;
    }
    if($cur) { $result->{$cur->{time}} = $cur; }

    $c->stats->profile(end => "_extract_top_data") if $c;
    return($result);
}

##########################################################
# returns memory in megabyte
sub _normalize_mem {
    my($value, $factor) = @_;
    if($value =~ m/^([\d\.]+)([a-zA-Z])$/mxo) {
        $value = $1;
        my $unit = lc($2);
        if(   $unit eq 'k') { $value = $value / 1024; }
        elsif($unit eq 'm') {  }
        elsif($unit eq 'g') { $value = $value * 1024; }
        else {
            confess("could not parse top data: $value\n");
        }
    }
    elsif($value !~ m/^[\d\.]*$/mxo) {
        confess("could not parse top data: $value\n");
    } else {
        # default is bytes
        $value = $value/1024/1024;
    }
    $value = $value * $factor if defined $factor;
    return(int($value));
}

##########################################################
sub _get_pattern {
    my($c) = @_;
    my $pattern = [];
    if($c && $c->config->{'omd_top'}) {
        for my $regex (@{$c->config->{'omd_top'}}) {
            my($k,$p) = split(/\s*=\s*/mx, $regex, 2);
            &Thruk::Base::trim_whitespace($p);
            &Thruk::Base::trim_whitespace($k);
            push @{$pattern}, [$k,$p];
        }
    }
    return($pattern);
}

##########################################################
sub _update_index {
    my($self, $c) = @_;

    $c->stats->profile(begin => "_update_index");

    # read current index
    my $folder = $self->{'folder'};
    my $indexfile = $folder.'/.index';
    my @index     = Thruk::Utils::IO::saferead_as_list($indexfile);
    my $indexfiles = {};
    for my $row (@index) {
        my($file, undef) = split(/:/mx, $row, 2);
        $file = Thruk::Base::basename($file);
        $indexfiles->{$file} = $row;
    }

    # get existing and missing files
    my $existing = {};
    my $missing  = {};
    my @files = sort glob($folder.'/*.gz');
    for my $path (@files) {
        my $file = Thruk::Base::basename($path);
        $existing->{$file} = $path;
        $missing->{$file} = $path unless $indexfiles->{$file};
    }

    # remove obsolete entries
    my $changed = 0;
    for my $ind (sort keys %{$indexfiles}) {
        if(!defined $existing->{$ind}) {
            delete $indexfiles->{$ind};
            $changed++;
        }
    }
    if($changed > 0) {
        # write out cleaned up index
        my @lines;
        for my $f (sort keys %{$indexfiles}) {
            push @lines, $indexfiles->{$f};
        }
        Thruk::Utils::IO::write($indexfile, join("\n", @lines)."\n");
    }

    my @files_striped = sort keys %{$missing};
    if(scalar @files_striped > 0) {
        # zgrep to 30 files each to reduce the number of forks
        while( my @chunk = splice( @files_striped, 0, 30 ) ) {
            my $joined = join(' ', @chunk);
            my($rc, $out) = Thruk::Utils::IO::cmd("cd $folder && LC_ALL=C zgrep -H -F -m 1 'load average:' $joined 2>/dev/null >> $indexfile");
        }
        $changed++;
    }

    if($changed > 0) {
        @index = Thruk::Utils::IO::saferead_as_list($indexfile);
    }

    $c->stats->profile(end => "_update_index");

    return \@index;
}


##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-now, <sven@nierlein.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
