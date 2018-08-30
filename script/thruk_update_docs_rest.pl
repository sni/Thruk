#!/usr/bin/env perl

use warnings;
use strict;
use File::Slurp qw/read_file/;
use Cpanel::JSON::XS qw/encode_json/;
use Data::Dumper;

use Thruk::Utils::CLI;
use Thruk::Controller::rest_v1;

################################################################################
my $c = Thruk::Utils::CLI->new()->get_c();
Thruk::Utils::set_user($c, '(cli)');
$c->stash->{'is_admin'} = 1;
$c->config->{'cluster_enabled'} = 1; # fake cluster
$c->app->cluster->register($c);
$c->app->cluster->load_statefile();
$c->sub_request('/r/config/objects', 'POST', {':TYPE' => 'host', ':FILE' => 'docs-update-test.cfg', 'name' => 'docs-update-test'});

_update_cmds($c);
_update_docs($c, "docs/documentation/rest.asciidoc");
_update_docs($c, "docs/documentation/rest_commands.asciidoc");
unlink('var/cluster/nodes');
$c->sub_request('/r/config/revert', 'POST', {});
exit 0;

################################################################################
sub _update_cmds {
    my($c) = @_;
    my $output_file = "lib/Thruk/Controller/Rest/V1/cmd.pm";
    my $content = read_file($output_file);
    $content =~ s/^__DATA__\n.*$/__DATA__\n/gsmx;

    my $input_files = [glob(join(" ", (
                        $c->config->{'project_root'}."/templates/cmd/*.tt",
                        $c->config->{'plugin_path'}."/plugins-enabled/*/templates/cmd/*.tt",
                    )))];

    my $cmds = {};
    for my $file (@{$input_files}) {
        next if $file =~ m/cmd_typ_c\d+/gmx;
        my $nr;
        if($file =~ m/cmd_typ_(\d+)\./gmx) {
            $nr = $1;
        }
        my $template = read_file($file);
        next if $template =~ m/enable_shinken_features/gmx;
        my @matches = $template =~ m%^\s*([A-Z_]+)\s*(;|$|)(.*sprintf.*|$)%gmx;
        die("got no command in ".$file) if scalar @matches == 0;
        my $require_comments = $template =~ m/require_comments_for_disable_cmds/gmx ? 1 : 0;
        while(scalar @matches > 0) {
            my $name = shift @matches;
            shift @matches;
            my $arg  = shift @matches;
            my $cmd = {
                name => lc $name,
            };
            my @args;
            if($arg) {
                if($arg =~ m/"\s*,([^\)]+)\)/gmx) {
                    @args = split(/\s*,\s*/mx, $1);
                } else {
                    die("cannot parse arguments in ".$file);
                }
            }
            my @required_args;
            if(my @req = $template =~ m/class='(optBoxRequiredItem|optBoxItem)'>(?:.*?):<\/td>.*?input\s+type='.*?'\s+name='(.*?)'/gmx ) {
                while ( scalar @req > 0 ) {
                    my $req  = shift @req;
                    my $key  = shift @req;
                    if($req eq 'optBoxRequiredItem') {
                        # unfortunatly naming is different, so we need to translate some names
                        $key = 'triggered_by'       if $key eq 'trigger';
                        $key = 'comment_data'       if $key eq 'com_data';
                        $key = 'comment_data'       if $key eq 'com_data_disable_cmd';
                        $key = 'comment_author'     if $key eq 'com_author';
                        $key = 'persistent_comment' if $key eq 'persistent';
                        $key = 'sticky_ack'         if $key eq 'sticky';
                        $key = 'notification_time'  if $key eq 'not_dly';
                        $key = 'downtime_id'        if $key eq 'down_id';
                        $key = 'comment_id'         if $key eq 'com_id';
                        # some are required but have defaults, so they are not strictly required
                        next if $key eq 'comment_author';
                        next if $key eq 'start_time';
                        next if $key eq 'end_time';

                        # comment_data is a false positive if comments are added to other commands
                        next if($require_comments && $key eq 'comment_data');
                        push @required_args, $key;
                    }
                }
            }

            next if $require_comments && $cmd->{'name'} =~ m/add_.*_comment/;

            map {s/_unix$//gmx; } @args;
            if($args[0] && $args[0] eq 'host_name') {
                shift @args;
                shift @required_args;
                if($args[0] && $args[0] eq 'service_desc') {
                    shift @args;
                    shift @required_args;
                    $cmds->{'services'}->{$cmd->{'name'}} = $cmd;
                } else {
                    $cmds->{'hosts'}->{$cmd->{'name'}} = $cmd;
                }
            }
            elsif($args[0] && $args[0] eq 'hostgroup_name') {
                shift @args;
                shift @required_args;
                $cmds->{'hostgroups'}->{$cmd->{'name'}} = $cmd;
            }
            elsif($args[0] && $args[0] eq 'servicegroup_name') {
                shift @args;
                shift @required_args;
                $cmds->{'servicegroups'}->{$cmd->{'name'}} = $cmd;
            } else {
                $cmds->{'system'}->{$cmd->{'name'}} = $cmd;
            }
            $cmd->{'args'}     = \@args;
            $cmd->{'required'} = \@required_args;
            # sanity check, there should not be any required parameters which cannot be found in the args list
            my $args_hash = Thruk::Utils::array2hash(\@args);
            for my $r (@required_args) {
                die("cannot find required $r in args list for file: ".$file) unless $args_hash->{$r};
            }
            $cmd->{'requires_comment'} = 1 if $require_comments;
            $cmd->{'nr'} = $nr;
        }
    }

    for my $category (qw/hosts services hostgroups servicegroups system/) {
        for my $name (sort keys %{$cmds->{$category}}) {
            my $cmd = $cmds->{$category}->{$name};
            if($category =~ m/^(hosts|hostgroups|servicegroups)$/mx) {
                $content .= "# REST PATH: POST /$category/<name>/cmd/$name\n";
            }
            elsif($category =~ m/^(services)$/mx) {
                $content .= "# REST PATH: POST /$category/<host>/<service>/cmd/$name\n";
            }
            elsif($category =~ m/^(system)$/mx) {
                $content .= "# REST PATH: POST /$category/cmd/$name\n";
            }
            $content .= "# Sends the ".uc($name)." command.\n#\n";
            if(scalar @{$cmd->{'args'}} > 0) {
                my $optional = [];
                my $required = Thruk::Utils::array2hash($cmd->{'required'});
                for my $a (@{$cmd->{'args'}}) {
                    next if $required->{$a};
                    push @{$optional}, $a;
                }
                if(scalar @{$cmd->{'required'}} > 0) {
                    $content .= "# Required arguments:\n#\n#   * ".join("\n#   * ", @{$cmd->{'required'}})."\n";
                    if(scalar @{$optional} > 0) {
                        $content .= "#\n";
                    }
                }
                if(scalar @{$optional} > 0) {
                    $content .= "# Optional arguments:\n#\n#   * ".join("\n#   * ", @{$optional})."\n";
                }
            } else {
                $content .= "# This command does not require any arguments.\n";
            }
            $content .= "#\n";
            $content .= "# See http://www.naemon.org/documentation/developer/externalcommands/$name.html for details.\n";
            $content .= "\n";
        }
    }

    my $cmd_dump = Cpanel::JSON::XS->new->utf8->canonical->encode($cmds);
    $cmd_dump    =~ s/\},/},\n  /gmx;
    $cmd_dump    =~ s/\ *"(hostgroups|hosts|services|servicegroups|system)":\{/"$1":{\n  /gmx;
    $cmd_dump    =~ s/\}$/\n}/gmx;
    $cmd_dump    =~ s/\}\},$/}\n},/gmx;
    $content .= $cmd_dump;

    $output_file = 'cmd.pm.tst' if $ENV{'TEST_MODE'};
    open(my $fh, '>', $output_file) or die("cannot write to ".$output_file.': '.$@);
    print $fh $content;
    close($fh);
}

