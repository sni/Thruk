package Thruk::Utils::CLI::Agents;

=head1 NAME

Thruk::Utils::CLI::Agents - Agents CLI module

=head1 DESCRIPTION

The agents command handles agent configs.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] agents [command]

=head1 OPTIONS

=over 4

Available commands are:

  - help                      print help and exit
  - check  | -C   <host>      run checks, ex. inventory
  - list   | -l               list agent hosts
  - show   | -S   <host>      show checks for host
  - add    | -I   <host> ...  add/inventory for new/existing host(s)
  - update | -II  <host> ...  add/inventory for new/existing host(s) and freshly apply excludes
             -III <host> ...  add/inventory for new/existing host(s) and remove manual overrides
  - rm     | -D   <host> ...  delete existing host(s)
  - reload | -R               reload monitoring core

  -i                interactive mode      (available in edit/add mode)
  --all             show all items        (available in show mode)
  -P | --password   set password          (available in add mode)
  -p | --port       set tcp port          (available in add mode)
       --ip         set ip address        (available in add mode)
       --section    set section           (available in add mode)
  -k | --insecure   skip tls verification (available in add mode)


=back

=cut

use warnings;
use strict;
use Cpanel::JSON::XS qw/decode_json/;
use File::Temp ();
use Getopt::Long ();
use Time::HiRes qw/gettimeofday tv_interval/;

use Thruk::Backend::Manager ();
use Thruk::Controller::conf ();
use Thruk::Utils ();
use Thruk::Utils::Agents ();
use Thruk::Utils::Auth ();
use Thruk::Utils::CLI ();
use Thruk::Utils::Conf ();
use Thruk::Utils::Log qw/:all/;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, undef, $commandoptions, $data, $src, $global_options) = @_;
    $c->stats->profile(begin => "_cmd_agents()");

    if(!$c->check_user_roles('authorized_for_admin')) {
        _error("authorized_for_admin role required");
        return("", 1);
    }

    # parse options
    my $opt = {
        'interactive'  => undef,
        'port'         => undef,
        'password'     => undef,
        'address'      => undef,
        'type'         => undef,
        'reload'       => undef,
        'check'        => undef,
        'list'         => undef,
        'show'         => undef,
        'edit'         => undef,
        'remove'       => undef,
        'fresh'        => undef,
        'clear_manual' => undef,
        'section'      => undef,
        'insecure'     => undef,
    };
    $opt->{'fresh'}        = 1 if Thruk::Base::array_contains('-II',  $commandoptions);
    $opt->{'clear_manual'} = 1 if Thruk::Base::array_contains('-III', $commandoptions);
    Getopt::Long::Configure('no_ignore_case');
    Getopt::Long::Configure('bundling');
    Getopt::Long::Configure('pass_through');
    Getopt::Long::GetOptionsFromArray($commandoptions,
       "all"          => \$opt->{'all'},
       "i"            => \$opt->{'interactive'},
       "p|port=i"     => \$opt->{'port'},
       "P|password=s" => \$opt->{'password'},
       "T|type=s"     => \$opt->{'type'},
       "l|list"       => \$opt->{'list'},
       "S|show"       => \$opt->{'show'},
       "C|check"      => \$opt->{'check'},
       "R|reload"     => \$opt->{'reload'},
       "I|add"        => \$opt->{'add'},
       "II|update"    => \$opt->{'fresh'},
       "III"          => \$opt->{'clear_manual'},
       "E|edit"       => \$opt->{'edit'},
       "D|remove"     => \$opt->{'remove'},
       "ip=s"         => \$opt->{'address'},
       "section=s"    => \$opt->{'section'},
       "s|insecure=s" => \$opt->{'insecure'},
    ) or do {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    };

    my $action;
    if($opt->{'list'})         { $action = "list"; }
    if($opt->{'add'})          { $action = "add"; }
    if($opt->{'edit'})         { $action = "edit"; }
    if($opt->{'fresh'})        { $action = "add"; }
    if($opt->{'clear_manual'}) { $action = "add"; }
    if($opt->{'show'})         { $action = "show"; }
    if($opt->{'remove'})       { $action = "rm"; }
    if($opt->{'check'})        { $action = "check"; if($commandoptions->[0] ne 'inventory') { unshift(@{$commandoptions}, 'inventory') } }
    if($opt->{'reload'})       { $action = "reload" unless $action; }

    $action = $action // shift @{$commandoptions} // '';

    if(!$action) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    my($output, $rc) = ("", 0);

    if($action eq 'check')     { ($output, $rc) = _run_check($c, $commandoptions, $data, $opt); }
    elsif($action eq 'list')   { ($output, $rc) = _run_list($c, $commandoptions, $opt); }
    elsif($action eq 'show')   { ($output, $rc) = _run_show($c, $commandoptions, $opt); }
    elsif($action eq 'add')    { ($output, $rc) = _run_add($c, $commandoptions, $opt, 0); }
    elsif($action eq 'edit')   { ($output, $rc) = _run_add($c, $commandoptions, $opt, 1); }
    elsif($action eq 'rm')     { ($output, $rc) = _run_remove($c, $commandoptions, $opt, $global_options); }
    elsif($action eq 'reload') {} # handled later
    else {
        _error("unknown command, see help for available commands");
        return("", 3);
    }

    # reload can be combined with existing actions like ex.: add
    if($action eq 'reload' || $opt->{'reload'}) {
        my($o, $r) = _run_reload($c);
        $rc += $r;
        $output = $output ? $output."\n".$o : $o;
    }

    $c->stats->profile(end => "_cmd_agents()");
    return($output, $rc);
}

