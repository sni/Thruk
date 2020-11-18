package Thruk::Utils::CLI::Rest;

=head1 NAME

Thruk::Utils::CLI::Rest - Rest API CLI module

=head1 DESCRIPTION

The rest command is a cli interface to the rest api.

=head1 SYNOPSIS

  Usage:

    - simple query:
      thruk [globaloptions] rest [-m method] [-d postdata] <url>

    - multiple queries_:
      thruk [globaloptions] rest [-m method] [-d postdata] <url> [-m method] [-d postdata] <url>

=cut

use warnings;
use strict;
use Getopt::Long ();
use Cpanel::JSON::XS qw/decode_json/;
use Thruk::Utils::Filter ();
use Thruk::Utils::Log qw/:all/;

our $skip_backends = \&_skip_backends;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, undef, $commandoptions, undef, undef, $opt) = @_;

    # split args by url, then parse leading options. In case there is only one
    # url, all options belong to this url.
    my $opts = $opt->{'_parsed_args'} // _parse_args($commandoptions);
    if(ref $opts eq "") {
        return({output => $opts, rc => 2});
    }

    if(scalar @{$opts} == 0) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    my $result = _fetch_results($c, $opts, $opt);
    # return here for simple requests
    if(scalar @{$result} == 1 && !$result->[0]->{'output'} && !$result->[0]->{'warning'} && !$result->[0]->{'critical'} && !$result->[0]->{'rename'}) {
        return({output => $result->[0]->{'result'}, rc => $result->[0]->{'rc'}, all_stdout => 1});
    }

    my($output, $rc) = _create_output($c, $opts, $result);
    return({output => $output, rc => $rc, all_stdout => 1 });
}

##############################################
sub _fetch_results {
    my($c, $opts, $global_opts) = @_;

    for my $opt (@{$opts}) {
        my $url = $opt->{'url'};

        # Support local files and remote urls as well.
        # But for security reasons only from the command line
        if($ENV{'THRUK_CLI_SRC'} && $ENV{'THRUK_CLI_SRC'}) {
            # json arguments
            if($url =~ m/^\s*\[.*\]\s*$/mx || $url =~ m/^\s*\{.*\}\s*$/mx) {
                $opt->{'result'} = $url;
                $opt->{'rc'}     = 0;
                _debug("json data from command line argument:");
                _debug($opt->{'result'});
                next;
            }
            elsif($url =~ m/^https?:/mx) {
                my($code, $result, $res) = Thruk::Utils::CLI::request_url($c, $url, undef, $opt->{'method'}, $opt->{'postdata'}, $opt->{'headers'}, $global_opts->{'insecure'});
                if(Thruk->verbose >= 2) {
                    _debug2("request:");
                    _debug2($res->request->as_string());
                    _debug2("response:");
                    _debug2($res->as_string());
                }
                $opt->{'result'} = $result->{'result'};
                $opt->{'rc'}     = $code == 200 ? 0 : 3;
                if(!$opt->{'result'} && $opt->{'rc'} != 0) {
                    $opt->{'result'} = Cpanel::JSON::XS->new->pretty->encode({
                        'message'  => $res->message(),
                        'code'     => $res->code(),
                        'request'  => $res->request->as_string(),
                        'response' => $res->as_string(),
                        'failed'   => Cpanel::JSON::XS::true,
                    })."\n";
                }
                next;
            } elsif(-r $url) {
                _debug("loading local file: ".$url);
                $opt->{'result'} = Thruk::Utils::IO::read($url);
                $opt->{'rc'}     = 0;
                _debug("json data from local file ".$url.":");
                _debug($opt->{'result'});
                next;
            }
        }

        $url =~ s|^/||gmx;

        $c->stats->profile(begin => "_cmd_rest($url)");
        my $sub_c = $c->sub_request('/r/v1/'.$url, uc($opt->{'method'}), $opt->{'postdata'}, 1);
        $c->stats->profile(end => "_cmd_rest($url)");

        $opt->{'result'} = $sub_c->res->body;
        $opt->{'rc'}     = ($sub_c->res->code == 200 ? 0 : 3);
        _debug2("json data:");
        _debug2($opt->{'result'});
    }
    return($opts);
}

