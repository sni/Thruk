package Thruk::Utils::CLI::Agents;

=head1 NAME

Thruk::Utils::CLI::Agents - Agents CLI module

=head1 DESCRIPTION

The agents command handles agent configs.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] agents [cmd]

=head1 OPTIONS

=over 4

  help              print help and exit
  check  | -C       run checks, ex. inventory
  show   | -S       show checks for host
  add    | -I       add/inventory new host
  rm     | -D       delete existing host
  reload | -R       reload monitoring core

  -i                interactive mode (available in edit/add mode)
  --all             show all items   (available in show mode)
  -P | --password   set password     (available in add mode)
  -p | --port       set tcp port     (available in add mode)


=back

=cut

use warnings;
use strict;
use File::Temp ();
use Getopt::Long ();
use Time::HiRes qw/gettimeofday tv_interval/;

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
        'type'        => undef,
        'reload'      => undef,
        'check'       => undef,
        'show'        => undef,
        'edit'        => undef,
        'remove'      => undef,
    };
    Getopt::Long::Configure('no_ignore_case');
    Getopt::Long::Configure('bundling');
    Getopt::Long::Configure('pass_through');
    Getopt::Long::GetOptionsFromArray($commandoptions,
       "all"          => \$opt->{'all'},
       "i"            => \$opt->{'interactive'},
       "p|port=i"     => \$opt->{'port'},
       "P|password=s" => \$opt->{'password'},
       "T|type=s"     => \$opt->{'type'},
       "S|show"       => \$opt->{'show'},
       "C|check"      => \$opt->{'check'},
       "R|reload"     => \$opt->{'reload'},
       "I|add"        => \$opt->{'add'},
       "E|edit"       => \$opt->{'edit'},
       "D|remove"     => \$opt->{'remove'},
    ) or do {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    };

    my $action;
    if($opt->{'add'})    { $action = "add"; }
    if($opt->{'edit'})   { $action = "edit"; }
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
sub _run_show {
    my($c, $commandoptions, $opt) = @_;

    my $output = "usage: $0 agents show <host>\n";
    my $rc     = 3;

    my $hostname = shift @{$commandoptions} // '';
    if(!$hostname) {
        return($output, $rc);
    }

    my($checks, $checks_num, $hst, $hostobj) = _get_checks($c, $hostname, $opt, 0);
    return("something went wrong", 3) unless $checks;

    if(!$hst) {
        return(sprintf("no host %s (with agent checks) found", $hostname), 3)
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

    my($checks, $checks_num, $hst, $hostobj) = _get_checks($c, $hostname, $opt, $edit_only ? 0 : 1);
    if($edit_only) {
        return(sprintf("no host found by name: %s\n", $hostname), 3) unless $hostobj;
    }
    return("something went wrong", 3) unless $checks;

    if($opt->{'interactive'}) {
        my @lines = (
            "# set checks into desired states (legend is at the end of the file):"
        );
        for my $t (qw/new exists obsolete disabled/) {
            for my $chk (@{$checks->{$t}}) {
                $chk->{'type'} = "n" if $t eq 'new';
                $chk->{'type'} = "o" if $t eq 'obsolete';
                $chk->{'type'} = "k" if $t eq 'exists';
                $chk->{'type'} = "d" if $t eq 'disabled';
                push @lines, sprintf("%-4s %-25s %s", $chk->{'type'}, $chk->{'id'}, $chk->{'name'});
            }
        }
        push @lines, "# legend:";
        push @lines, "# k - keep,     keep this check";
        push @lines, "# n - new,      check will be listed as new in the inventory";
        push @lines, "# o - obsolete, keep obsolete check";
        push @lines, "# d - disabled, check is unwanted";
        my $text = join("\n", @lines);
        my(undef, $filename)     = File::Temp::tempfile();
        Thruk::Utils::IO::write($filename, $text);
        # start default editor for this file
        my $editor = $ENV{'editor'} // "vim";
        system("$editor $filename");
    }

    my $out = Thruk::Utils::text_table(
        keys => [['Name', 'name'],
                    ['ID', 'id'],
                ],
        data => $checks->{'new'},
    );
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
        return(sprintf("WARNING - %s new checks found|%s\n%s\n",
            scalar @{$checks->{'new'}},
            $perfdata,
            join("\n", @details),
        ), 2);
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
        return($backends);
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
    }
    my $backend = $hst->{'peer_key'} // _get_backend($c);

    my $type    = $opt->{'type'} // $hst->{'_AGENT'} // Thruk::Utils::Agents::default_agent_type($c);
    $port       = $port // $opt->{'port'} // Thruk::Utils::Agents::default_port($type);
    if($update) {
        if($hostobj) {
            my($inv, $err) = Thruk::Utils::Agents::update_inventory($c, $hostname, $hostobj);
            die($err) if $err;
        } else {
            my $err     = Thruk::Utils::Agents::scan_agent($c, {
                'type'      => $type,
                'hostname'  => $hostname,
                'ip'        => $hst->{'address'},
                'password'  => $opt->{'password'},
                'backend'   => $backend,
                'port'      => $port,
            });
            die($err) if $err;
        }
    }

    my($checks, $checks_num) = Thruk::Utils::Agents::get_agent_checks_for_host($c, $backend, $hostname, $hostobj, $type);
    return($checks, $checks_num, $hst->{'peer_key'} ? $hst : undef, $hostobj);
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