##############################################
sub _run_reload {
    my($c) = @_;

    my $backend = _get_backend($c);
    Thruk::Utils::Agents::set_object_model($c, $backend);
    my($rc, $out) = Thruk::Utils::Conf::config_reload($c, $backend);

    # translate rc
    if($rc) { $rc = 0; } else { $rc = 1; }

    return($out, $rc);
}

##############################################
sub _run_check {
    my($c, $commandoptions, $data, $opt) = @_;

    my $output = "usage: $0 agents check inventory <host>\n";
    my $rc     = 3;

    $data->{'all_stdout'} = 1;
    my $action = shift @{$commandoptions} // '';
    if($action eq 'inventory') {
        my $host = shift @{$commandoptions} // '';
        ($output, $rc) = _check_inventory($c, $host, $opt);
    }
    return($output, $rc);
}

##############################################
sub _run_list {
    my($c, $commandoptions, $opt) = @_;

    my $filter = shift @{$commandoptions};
    my @result;
    my $hosts = $c->db->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ),
                                              'custom_variables' => { '~' => 'AGENT .+' },
                                            ],
                                 );
    my $versions = $c->db->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ),
                                         'host_custom_variables' => { '~' => 'AGENT .+' },
                                         'description' => 'agent version',
                                        ],
                                        columns => [qw/host_name plugin_output state/],
                                 );
    $versions = Thruk::Base::array2hash($versions, "host_name");

    for my $hst (@{$hosts}) {
        next if($filter && $hst->{'name'} !~ m/$filter/mx);
        my $agent = Thruk::Utils::Agents::build_agent($hst);
        my $address = $hst->{'address'};
        if($agent->{'port'} ne $agent->settings()->{'default_port'}) {
            $address .= ':'.$agent->{'port'};
        }
        my $row = {
            'host_name' => $hst->{'name'},
            'site'      => Thruk::Utils::Filter::peer_name($hst),
            'section'   => $agent->{'section'},
            'agent'     => $agent->{'type'},
            'address'   => $address,
        };
        if($versions->{$hst->{'name'}}) {
            my $versiondata = $versions->{$hst->{'name'}};
            if($versiondata->{'state'} == 0) {
                my $v = $versiondata->{'plugin_output'};
                $v =~ s/^.*v/v/gmx;
                $row->{'version'} = $v;
            }
        }
        push @result, $row;
    }

    if(scalar @result == 0) {
        return("no agents found matching '".$filter."'\n", 0) if $filter;
        return("no agents found\n", 0);
    }

    # sort by section and hostname
    my $sorted = Thruk::Backend::Manager::sort_result($c, \@result, { 'ASC' => ['section', 'host_name'] });

    my $out = Thruk::Utils::text_table(
        keys => [
                    ['Section',  'section'],
                    ['Hostname', 'host_name'],
                    ['Address',  'address'],
                    ['Site',     'site'],
                    ['Agent',    'agent'],
                    ['Version',  'version'],
                ],
        data => $sorted,
    );

    return($out, 0);
}

