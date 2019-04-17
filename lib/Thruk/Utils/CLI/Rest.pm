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

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions) = @_;

    # split args by url, then parse leading options. In case there is only one
    # url, all options belong to this url.
    my $opts = _parse_args($commandoptions);
    if(ref $opts eq "") {
        return({output => $opts, rc => 2});
    }

    # logging to screen would break json output
    {
        delete $c->app->{'_log'};
        local $ENV{'THRUK_SRC'} = undef;
        $c->app->init_logging();
    }
    if(scalar @{$opts} == 0) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    my $result = _fetch_results($c, $opts);
    # return here for simple requests
    if(scalar @{$result} == 1 && !$result->[0]->{'output'} && !$result->[0]->{'warning'} && !$result->[0]->{'critical'}) {
        return({output => $result->[0]->{'result'}, rc => $result->[0]->{'rc'}, all_stdout => 1});
    }

    my($output, $rc) = _create_output($c, $result);
    return({output => $output, rc => $rc, all_stdout => 1 });
}

##############################################
sub _fetch_results {
    my($c, $opts) = @_;
    for my $opt (@{$opts}) {
        my $url = $opt->{'url'};
        $url =~ s|^/||gmx;

        $c->stats->profile(begin => "_cmd_rest($url)");
        my $sub_c = $c->sub_request('/r/v1/'.$url, uc($opt->{'method'}), $opt->{'postdata'}, 1);
        $c->stats->profile(end => "_cmd_rest($url)");

        $opt->{'result'} = $sub_c->res->body;
        $opt->{'rc'}     = ($sub_c->res->code == 200 ? 0 : 3);
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
        'method'   => undef,
        'postdata' => [],
        'warning'  => [],
        'critical' => [],
        };
        Getopt::Long::GetOptionsFromArray($s,
        "m|method=s"   => \$opt->{'method'},
        "d|data=s"     =>  $opt->{'postdata'},
        "o|output=s"   => \$opt->{'output'},
        "w|warning=s"  =>  $opt->{'warning'},
        "c|critical=s" =>  $opt->{'critical'},
        );
        if(scalar @{$s} == 1) {
            $opt->{'url'} = $s->[0];
        }

        if($opt->{'postdata'} && scalar @{$opt->{'postdata'}} > 0 && !$opt->{'method'}) {
            $opt->{'method'} = 'POST';
        }
        $opt->{'method'} = 'GET' unless $opt->{'method'};

        my $postdata = {};
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
    my($threshold, $data, $totals) = @_;
    return unless scalar @{$data->{$threshold}} > 0;
    $data->{'data'} = decode_json($data->{'result'}) unless $data->{'data'};

    for my $t (@{$data->{$threshold}}) {
        my($attr,$val1, $val2) = split(/:/mx, $t, 3);
        my $value = $data->{'data'}->{$attr} // 0;
        if(!exists $data->{'data'}->{$attr}) {
            _set_rc($data, 3, "unknown variable $attr in thresholds, syntax is --$threshold=key:value\n");
            return;
        }
        if(defined $val2) {
            eval {
                require Monitoring::Plugin::Range;
            };
            if($@) {
                die("Monitoring::Plugin module is required when using threshold ranges");
            }
            my $r = Monitoring::Plugin::Range->parse_range_string($val1.":".$val2);
            if($r->check_range($value)) {
                if($threshold eq 'warning')  { _set_rc($data, 1); }
                if($threshold eq 'critical') { _set_rc($data, 2); }
            }
            # save range object
            $totals->{'range'}->{$attr}->{$threshold} = $r;
            next;
        }
        # single value check
        if($value < 0 || $value > $val1) {
            if($threshold eq 'warning')  { _set_rc($data, 1); }
            if($threshold eq 'critical') { _set_rc($data, 2); }
        }
        $totals->{$threshold}->{$attr} = $val1;
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
    my($c, $result) = @_;
    my($output, $rc) = ("", 0);

    # if there are output formats, use them
    my $totals = {};
    for my $r (@{$result}) {
        # directly return fetch errors
        return($r->{'result'}, $r->{'rc'}) if $r->{'rc'} > 0;

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
        STATUS => $c->config->{'nagios'}->{'service_state_by_number'}->{$rc} // 'UNKNOWN',
    };
    $output = $totals->{'output'};
    $output =~ s/\{([^\}]+)\}/&_replace_output($1, $result, $macros)/gemx;

    chomp($output);
    $output .= _append_performance_data($result);
    $output .= "\n";
    return($output, $rc);
}

##############################################
sub _append_performance_data {
    my($result) = @_;
    my @perf_data;
    my $totals = $result->[0];
    for my $key (sort keys %{$totals->{'data'}}) {
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
        push @perf_data, sprintf("'%s'=%s;%s;%s;%s;%s",
                $key,
                $totals->{'data'}->{$key} // 'U',
                $warn,
                $crit,
                $min,
                $max,
        );
    }
    return("|".join(" ", @perf_data));
}

##############################################
sub _calculate_data_totals {
    my($result, $totals) = @_;
    $totals->{data} = {};
    for my $r (@{$result}) {
        $r->{'data'} = decode_json($r->{'result'}) unless $r->{'data'};
        for my $key (sort keys %{$r->{'data'}}) {
            if(!defined $totals->{'data'}->{$key}) {
                $totals->{'data'}->{$key} = $r->{'data'}->{$key};
            } else {
                $totals->{'data'}->{$key} += $r->{'data'}->{$key};
            }
        }
    }
    return($totals);
}

##############################################
sub _replace_output {
    my($var, $result, $macros) = @_;
    my $format;
    if($var =~ m/^(.*)(%[^%]+?)$/gmx) {
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
            $val = $result->[$nr]->{'data'}->{$v} // $macros->{$v};
            if(!defined $val) {
                $error = "error:$v does not exist";
            }
        }
        push @processed, $val;
    }
    my $value = "";
    if($error) {
        $value  = '{'.$error.'}';
        $format = "";
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
    return($value);
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