################################################################################
sub _update_docs {
    my($c, $output_file) = @_;

    my($paths, $keys, $docs) = Thruk::Controller::rest_v1::get_rest_paths();
    Thruk::Utils::get_fake_session($c);
    `mkdir -p bp;            cp t/scenarios/cli_api/omd/1.tbp bp/9999.tbp`;
    `mkdir -p panorama;      cp t/scenarios/cli_api/omd/1.tab panorama/9999.tab`;
    `mkdir -p var/broadcast; cp t/scenarios/rest_api/omd/broadcast.json var/broadcast/broadcast.json`;
    `mkdir -p var/downtimes; cp t/scenarios/cli_api/omd/1.tsk var/downtimes/9999.tsk`;
    `mkdir -p var/reports;   cp t/scenarios/cli_api/omd/1.rpt var/reports/9999.rpt`;

    my $content    = read_file($output_file);
    my $attributes = _parse_attribute_docs($content);
    $content =~ s/^(\QSee examples and detailed description for\E.*?:).*$/$1\n\n/gsmx;

    for my $url (sort keys %{$paths}) {
        if($output_file =~ m/_commands/mx) {
            next if $url !~ m%/cmd/%mx;
        } else {
            next if $url =~ m%/cmd/%mx;
        }
        for my $proto (sort _sort_by_proto (keys %{$paths->{$url}})) {
            $content .= "=== $proto $url\n\n";
            my $doc   = $docs->{$url}->{$proto} ? join("\n", @{$docs->{$url}->{$proto}})."\n\n" : '';
            $content .= $doc;

            if(!$keys->{$url}->{$proto}) {
                $keys->{$url}->{$proto} = _fetch_keys($c, $proto, $url, $doc);
            }
            if(!$keys->{$url}->{$proto} && $attributes->{$url}->{$proto}) {
                $keys->{$url}->{$proto} = [];
                for my $key (sort keys %{$attributes->{$url}->{$proto}}) {
                    push @{$keys->{$url}->{$proto}}, [$key, $attributes->{$url}->{$proto}->{$key}];
                }
            }
            if($keys->{$url}->{$proto}) {
                $content .= '[options="header"]'."\n";
                $content .= "|===========================================\n";
                $content .= sprintf("|%-33s | %s\n", 'Attribute', 'Description');
                for my $doc (@{$keys->{$url}->{$proto}}) {
                    my $desc = ($doc->[1] || $attributes->{$url}->{$proto}->{$doc->[0]} || '' );
                    if(!$desc && $doc->[0] eq 'peer_key') {
                        $desc = "backend id when having multiple sites connected";
                    }
                    printf(STDERR "WARNING: no documentation on url %s for attribute %s\n", $url, $doc->[0]) unless $desc;
                    $content .= sprintf("|%-33s | %s\n", $doc->[0], $desc);
                }
                $content .= "|===========================================\n\n\n";
            }
        }
    }

    # trim trailing whitespace
    $content =~ s/\ +$//gmx;

    $output_file = $output_file.'.tst' if $ENV{'TEST_MODE'};
    open(my $fh, '>', $output_file) or die("cannot write to ".$output_file.': '.$@);
    print $fh $content;
    close($fh);

    unlink('bp/9999.tbp');
    unlink('panorama/9999.tab');
    unlink('var/broadcast/broadcast.json');
    unlink('var/downtimes/9999.tsk');
    unlink('var/reports/9999.rpt');
    unlink($c->stash->{'fake_session_file'});
}

