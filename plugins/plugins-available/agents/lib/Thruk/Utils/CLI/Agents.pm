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

  - help                    print help and exit
  - check  | -C   <host>    run checks, ex. inventory
  - list   | -l             list agent hosts
  - show   | -S   <host>    show checks for host
  - add    | -I   <host>    add/inventory new/existing host
  - update | -II  <host>    add/inventory new/existing host and freshly apply excludes
  - rm     | -D   <host>    delete existing host
  - reload | -R             reload monitoring core

  -i                interactive mode (available in edit/add mode)
  --all             show all items   (available in show mode)
  -P | --password   set password     (available in add mode)
  -p | --port       set tcp port     (available in add mode)
       --ip         set ip address   (available in add mode)
       --section    set section      (available in add mode)


=back

=cut

use warnings;
use strict;
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
        return("ERROR - authorized_for_admin role required", 1);
    }

    # parse options
    my $opt = {
        'interactive' => undef,
        'port'        => undef,
        'password'    => undef,
        'address'     => undef,
        'type'        => undef,
        'reload'      => undef,
        'check'       => undef,
        'list'        => undef,
        'show'        => undef,
        'edit'        => undef,
        'remove'      => undef,
        'fresh'       => undef,
        'section'     => undef,
    };
    $opt->{'fresh'} = 1 if Thruk::Base::array_contains('-II', $commandoptions);
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
       "E|edit"       => \$opt->{'edit'},
       "D|remove"     => \$opt->{'remove'},
       "ip=s"         => \$opt->{'address'},
       "section=s"    => \$opt->{'section'},
    ) or do {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    };

    my $action;
    if($opt->{'list'})   { $action = "list"; }
    if($opt->{'add'})    { $action = "add"; }
    if($opt->{'edit'})   { $action = "edit"; }
    if($opt->{'fresh'})  { $action = "add"; }
    if($opt->{'show'})   { $action = "show"; }
    if($opt->{'remove'}) { $action = "rm"; }
    if($opt->{'check'})  { $action = "check"; if($commandoptions->[0] ne 'inventory') { unshift(@{$commandoptions}, 'inventory') } }
    if($opt->{'reload'}) { $action = "reload" unless $action; }

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
        return("unknown command, see help for available commands\n", 3);
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
            my $v = $versions->{$hst->{'name'}}->{'plugin_output'};
            $v =~ s/^.*v/v/gmx;
            $row->{'version'} = $v;
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
    return("something went wrong\n", 3) unless $checks;

    if(!$hst && !$hostobj) {
        return(sprintf("no host %s (with agent checks) found\n", $hostname), 3);
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

    my $output = "usage: $0 agents add <host>\n";
    my $rc     = 3;

    my $hostname = shift @{$commandoptions} // '';
    if(!$hostname) {
        return($output, $rc);
    }

    my $err = Thruk::Utils::Agents::validate_params($hostname, $opt->{'section'});
    if($err) {
        return($err, 2);
    }

    my($checks, $checks_num, $hst, $hostobj, $data) = _get_checks($c, $hostname, $opt, $edit_only ? 0 : 1);
    if($edit_only) {
        return(sprintf("no host found by name: %s\n", $hostname), 3) unless $hostobj;
        $opt->{'interactive'} = 1;
    }
    return("something went wrong\n", 3) unless $checks;

    my $orig_checks   = _build_checks_config($checks);
    my $checks_config = _build_checks_config($checks);
    if($opt->{'interactive'}) {
        my @lines = (
            "# set checks into desired states (legend is at the end of the file):",
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

            $checks_config->{'args.'.$id} = $args = $args;
        }
    } else {
        # none-interactive - set all new to enabled automatically
        if(scalar @{$checks->{'new'}} == 0) {
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
            return(sprintf("cannot write to %s, file is marked readonly\n", $file->{'display'}), 2);
        }
        if(!$oldfile) {
            $obj->set_file($file);
            $obj->set_uniq_id($c->{'obj_db'});
        } elsif($oldfile->{'path'} ne $file->{'path'}) {
            $c->{'obj_db'}->move_object($obj, $file);
        }
        if(!$c->{'obj_db'}->update_object($obj, $obj->{'conf'}, "", 1)) {
            return("unable to save changes\n", 2);
        }
        # build output
        if($obj->{'conf'}->{'service_description'}) {
            my $id = $obj->{'conf'}->{'_AGENT_AUTO_CHECK'};
            push @result, {
                'id'      => $id,
                'name'    => $obj->{'conf'}->{'service_description'},
                '_change' => sprintf("%s -> %s", $orig_checks->{'check.'.$id}, $checks_config->{'check.'.$id}),
            };
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

    if($c->{'obj_db'}->commit($c)) {
        $c->stash->{'obj_model_changed'} = 1;
    }
    Thruk::Utils::Conf::store_model_retention($c, $c->stash->{'param_backend'});

    # build result table
    my $out = Thruk::Utils::text_table(
        keys => [['', '_change'],
                 ['Name', 'name'],
                 ['ID', 'id'],
                ],
        data => \@result,
    );
    if(!$opt->{'reload'}) {
        $out .= "\n(use -R to activate changes)\n";
    }
    return($out, 0);
}

##############################################
sub _run_remove {
    my($c, $commandoptions, $opt, $global_options) = @_;

    my $output = "usage: $0 agents rm <host>\n";
    my $rc     = 3;

    my $hostname = shift @{$commandoptions} // '';
    if(!$hostname) {
        return($output, $rc);
    }

    my($checks, $checks_num, $hst, $hostobj) = _get_checks($c, $hostname, $opt, 0);
    return(sprintf("no host found by name: %s\n", $hostname), 3) unless $hostobj;

    if(!$global_options->{'yes'}) {
        _info("Really  remove host: %s", $hostname);
        _info("(use -y to skip this message)");
        return("canceled\n", 1) unless _user_confirm();
    }

    my $backend = $hst->{'peer_key'} // _get_backend($c);
    Thruk::Utils::Agents::remove_host($c, $hostname, $backend);
    return(sprintf("host %s removed successsfully\n", $hostname), 0);
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
    my $perfdata = sprintf("duration=%ss", $elapsed);
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

    my $data = {
        'type'     => $type,
        'hostname' => $hostname,
        'backend'  => $backend,
        'section'  => $opt->{'section'},
        'password' => $opt->{'password'},
        'port'     => $port,
        'ip'       => $opt->{'address'} || $hst->{'address'},
    };
    if($hostobj) {
        $data->{'ip'}       = $hostobj->{'conf'}->{'address'}         unless $data->{'ip'};
        $data->{'password'} = $hostobj->{'conf'}->{'_AGENT_PASSWORD'} unless $data->{'password'};
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

    my($checks, $checks_num) = Thruk::Utils::Agents::get_agent_checks_for_host($c, $backend, $hostname, $hostobj, $type, $opt->{'fresh'});
    return($checks, $checks_num, $hst->{'peer_key'} ? $hst : undef, $hostobj, $data);
}

##############################################
sub _user_confirm {
    _infos("Continue? [n]: ");
    my $buf;
    sysread STDIN, $buf, 1;
    if($buf !~ m/^(y|j)/mxi) {
        return;
    }
    _info("");
    return(1);
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