##############################################
sub _parse_args {
    my($args) = @_;

    # split by url
    my $current_args = [];
    my $split_args = [];
    while(@{$args}) {
        my $a = shift @{$args};
        if($a =~ m/^\-\-/mx) {
            push @{$current_args}, $a;
        } elsif($a =~ m/^\-/mx) {
            push @{$current_args}, $a;
            push @{$current_args}, shift @{$args};
        } else {
            push @{$current_args}, $a;
            push @{$split_args}, $current_args;
            undef $current_args;
        }
    }
    # trailing args are amended to the previous url
    if($current_args) {
        if(scalar @{$split_args} > 0) {
            push @{$split_args->[scalar @{$split_args}-1]}, @{$current_args};
        }
    }

    # then parse each options
    my @commands = ();
    Getopt::Long::Configure('no_ignore_case');
    Getopt::Long::Configure('bundling');
    Getopt::Long::Configure('pass_through');
    for my $s (@{$split_args}) {
        my $opt = {
            'method'     => undef,
            'postdata'   => [],
            'warning'    => [],
            'critical'   => [],
            'perfunit'   => [],
            'rename'     => [],
            'headers'    => [],
            'perffilter' => [],
        };
        Getopt::Long::GetOptionsFromArray($s,
            "H|header=s"      =>  $opt->{'headers'},
            "m|method=s"      => \$opt->{'method'},
            "d|data=s"        =>  $opt->{'postdata'},
            "o|output=s"      => \$opt->{'output'},
            "w|warning=s"     =>  $opt->{'warning'},
            "c|critical=s"    =>  $opt->{'critical'},
              "perfunit=s"    =>  $opt->{'perfunit'},
              "perffilter=s"  =>  $opt->{'perffilter'},
              "rename=s"      =>  $opt->{'rename'},
        );

        # last option of parameter set is the url
        if(scalar @{$s} >= 1) {
            $opt->{'url'} = pop(@{$s});
        }

        if($opt->{'postdata'} && scalar @{$opt->{'postdata'}} > 0 && !$opt->{'method'}) {
            $opt->{'method'} = 'POST';
        }
        $opt->{'method'} = 'GET' unless $opt->{'method'};

        my $postdata;
        for my $d (@{$opt->{'postdata'}}) {
            if(ref $d eq '' && $d =~ m/^\{.*\}$/mx) {
                my $data;
                my $json = Cpanel::JSON::XS->new->utf8;
                $json->relaxed();
                eval {
                    $data = $json->decode($d);
                };
                if($@) {
                    return("ERROR: failed to parse json data argument: ".$@, 1);
                }
                for my $key (sort keys %{$data}) {
                    $postdata->{$key} = $data->{$key};
                }
                next;
            }
            my($key,$val) = split(/=/mx, $d, 2);
            next unless $key;
            if(defined $postdata->{$key}) {
                $postdata->{$key} = [$postdata->{$key}] unless ref $postdata->{$key} eq 'ARRAY';
                push @{$postdata->{$key}}, $val;
            } else {
                $postdata->{$key} = $val;
            }
        }
        $opt->{'postdata'} = $postdata if $opt->{'postdata'};

        push @commands, $opt;
    }

    return(\@commands);
}

##############################################
sub _apply_threshold {
    my($threshold_name, $data, $totals) = @_;
    return unless scalar @{$data->{$threshold_name}} > 0;
    $data->{'data'} = decode_json($data->{'result'}) unless $data->{'data'};

    for my $t (@{$data->{$threshold_name}}) {
        my($attr, $threshold);
        # {key1.key2...}threshold
        # {key1::key2...}threshold
        if($t =~ m/^\s*\{([^\}]*)\}\s*(.*)\s*$/mx) {
            $attr      = $1;
            $threshold = $2;
        }
        # key1.key2...:threshold
        # key:threshold
        elsif($t =~ m/^\s*([^:]*?):\s*(.*)\s*$/mx) {
            $attr      = $1;
            $threshold = $2;
        } else {
            _set_rc($data, 3, "unknown threshold format, syntax is --$threshold_name={key}threshold, got: ".$t."\n");
            return;
        }
        $attr =~ s/\./::/gmx;

        my($value, $ok) = _get_value($data->{'data'}, $attr);
        if(!$ok) {
            _set_rc($data, 3, "unknown variable $attr in thresholds, syntax is --$threshold_name=key:value\n");
            return;
        }
        $value = 0 unless defined $value;
        if($threshold !~ m/^[\-\d\.]+$/mx) {
            eval {
                require Monitoring::Plugin::Range;
            };
            if($@) {
                die("Monitoring::Plugin module is required when using threshold ranges");
            }
            my $r = Monitoring::Plugin::Range->parse_range_string($threshold);
            if($r->check_range($value)) {
                if($threshold_name eq 'warning')  { _set_rc($data, 1); }
                if($threshold_name eq 'critical') { _set_rc($data, 2); }
            }
            # save range object
            $totals->{'range'}->{$attr}->{$threshold_name} = $r;
            next;
        }
        # single value check
        if($value < 0 || $value > $threshold) {
            if($threshold_name eq 'warning')  { _set_rc($data, 1); }
            if($threshold_name eq 'critical') { _set_rc($data, 2); }
        }
        $totals->{$threshold_name}->{$attr} = $threshold;
    }
    return;
}