################################################################################
sub _fetch_keys {
    my($c, $proto, $url, $doc) = @_;

    return if $proto ne 'GET';
    return if $doc =~ m/alias|https?:/mxi;
    return if $url eq '/thruk/reports/<nr>/report';
    return if $url eq '/thruk/cluster/heartbeat';
    return if $url eq '/thruk/config';
    return if $url eq '/config/objects';
    return if($url eq '/lmd/sites' && !$ENV{'THRUK_USE_LMD'});
    return if $doc =~ m/see\ /mxi;

    my $keys = [];
    $c->{'rendered'} = 0;
    $c->req->parameters->{'limit'} = 1;
    print STDERR "fetching keys for ".$url."\n";
    my $tst_url = $url;
    $tst_url =~ s|<nr>|9999|gmx;
    $tst_url =~ s|<id>|$Thruk::NODE_ID|gmx if $tst_url =~ m%/cluster/%mx;
    Thruk::Action::AddDefaults::_set_enabled_backends($c);
    my $data = Thruk::Controller::rest_v1::_process_rest_request($c, $tst_url);
    if($data && ref($data) eq 'ARRAY' && $data->[0] && ref($data->[0]) eq 'HASH') {
        for my $k (sort keys %{$data->[0]}) {
            next if $k =~ m/^tabpan/mx;
            push @{$keys}, [$k, ""];
        }
    }
    elsif($data && ref($data) eq 'HASH' && !$data->{'code'}) {
        for my $k (sort keys %{$data}) {
            push @{$keys}, [$k, ""];
        }
    }
    else {
        print STDERR "ERROR: got no usable data in url ".$tst_url."\n".Dumper($data);
        return;
    }
    return $keys;
}

################################################################################
sub _sort_by_proto {
    my $weight = {
        'GET'    => 1,
        'POST'   => 2,
        'PATCH'  => 3,
        'DELETE' => 4,
    };
    ($weight->{$a}//99) <=> ($weight->{$b}//99);
}

################################################################################
sub _parse_attribute_docs {
    my($content) = @_;
    my $attributes = {};
    my($url, $proto);
    for my $line (split/\n/mx, $content) {
        if($line =~ m%^=%mx) {
            $url = undef;
        }
        if($line =~ m%^===\ (\w+)\ (/.*)$%mx) {
            $proto = $1;
            $url   = $2;
        }
        if($url && $line =~ m%^\|([^\|]+?)\s*\|\s*(.*)$%mx) {
            next if $1 eq 'Attribute';
            $attributes->{$url}->{$proto}->{$1} = $2;
        }
    }
    return $attributes;
}
################################################################################