##############################################
sub _run_show {
    my($c, $commandoptions, $opt) = @_;

    my $output = "usage: $0 agents show <host>\n";
    my $rc     = 3;

    my $hostname = shift @{$commandoptions} // '';
    if(!$hostname) {
        return($output, $rc);
    }

    my($checks, $checks_num, $hst, $hostobj, undef) = _get_checks($c, $hostname, $opt, 0);
    unless($checks) {
        _error("something went wrong");
        return("", 3);
    }

    if(!$hst && !$hostobj) {
        _error("no host %s (with agent checks) found\n", $hostname);
        return("", 3);
    }
    if(!$hst && $hostobj) {
        _info("host %s has not yet been activated (reload core with -R)\n", $hostname);
    }

    my @result;
    for my $t (qw/new exists obsolete disabled/) {
        for my $chk (@{$checks->{$t}}) {
            $chk->{'type'} = "NEW"      if $t eq 'new';
            $chk->{'type'} = "OBSOLETE" if $t eq 'obsolete';
            next if($t eq 'disabled' && !$opt->{'all'});
            $chk->{'type'} = "UNWANTED" if $t eq 'disabled';
            push @result, $chk;
        }
    }

    my $out = Thruk::Utils::text_table(
        keys => [
                    ['', 'type'],
                    ['Name', 'name'],
                    ['ID', 'id'],
                ],
        data => \@result,
    );

    my $unwanted = scalar @{$checks->{'disabled'}};
    if(!$opt->{'all'} && $unwanted > 0) {
        $out .= sprintf("\nskipped %d unwanted checks, use (--all) to show them all.\n", $unwanted);
    }

    return($out, 0);
}

##############################################
sub _run_add {
    my($c, $commandoptions, $opt, $edit_only) = @_;

    my $output = "usage: $0 agents add <host>|ALL\n";
    my $rc     = 3;

    my $hosts = $commandoptions;
    if(!$hosts || scalar @{$hosts} == 0) {
        return($output, $rc);
    }

    $opt->{'fresh'} = 1 if $opt->{'clear_manual'};

    # expand "ALL" hosts
    if($hosts->[0] eq 'ALL') {
        my $data = $c->db->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ),
                                                'custom_variables' => { '~' => 'AGENT .+' },
                                                ],
                                      columns => [qw/name/],
        );
        $hosts = [];
        for my $hst (@{$data}) {
            push @{$hosts}, $hst->{'name'};
        }
    }

    for my $hostname (@{$hosts}) {
        my $err = Thruk::Utils::Agents::validate_params($hostname, $opt->{'section'});
        if($err) {
            _error($err);
            return("", 2);
        }
    }

    for my $hostname (@{$hosts}) {
        my($out, $rc) = _run_add_host($c, $hostname, $opt, $edit_only);
        print($out."\n");
        if($rc > 0) {
            return("", $rc);
        }

        Thruk::Utils::Agents::remove_orphaned_agent_templates($c);
        Thruk::Utils::Agents::sort_config_objects($c);

        if($c->{'obj_db'}->commit($c)) {
            $c->stash->{'obj_model_changed'} = 1;
        }
        Thruk::Utils::Conf::store_model_retention($c, $c->stash->{'param_backend'});
    }

    my $out = "";
    if(!$opt->{'reload'}) {
        $out .= "\n(use -R to activate changes)\n";
    }
    return($out, 0);
}