##############################################
sub _set_rc {
    my($data, $rc, $msg) = @_;
    if(!defined $data->{'rc'} || $data->{'rc'} < $rc) {
        $data->{'rc'} = $rc;
    }
    if($msg) {
        $data->{'output'} = $msg;
    }
    return;
}

##############################################
sub _create_output {
    my($c, $opt, $result) = @_;
    my($output, $rc) = ("", 0);

    # if there are output formats, use them
    my $totals = {};
    for my $r (@{$result}) {
        # directly return fetch errors
        return($r->{'result'}, $r->{'rc'}) if $r->{'rc'} > 0;

        if($r->{rename} && scalar @{$r->{rename}} > 0) {
            $r->{'data'} = decode_json($r->{'result'}) unless $r->{'data'};
            for my $d (@{$r->{rename}}) {
                my($old,$new) = split(/:/mx,$d, 2);
                $r->{'data'}->{$new} = delete $r->{'data'}->{$old};
            }
        }

        # output template supplied?
        if($r->{'output'}) {
            if($totals->{'output'}) {
                _set_rc(3, "multiple -o/--output parameter are not supported.");
                return;
            }
            $totals->{'output'} = $r->{'output'};
        }

        # apply thresholds
        _apply_threshold('warning', $r, $totals);
        _apply_threshold('critical', $r, $totals);

        $rc = $r->{'rc'} if $r->{'rc'} > $rc;
        return($r->{'output'}, 3) if $r->{'rc'} == 3;
    }

    # if there is no format, simply concatenate the output
    if(!$totals->{'output'}) {
        for my $r (@{$result}) {
            $output .= $r->{'result'};
        }
        return($output, $rc);
    }

    $totals = _calculate_data_totals($result, $totals);
    unshift(@{$result}, $totals);
    my $macros = {
        STATUS => Thruk::Utils::Filter::state2text($rc) // 'UNKNOWN',
    };
    $output = $totals->{'output'};
    $output =~ s/\{([^\}]+)\}/&_replace_output($1, $result, $macros)/gemx;

    chomp($output);
    $output .= _append_performance_data($opt, $result);
    $output .= "\n";
    return($output, $rc);
}

##############################################
sub _append_performance_data {
    my($opt, $result) = @_;
    my @perf_data;
    my $totals = $result->[0];
    for my $key (sort keys %{$totals->{'data'}}) {
        my $perfdata = _append_performance_data_string($key, $totals->{'data'}->{$key}, $totals);
        push @perf_data, @{$perfdata} if $perfdata;
    }
    return("|".join(" ", @perf_data));
}

##############################################
sub _append_performance_data_string {
    my($key, $data, $totals) = @_;
    return unless _perffilter($totals->{'perffilter'}, $key);
    if(ref $data eq 'HASH') {
        my @res;
        for my $k (sort keys %{$data}) {
            my $r = _append_performance_data_string($key."::".$k, $data->{$k}, $totals);
            push @res, @{$r} if $r;
        }
        return \@res;
    }
    if(ref $data eq 'ARRAY') {
        my @res;
        my $index = 0;
        for my $v (@{$data}) {
            my $r = _append_performance_data_string($key."::".$index, $v, $totals);
            push @res, @{$r} if $r;
            $index++;
        }
        return \@res;
    }
    if(defined $data && !Thruk::Backend::Manager::looks_like_number($data)) {
        return;
    }
    my($min,$max,$warn,$crit) = ("", "", "", "");
    if($totals->{'range'}->{$key}->{'warning'}) {
        $warn = $totals->{'range'}->{$key}->{'warning'};
    } elsif($totals->{'warning'}->{$key}) {
        $warn = $totals->{'warning'}->{$key};
    }
    if($totals->{'range'}->{$key}->{'critical'}) {
        $crit = $totals->{'range'}->{$key}->{'critical'};
    } elsif($totals->{'critical'}->{$key}) {
        $crit = $totals->{'critical'}->{$key};
    }
    my $unit = "";
    for my $p (sort keys %{$totals->{perfunits}}) {
        if($p eq $key) {
            $unit = $totals->{perfunits}->{$p};
            last;
        }
        ## no critic
        if($key =~ m/^$p$/) {
        ## use critic
            $unit = $totals->{perfunits}->{$p};
            last;
        }
    }
    return([sprintf("'%s'=%s%s;%s;%s;%s;%s",
            $key,
            $data // 'U',
            $unit,
            $warn,
            $crit,
            $min,
            $max,
    )]);
}

##############################################
# return true if $key passes given filter or filter list is empty
sub _perffilter {
    my($perffilter, $key) = @_;
    return 1 if !$perffilter;
    return 1 if scalar @{$perffilter} == 0;
    for my $f (@{$perffilter}) {
        my $regex = qr/$f/mx;
        return 1 if $key =~ m/$regex/mx;
    }
    return(0);
}

##############################################
sub _calculate_data_totals {
    my($result, $totals) = @_;
    $totals->{data} = {};
    my $perfunits   = [];
    my $perffilter  = [];
    for my $r (@{$result}) {
        $r->{'data'} = decode_json($r->{'result'}) unless $r->{'data'};
        for my $key (sort keys %{$r->{'data'}}) {
            if(!defined $totals->{'data'}->{$key}) {
                $totals->{'data'}->{$key} = $r->{'data'}->{$key};
            } else {
                $totals->{'data'}->{$key} += $r->{'data'}->{$key};
            }
        }
        push @{$perfunits}, @{$r->{'perfunit'}}    if $r->{'perfunit'};
        push @{$perffilter}, @{$r->{'perffilter'}} if $r->{'perffilter'};
    }
    $totals->{perfunits} = {};
    for my $p (@{$perfunits}) {
        my($label, $unit) = split(/:/mx, $p, 2);
        $totals->{perfunits}->{$label} = $unit;
    }
    $totals->{perffilter} = $perffilter;
    return($totals);
}

##############################################
sub _replace_output {
    my($var, $result, $macros) = @_;
    my($format, $strftime);
    if($var =~ m/^(.*)%strftime:(.*)$/gmx) {
        $strftime = $2; # overwriting $var first breaks on <= perl 5.16
        $var      = $1;
    }
    elsif($var =~ m/^(.*)(%[^%]+?)$/gmx) {
        $format = $2; # overwriting $var first breaks on <= perl 5.16
        $var    = $1;
    }

    my @vars = split(/([\s\-\+\/\*\(\)]+)/mx, $var);
    my @processed;
    my $error;
    for my $v (@vars) {
        $v =~ s/^\s*//gmx;
        $v =~ s/\s*$//gmx;
        if($v =~ m/[\s\-\+\/\*\(\)]+/mx) {
            push @processed, $v;
            next;
        }
        my $nr = 0;
        if($v =~ m/^(\d+):(.*)$/mx) {
            $nr = $1;
            $v  = $2;
        }
        my $val;
        if($nr == 0 && $v =~ m/^\d\.?\d*$/mx && !defined $result->[$nr]->{'data'}->{$v}) {
            $val = $v;
        } else {
            my($ok);
            ($val, $ok) = _get_value($result->[$nr]->{'data'}, $v);
            if(!$ok && defined $macros->{$v}) {
                $val = $macros->{$v};
                $ok = 1;
            }
            if(!$ok) {
                $error = "error:$v does not exist";
            }
        }
        push @processed, $val;
    }
    my $value = "";
    if($error) {
        $value    = '{'.$error.'}';
        $format   = "";
        $strftime = "";
    }
    elsif(scalar @processed == 1) {
        $value = $processed[0] // '(null)';
    } else {
        for my $d (@processed) {
            $d = 0 unless defined $d;
        }
        ## no critic
        $value = eval(join("", @processed)) // '(error)';
        ## use critic
    }

    if($format) {
        return(sprintf($format, $value));
    }
    if($strftime) {
        return(POSIX::strftime($strftime, localtime($value)));
    }
    return($value);
}

##############################################
# return $val, $ok. $ok is true if a value was found
sub _get_value {
    my($data, $key) = @_;
    if(exists $data->{$key}) {
        return($data->{$key}, 1);
    }
    # traverse into nested hashes and lists
    my @parts = split(/\.|::/mx, $key);
    if(scalar @parts <= 1) {
        return(undef, 0);
    }

    my $val = $data;
    for my $k (@parts) {
        if(ref $val eq 'HASH' && exists $val->{$k}) {
            $val = $val->{$k};
        }
        elsif(ref $val eq 'ARRAY' && $k =~ m/^\d+$/mx && exists $val->[$k]) {
            $val = $val->[$k];
        } else{
            return(undef, 0);
        }
    }

    return($val, 1);
}

##############################################
# determines if command requires backends or not
sub _skip_backends {
    my($c, $opts) = @_;
    return unless $opts->{'commandoptions'};
    my $cmds = _parse_args($opts->{'commandoptions'});
    $opts->{'_parsed_args'} = $cmds;
    for my $cmd (@{$cmds}) {
        if(!$cmd->{'url'} || $cmd->{'url'} !~ m/^https?:\/\//mx) {
            return;
        }
    }
    return(1);
}

##############################################

=head1 EXAMPLES

Get list of hosts sorted by name

  %> thruk r /hosts?sort=name

Get list of hostgroups starting with literal l

  %> thruk r '/hostgroups?name[~]=^l'

Reschedule next host check for host localhost:

  %> thruk r -d "start_time=now" /hosts/localhost/cmd/schedule_host_check

Send multiple endpoints at once:

  %> thruk r "/hosts/totals" "/services/totals"

See more examples and additional help at https://thruk.org/documentation/rest.html

=cut

##############################################

1;