##############################################
sub _run_add_host {
    my($c, $hostname, $opt, $edit_only) = @_;

    my($checks, $checks_num, $hst, $hostobj, $data) = _get_checks($c, $hostname, $opt, $edit_only ? 0 : 1);
    if($edit_only) {
        if(!$hostobj) {
            _error("no host found by name: %s", $hostname);
            return("", 3);
        }
        $opt->{'interactive'} = 1;
    }
    if(!$checks) {
        _error("something went wrong");
        return("", 3);
    }

    my $orig_checks   = _build_checks_config($checks);
    my $checks_config = _build_checks_config($checks);
    if($opt->{'interactive'}) {
        my @lines = (
            "# edit host: ".$hostname,
            "#",
            "address: ".($opt->{'address'} // $hostobj->{'conf'}->{'address'}),
            "section: ".($opt->{'section'} // $hostobj->{'conf'}->{'_AGENT_SECTION'}),
            "#",
            "# services:",
            "# short legend: (e)nable - (k)eep - (n)ew - (o)bsolete - (d)isabled - (u)pdate (complete legend at the end of this file)",
            "# state  id                        args             name",
        );
        for my $t (qw/new exists obsolete disabled/) {
            for my $chk (@{$checks->{$t}}) {
                $chk->{'type'} = "n" if $t eq 'new';
                $chk->{'type'} = "o" if $t eq 'obsolete';
                $chk->{'type'} = "k" if $t eq 'exists';
                $chk->{'type'} = "d" if $t eq 'disabled';
                push @lines, sprintf("%-8s %-25s %-15s  # %s", $chk->{'type'}, $chk->{'id'}, ($chk->{'args'}//''), $chk->{'name'});
            }
        }
        push @lines, "\n";
        push @lines, "# legend:";
        push @lines, "# e - enable,   enable this check";
        push @lines, "# k - keep,     keep this check, no changes";
        push @lines, "# n - new,      check will be listed as new in the inventory";
        push @lines, "# o - obsolete, keep obsolete check";
        push @lines, "# d - disabled, check is unwanted";
        push @lines, "# u - update,   check will be recreated with current defaults";
        my $text = join("\n", @lines);
        my(undef, $filename)     = File::Temp::tempfile();
        Thruk::Utils::IO::write($filename, $text);
        # start default editor for this file
        my $editor = $ENV{'editor'} // "vim";
        system("$editor $filename");
        $checks_config = _build_checks_config($checks);
        for my $line (Thruk::Utils::IO::read_as_list($filename)) {
            next if $line =~ m/^\#/mx;
            $line =~ s/\#.*$//gmx;
            $line =~ s/\s*$//gmx;
            $line =~ s/^\s*//gmx;
            next if $line =~ m/^\s*$/mx;
            my($m, $id, $args) = split(/\s+/mx, $line, 3);
            next unless defined $m;
            if($m eq 'k')    { $checks_config->{'check.'.$id} = "keep"; }
            elsif($m eq 'e') { $checks_config->{'check.'.$id} = "on"; }
            elsif($m eq 'd') { $checks_config->{'check.'.$id} = "off"; }
            elsif($m eq 'n') { $checks_config->{'check.'.$id} = "new"; }
            elsif($m eq 'o') { $checks_config->{'check.'.$id} = "keep"; }
            elsif($m eq 'u') { $checks_config->{'check.'.$id} = "on"; }
            elsif($m eq 'address:') { $data->{'address'} = $id; next; }
            elsif($m eq 'section:') { $data->{'section'} = $id; next; }

            $checks_config->{'args.'.$id} = $args = $args;
        }
    } else {
        # none-interactive - set all new to enabled automatically
        if(scalar @{$checks->{'new'}} == 0 && !$opt->{'fresh'}) {
            return(sprintf("no new checks found for host %s - %d existing checks found, use (-i) to edit them.\n", $hostname, $checks_num), 0);
        }
        for my $chk (@{$checks->{'new'}}) {
            $checks_config->{"check.".$chk->{'id'}} = "on";
        }
    }

    my $class   = Thruk::Utils::Agents::get_agent_class($data->{'type'});
    my $agent   = $class->new();
    my($objects, $remove) = $agent->get_config_objects($c, $data, $checks_config, $opt->{'fresh'});
    my @result;
    for my $obj (@{$objects}) {
        my $file = Thruk::Controller::conf::get_context_file($c, $obj, $obj->{'_filename'});
        my $oldfile = $obj->{'file'};
        if(defined $file && $file->{'readonly'}) {
            _error("cannot write to %s, file is marked readonly\n", $file->{'display'});
            return("", 2);
        }
        if(!$oldfile) {
            $obj->set_file($file);
            $obj->set_uniq_id($c->{'obj_db'});
        } elsif($oldfile->{'path'} ne $file->{'path'}) {
            $c->{'obj_db'}->move_object($obj, $file);
        }
        # build output
        if($obj->{'conf'}->{'service_description'}) {
            my $id = $obj->{'conf'}->{'_AGENT_AUTO_CHECK'};
            my $change = "";
            if($orig_checks->{'check.'.$id} ne $checks_config->{'check.'.$id}) {
                $change = sprintf("%s -> %s", $orig_checks->{'check.'.$id}, $checks_config->{'check.'.$id});
            }
            elsif($obj->{'_prev_conf'} && !_deep_compare($obj->{'_prev_conf'}, $obj->{'conf'}, {"use" => 0 })) {
                $change = "updated";
            }
            push @result, {
                'id'      => $id,
                'name'    => $obj->{'conf'}->{'service_description'},
                '_change' => $change,
            } if $change;
        } elsif($obj->{'conf'}->{'host_name'}) {
            if($data->{'address'} && $data->{'address'} ne $obj->{'conf'}->{'address'}) {
                push @result, {
                    'id'      => '',
                    'name'    => $obj->{'conf'}->{'host_name'},
                    '_change' => sprintf("ip updated: %s -> %s", $obj->{'conf'}->{'address'}, $data->{'address'}),
                };
                $obj->{'conf'}->{'address'} = $data->{'address'};
            } elsif($obj->{'_prev_conf'} && !_deep_compare($obj->{'_prev_conf'}, $obj->{'conf'})) {
                push @result, {
                    'id'      => "_HOST_",
                    'name'    => $obj->{'conf'}->{'host_name'},
                    '_change' => "updated",
                };
            }
        }
        if(!$c->{'obj_db'}->update_object($obj, $obj->{'conf'}, $obj->{'comments'}, 1)) {
            _error("unable to save changes");
            return("", 2);
        }
    }

    for my $obj (@{$remove}) {
        $c->{'obj_db'}->delete_object($obj);
        # build output
        if($obj->{'conf'}->{'service_description'}) {
            my $id = $obj->{'conf'}->{'_AGENT_AUTO_CHECK'};
            push @result, {
                'id'      => $id,
                'name'    => $obj->{'conf'}->{'service_description'},
                '_change' => sprintf("%s -> off", $orig_checks->{'check.'.$id}),
            };
        }
    }

    return(sprintf("no changes made.\n"), 0) if scalar @result == 0;

    # build result table
    my $out = Thruk::Utils::text_table(
        keys => [['', '_change'],
                 ['Name', 'name'],
                 ['ID', 'id'],
                ],
        data => \@result,
    );
    print($out."\n");
    return("", 0);
}

##############################################
sub _run_remove {
    my($c, $commandoptions, $opt, $global_options) = @_;

    my $output = "usage: $0 agents rm <host>\n";
    my $rc     = 3;

    my $hosts = $commandoptions;
    if(!$hosts || scalar @{$hosts} == 0) {
        return($output, $rc);
    }

    for my $hostname (@{$hosts}) {
        my($checks, $checks_num, $hst, $hostobj) = _get_checks($c, $hostname, $opt, 0);
        if(!$hostobj) {
            return(sprintf("no host found by name: %s\n", $hostname), 0) if $global_options->{'force'};
            _error("no host found by name: %s", $hostname);
            return("", 3);
        }

        if(!$global_options->{'yes'}) {
            _info("Really  remove host: %s", $hostname);
            _info("(use -y to skip this message)");
            my $rc = _user_confirm();
            $global_options->{'yes'} = 1 if($rc && lc($rc) eq 'a');
            return("canceled\n", 1) unless $rc;
        }

        my $backend = $hst->{'peer_key'} // _get_backend($c);
        Thruk::Utils::Agents::remove_host($c, $hostname, $backend);
        printf("host %s removed successsfully\n", $hostname);
    }

	my $out = "";
    if(!$opt->{'reload'}) {
        $out .= "\n(use -R to activate changes)\n";
    }
    return($out, 0);
}

##############################################
sub _check_inventory {
    my($c, $hostname, $opt) = @_;
    if(!$hostname) {
        return("usage: $0 agents check inventory <host>\n", 3);
    }

    my $t1 = [gettimeofday];

    my($checks, $checks_num, $hst, $hostobj) = _get_checks($c, $hostname, $opt, 1);
    return(sprintf("UNKNOWN - no host found with enabled agent and name: %s\n", $hostname), 3) unless $hst;
    return(sprintf("UNKNOWN - no host found by name: %s\n", $hostname), 3) unless $hostobj;

    my $elapsed  = tv_interval($t1);
    my $perfdata = sprintf("duration=%ss;;;0; checks=%d;;;0; new=%d;;;0; obsolete=%d;;;0; disabled=%d;;;0;",
        $elapsed,
        scalar @{$checks->{'exists'} // []},
        scalar @{$checks->{'new'} // []},
        scalar @{$checks->{'obsolete'} // []},
        scalar @{$checks->{'disabled'} // []},
        );
    if(scalar @{$checks->{'new'}} > 0) {
        my @details;
        for my $chk (@{$checks->{'new'}}) {
            push @details, " - ".$chk->{'name'};
        }
        return(sprintf("WARNING - %s new check%s found|%s\n%s\n",
            scalar @{$checks->{'new'}},
            (scalar @{$checks->{'new'}} != 1 ? 's' : ''),
            $perfdata,
            join("\n", @details),
        ), 1);
    }

    my @details;
    for my $chk (@{$checks->{'disabled'}}) {
        push @details, " - ".$chk->{'name'};
    }
    my $detail = "";
    if(scalar @details > 0) {
        $detail = "unwanted checks:\n".join("\n", @details);
    }
    return(sprintf("OK - inventory unchanged|%s\n%s\n", $perfdata, $detail), 0);
}

##############################################
sub _get_backend {
    my($c) = @_;
    my $peers = $c->db->get_peers();
    if(@{$peers} == 1) {
        return($peers->[0]->peer_key());
    }

    my($backends) = $c->db->select_backends();
    if(@{$backends} == 1) {
        return($backends->[0]);
    }

    my $type            = Thruk::Utils::Agents::default_agent_type($c);
    my $default_backend = $c->config->{'Thruk::Agents'}->{lc($type)}->{'default_backend'};
    if($default_backend) {
        if($default_backend eq 'LOCAL') {
            $peers = $c->db->get_local_peers();
            if(@{$peers} == 1) {
                return($peers->[0]->peer_key());
            }
        } else {
            my $peer = $c->db->get_peer_by_key($default_backend);
            if($peer) {
                return($peer->peer_key());
            }
        }
    }

    die("must specify backend (-b) if there are more than one.");
}

##############################################
sub _get_checks {
    my($c, $hostname, $opt, $update) = @_;
    my $port;
    if($hostname =~ s/:\d+$//mx) {
        $port = $1;
    }

    my $hosts = $c->db->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ),
                                            'custom_variables' => { '~' => 'AGENT .+' },
                                            'name' => $hostname,
                                            ],
    );
    my $hostobj;
    my $hst = {};
    if($hosts && scalar @{$hosts} > 0) {
        $hst = $hosts->[0];
        Thruk::Utils::Agents::set_object_model($c, $hst->{'peer_key'});
        my $objects = $c->{'obj_db'}->get_objects_by_name('host', $hostname);
        if($objects && scalar @{$objects} > 0) {
            $hostobj = $objects->[0];
        }
    } else {
        my $backend = _get_backend($c);
        Thruk::Utils::Agents::set_object_model($c, $backend);
        my $objects = $c->{'obj_db'}->get_objects_by_name('host', $hostname);
        if($objects && scalar @{$objects} > 0) {
            $hostobj = $objects->[0];
        }
    }
    my $backend = $hst->{'peer_key'} // _get_backend($c);
    my $vars    = Thruk::Utils::get_custom_vars($c, $hst);

    my $type    = $opt->{'type'} // $vars->{'AGENT'} // Thruk::Utils::Agents::default_agent_type($c);
    $port       = $port // $opt->{'port'} // $vars->{'AGENT_PORT'} // Thruk::Utils::Agents::default_port($type);
    my $mode    = $vars->{'AGENT_MODE'} // 'https';
    if($opt->{'insecure'}) {
        $mode = 'insecure';
    }

    my $data = {
        'type'     => $type,
        'hostname' => $hostname,
        'backend'  => $backend,
        'section'  => $opt->{'section'} // '',
        'password' => $opt->{'password'},
        'mode'     => $mode,
        'port'     => $port,
        'ip'       => $opt->{'address'} || $hst->{'address'},
    };
    if($hostobj) {
        $data->{'ip'}       = $hostobj->{'conf'}->{'address'}         unless $data->{'ip'};
        $data->{'password'} = $hostobj->{'conf'}->{'_AGENT_PASSWORD'} unless $data->{'password'};
        if($opt->{'clear_manual'}) {
            # remove manual disabled settings
            my $settings = $hostobj->{'conf'}->{'_AGENT_CONFIG'} ? decode_json($hostobj->{'conf'}->{'_AGENT_CONFIG'}) : {};
            delete $settings->{'disabled'};
            my $json = Cpanel::JSON::XS->new->canonical;
            $hostobj->{'conf'}->{'_AGENT_CONFIG'} = $json->encode($settings);
        }
    }

    if($update) {
        if($hostobj) {
            my($inv, $err) = Thruk::Utils::Agents::update_inventory($c, $hostname, $hostobj, $data);
            die($err) if $err;
        } else {
            my $err     = Thruk::Utils::Agents::scan_agent($c, $data);
            die($err) if $err;
        }
    }

    my($checks, $checks_num) = Thruk::Utils::Agents::get_agent_checks_for_host($c, $backend, $hostname, $hostobj, $type, $opt->{'fresh'}, $data->{'section'});
    return($checks, $checks_num, $hst->{'peer_key'} ? $hst : undef, $hostobj, $data);
}

##############################################
sub _user_confirm {
    _infos("Continue? (y)es - (a)ll - (n)o: ");

    ## no critic
    if(!-t 0) {
        _warn("no terminal, cannot ask for confirmation");
        return;
    }
    ## use critic
    my $has_readkey = 0;
    eval {
        require Term::ReadKey;
        Term::ReadKey->import();
        $has_readkey = 1;
    };
    _debug("has readkey support: ".$has_readkey);

    my $key;
    if($has_readkey) {
        local $SIG{'INT'} = sub {
            ReadMode(1); # restore
            _info("canceled");
            exit(1);
        };
        ReadMode('cbreak');
        sysread STDIN, $key, 1;
        ReadMode(1); # restore
        _info($key);
    } else {
        sysread STDIN, $key, 1;
    }
    chomp ($key);
    if($key =~ m/^(y|j|a)/mxi) {
        _info("");
        return($1);
    }
    return;
}

##############################################
sub _build_checks_config {
    my($checks) = @_;
    my $checks_config = {};

    for my $t (qw/new exists obsolete disabled/) {
        for my $chk (@{$checks->{$t}}) {
            $chk->{'_type'} = $t;
            $chk->{'type'} = "new"  if $t eq 'new';
            $chk->{'type'} = "keep" if $t eq 'obsolete';
            $chk->{'type'} = "keep" if $t eq 'exists';
            $chk->{'type'} = "off"  if $t eq 'disabled';
            $checks_config->{"check.".$chk->{'id'}} = $chk->{'type'};
        }
    }

    return($checks_config);
}

##############################################
sub _deep_compare {
    my($obj1, $obj2, $skip_keys) = @_;

    # check type
    return if(ref $obj1 ne ref $obj2);

    if(ref $obj1 eq 'ARRAY') {
        # check size of array
        return if(scalar @{$obj1} ne scalar @{$obj2});

        for(my $x = 0; $x < scalar @{$obj1}; $x++) {
            return if(!_deep_compare($obj1->[$x], $obj2->[$x], $skip_keys));
        }

        return 1;
    }

    if(ref $obj1 eq 'HASH') {
        # check size of array
        return if(scalar keys %{$obj1} ne scalar keys %{$obj2});
        for my $key (sort keys %{$obj1}) {
            next if $skip_keys && exists $skip_keys->{$key};
            return if(!exists $obj2->{$key});
            return if(!_deep_compare($obj1->{$key}, $obj2->{$key}, $skip_keys));
        }
        return 1;
    }

    return($obj1 eq $obj2);
}

##############################################

=head1 EXAMPLES

Run inventory check for host localhost

  %> thruk agents check inventory localhost

Show all checks for host localhost

  %> thruk agents show --all localhost

Add new host localhost, edit checks interactivly and reload afterwards

  %> thruk agents -IiR localhost

See 'thruk agents help' for more help.

=cut

##############################################

1;
