package Thruk::BP::Utils;

use strict;
use warnings;
use File::Temp qw/tempfile/;
use File::Copy qw/move/;
use File::Slurp qw/read_file/;
use Carp;

use Thruk::Utils::Filter;
use Thruk::BP::Components::BP;
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::BP::Utils - Helper for the business process addon

=head1 DESCRIPTION

Helper for the business process addon

=head1 METHODS

=cut

##########################################################

=head2 load_bp_data

    load_bp_data($c, [$num], [$editmode], [$drafts], [$backend_id])

editmode:
    - 0/undef:    no edit mode
    - 1:          only edit mode

drafts:
    - 0/undef:    skip drafts
    - 1:          load drafts too

load all or specific business process

=cut
sub load_bp_data {
    my($c, $num, $editmode, $drafts, $backend_id) = @_;

    # make sure our folders exist
    my $base_folder = bp_base_folder($c);
    Thruk::Utils::IO::mkdir_r($c->config->{'var_path'}.'/bp');
    Thruk::Utils::IO::mkdir_r($base_folder);

    my $bps       = [];
    my $pattern   = '*.tbp';
    my $svcfilter = { 'custom_variables' => { '>=' => "THRUK_BP_ID 0" }};
    if($num) {
        return($bps) unless $num =~ m/^\d+$/mx;
        $pattern   = $num.'.tbp';
        $svcfilter = { 'custom_variables' => { '=' => "THRUK_BP_ID ".$num }};
    }

    # check permissions
    my $is_admin = 0;
    my $allowed  = {};
    if($c->check_user_roles("admin")) {
        $is_admin = 1;
    } else {
        my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $svcfilter ], columns => ['custom_variable_names', 'custom_variable_values'] );
        for my $s (@{$services}) {
            my $vars = Thruk::Utils::get_custom_vars($c, $s);
            if($vars->{'THRUK_BP_ID'}) {
                $allowed->{$vars->{'THRUK_BP_ID'}} = 1;
            }
        }
    }

    my $numbers = {};
    my @files   = glob($base_folder.'/'.$pattern);
    for my $file (@files) {
        my $nr = $file;
        $nr =~ s|^.*/(\d+)\.tbp$|$1|mx;
        next if(!$is_admin && !$allowed->{$nr});
        my $bp = Thruk::BP::Components::BP->new($c, $file, undef, $editmode);
        if($bp) {
            if($backend_id) {
                if(!$bp->{'bp_backend'} || $bp->{'bp_backend'} ne $backend_id) {
                    next;
                }
            }
            push @{$bps}, $bp;
            $bp->{'remote'} = 0;
            $numbers->{$bp->{'id'}} = 1;
        }
    }
    if($drafts) {
        # load drafts too
        my @files = glob($c->config->{'var_path'}.'/bp/*.tbp.edit');
        for my $file (@files) {
            my $nr = $file;
            $nr =~ s|^.*/(\d+)\.tbp\.edit$|$1|mx;
            next if $numbers->{$nr};
            next if(!$is_admin && !$allowed->{$nr});
            next if $num && $num != $nr;
            $file  = $base_folder.'/'.$nr.'.tbp';
            my $bp = Thruk::BP::Components::BP->new($c, $file, undef, 1);
            if($bp) {
                $bp->{'remote'} = 0;
                push @{$bps}, $bp;
                $numbers->{$bp->{'id'}} = 1;
            }
        }
    }

    # sort by name
    @{$bps} = sort { $a->{'name'} cmp $b->{'name'} } @{$bps};

    return($bps);
}

##########################################################

=head2 next_free_bp_file

    next_free_bp_file($c)

return next free bp file

=cut
sub next_free_bp_file {
    my($c) = @_;
    my $num = 1;
    my $base_folder = bp_base_folder($c);
    Thruk::Utils::IO::mkdir_r($c->config->{'var_path'}.'/bp');
    Thruk::Utils::IO::mkdir_r($base_folder);
    while(-e $base_folder.'/'.$num.'.tbp' || -e $c->config->{'var_path'}.'/bp/'.$num.'.tbp.edit') {
        $num++;
    }
    return($base_folder.'/'.$num.'.tbp', $num);
}

##########################################################

=head2 make_uniq_label

    make_uniq_label($c, $label, $bp_id)

returns new uniq label

=cut
sub make_uniq_label {
    my($c, $label, $bp_id) = @_;

    # gather names of all BPs and editBPs
    my $names = {};
    my @files = glob(bp_base_folder($c).'/*.tbp '.$c->config->{'var_path'}.'/bp/*.tbp.edit');
    for my $file (@files) {
        next if $bp_id and $file =~ m#/$bp_id\.tbp(.edit|)$#mx;
        my $data = Thruk::Utils::IO::json_lock_retrieve($file);
        $names->{$data->{'name'}} = 1;
    }

    my $num = 2;
    my $testlabel = $label;
    while(defined $names->{$testlabel}) {
        $testlabel = $label.' '.$num++;
    }

    return $testlabel;
}

##########################################################

=head2 update_bp_status

    update_bp_status($c, $bps)

update status of all given business processes

=cut
sub update_bp_status {
    my($c, $bps) = @_;
    for my $bp (@{$bps}) {
        $bp->update_status($c);
    }
    return;
}

##########################################################

=head2 save_bp_objects

    save_bp_objects($c, $bps, [$skip_reload])

save business processes objects to object file

=cut
sub save_bp_objects {
    my($c, $bps, $skip_reload) = @_;

    my $file   = $c->config->{'Thruk::Plugin::BP'}->{'objects_save_file'};
    my $format = $c->config->{'Thruk::Plugin::BP'}->{'objects_save_format'} || 'nagios';
    if($format ne 'icinga2') { $format = 'nagios'; }
    return(0, 'no \'objects_save_file\' set') unless $file;

    my($rc, $msg) = (0, 'reload ok');
    my $obj = {'hosts' => {}, 'services' => {}};
    for my $bp (@{$bps}) {
        my $data = $bp->get_objects_conf();
        merge_obj_hash($obj, $data);
    }

    my($fh, $filename) = tempfile();
    _debug(sprintf("writing objects to %s", $filename));
    binmode($fh, ":encoding(UTF-8)");
    print $fh "########################\n";
    print $fh "# thruk: readonly\n";
    print $fh "# don't change, file is generated by thruk and will be overwritten.\n";
    print $fh "########################\n\n\n";
    if($format eq 'nagios') {
        print $fh _get_nagios_objects($c, $obj);
    }
    elsif($format eq 'icinga2') {
        print $fh _get_icinga2_objects($c, $obj);
    }

    Thruk::Utils::IO::close($fh, $filename);

    my $new_hex = Thruk::Utils::Crypt::hexdigest(scalar read_file($filename));
    my $old_hex = -f $file ? Thruk::Utils::Crypt::hexdigest(scalar read_file($file)) : '';

    # check if something changed
    if($new_hex ne $old_hex) {
        _debug(sprintf("moving %s to %s", $filename, $file));
        if(!move($filename, $file)) {
            return(1, 'move '.$filename.' to '.$file.' failed: '.$!);
        }
        my $result_backend = $c->config->{'Thruk::Plugin::BP'}->{'result_backend'};
        if(!$result_backend && $Thruk::Backend::Pool::peer_order && scalar @{$Thruk::Backend::Pool::peer_order}) {
            my $peer_key = $Thruk::Backend::Pool::peer_order->[0];
            $result_backend = $c->{'db'}->get_peer_by_key($peer_key)->peer_name;
        }

        if($skip_reload) {
            return(0, "bp objects written, reload skipped.");
        }

        # and reload
        my $time = time();
        my $pkey;
        if($result_backend) {
            my $peer = $c->{'db'}->get_peer_by_key($result_backend);
            if($peer) {
                $pkey = $peer->peer_key();
                if(!$c->stash->{'has_proc_info'} || !$c->stash->{'backend_detail'}->{$pkey}) {
                    Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_SAFE_DEFAULTS);
                }
                if(!defined $c->stash->{'backend_detail'}->{$pkey} || !$c->stash->{'backend_detail'}->{$pkey}->{'running'}) {
                    return(0, "reload skipped, backend offline");
                }
            }
        }
        my $cmd = $c->config->{'Thruk::Plugin::BP'}->{'objects_reload_cmd'};
        my $reloaded = 0;
        if($cmd) {
            ($rc, $msg) = Thruk::Utils::IO::cmd($c, $cmd." 2>&1");
            $reloaded = 1;
        }
        elsif($result_backend) {
            # restart by livestatus
            die("no backend found by name ".$result_backend) unless $pkey;
            my $options = {
                'command' => sprintf("COMMAND [%d] RESTART_PROCESS", time()),
                'backend' => [ $pkey ],
            };
            $c->{'db'}->send_command( %{$options} );
            ($rc, $msg) = (0, 'business process saved and core restarted');
            $reloaded = 1;
        }
        if($rc == 0 && $reloaded) {
            my $core_reloaded = Thruk::Utils::wait_after_reload($c, $pkey, $time-1);
            if(!$core_reloaded) {
                ($rc, $msg) = (1, 'business process saved but core failed to restart');
            }
        }
    } else {
        _debug(sprintf("no differences in %s and %s", $filename, $file));
        # discard file
        unlink($filename);
        $msg = "no reload required";
    }

    return($rc, $msg);
}

##########################################################

=head2 clean_function_args

    clean_function_args($args)

return clean args from a string

=cut
sub clean_function_args {
    my($args) = @_;
    return([]) unless defined $args;
    my @newargs = $args =~ m/('.*?'|".*?"|\d+)/gmx;
    for my $arg (@newargs) {
        $arg =~ s/^'(.*)'$/$1/mx;
        $arg =~ s/^"(.*)"$/$1/mx;
        if($arg =~ m/^(\d+|\d+.\d+)$/mx) {
            $arg = $arg + 0; # make it a real number
        }
    }
    return(\@newargs);
}

##########################################################

=head2 clean_orphaned_edit_files

  clean_orphaned_edit_files($c, [$threshold])

remove old edit files

=cut
sub clean_orphaned_edit_files {
    my($c, $threshold) = @_;
    $threshold = 86400 unless defined $threshold;
    my $base_folder = bp_base_folder($c);
    for my $pattern (qw/edit runtime/) {
    my @files = glob($c->config->{'var_path'}.'/bp/*.tbp.'.$pattern);
        for my $file (@files) {
            $file =~ m/\/(\d+)\.tbp\.$pattern/mx;
            if($1 && !-e $base_folder.'/'.$1.'.tbp') {
                my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
                next if $mtime > (time() - $threshold);
                unlink($file);
            }
        }
    }
    return;
}

##########################################################

=head2 update_cron_file

  update_cron_file($c)

update reporting cronjobs

=cut
sub update_cron_file {
    my($c) = @_;

    my $rate = int($c->config->{'Thruk::Plugin::BP'}->{'refresh_interval'} || 1);
    if($rate <  1) { $rate =  1; }
    if($rate > 60) { $rate = 60; }

    # gather reporting send types from all reports
    my $cron_entries = [];
    my @files = glob(bp_base_folder($c).'/*.tbp');
    if(scalar @files > 0) {
        open(my $fh, '>>', $c->config->{'var_path'}.'/cron.log');
        Thruk::Utils::IO::close($fh, $c->config->{'var_path'}.'/cron.log');
        my $cmd = sprintf("cd %s && %s '%s bp all' >/dev/null 2>>%s/cron.log",
                                $c->config->{'project_root'},
                                $c->config->{'thruk_shell'},
                                $c->config->{'thruk_bin'},
                                $c->config->{'var_path'},
                        );
        push @{$cron_entries}, ['* * * * *', $cmd] if $rate == 1;
        push @{$cron_entries}, ['*/'.$rate.' * * * *', $cmd] if $rate != 1;
    }

    # disable calculations by setting refresh_interval or workers to zero
    if(defined $c->config->{'Thruk::Plugin::BP'}->{'refresh_interval'} && $c->config->{'Thruk::Plugin::BP'}->{'refresh_interval'} == 0
      || defined $c->config->{'Thruk::Plugin::BP'}->{'worker'} && $c->config->{'Thruk::Plugin::BP'}->{'worker'} == 0) {
          $cron_entries = [];
    }

    Thruk::Utils::update_cron_file($c, 'business process', $cron_entries);
    return 1;
}

##########################################################

=head2 get_custom_functions

  get_custom_functions($c)

returns list of custom functions

=cut
sub get_custom_functions {
    my($c) = @_;

    # get required files
    my $functions = [];
    my @files = glob(bp_base_folder($c).'/*.pm');
    for my $filename (@files) {
        next unless -s $filename;
        my $f = _parse_custom_functions($filename, 'function$');
        push @{$functions}, @{$f};
    }
    return $functions;
}

##########################################################

=head2 get_custom_filter

  get_custom_filter($c)

returns list of custom filter

=cut
sub get_custom_filter {
    my($c) = @_;

    # get required files
    my $functions = [];
    my @files = glob(bp_base_folder($c).'/*.pm');
    for my $filename (@files) {
        next unless -s $filename;
        my $f = _parse_custom_functions($filename, 'filter$');
        push @{$functions}, @{$f};
    }

    # sort by name
    @{$functions} = sort { $a->{'name'} cmp $b->{'name'} } @{$functions};

    return $functions;
}

##########################################################
sub _parse_custom_functions {
    my($filename, $filter) = @_;

    my $functions = [];
    my $last_help = "";
    my $last_args = [];

    open(my $fh, '<', $filename);
    while(my $line = <$fh>) {
        if($line =~ m/^\s*sub\s+([\w_]+)(\s|\{)/mx) {
            my $func = $1;
            my $name = $func;
            $last_help =~ s/^(Input|Output):\s(.*?):?$//mx;
            if($2) {
                $name = $1.": ". $2;
            }
            $name =~ s/:?\s*$//gmx;
            $last_help =~ s/^Arguments:\s$//mx;
            $last_help =~ s/\A\s*//msx;
            $last_help =~ s/\s*\Z//msx;
            if(!$filter || $func =~ m/$filter/mx) {
                push @{$functions}, { function => $func, help => $last_help, file => $filename, args => $last_args, name => $name };
            }
            $last_help = "";
            $last_args = [];
        }
        elsif($line =~ m/^\s*\#\s*arg\d+:\s*(.*)/mx) {
            my($name, $type, $args) = split(/\s*;\s*/mx,$1,3);
            if($type eq 'checkbox' or $type eq 'select') { $args = [split(/\s*;\s*/mx,$args)]; }
            push @{$last_args}, {name => $name, type => $type, args => $args};
        }
        elsif($line =~ m/^\s*\#\ ?(.*?$)/mx) {
            $last_help .= $1."\n";
        }
        elsif($line =~ m/^\s*$/mx) {
            $last_help = "";
            $last_args = [];
        }
    }
    CORE::close($fh);

    return $functions;
}

##########################################################

=head2 join_labels

    join_labels($nodes, [$state])

return string with joined labels

=cut
sub join_labels {
    my($nodes, $state) = @_;
    my @labels;
    for my $n (@{$nodes}) {
        push @labels, $n->{'label'};
    }
    my $num = scalar @labels;
    if($num == 0) {
        return('');
    }
    my $long = "";
    if($state) {
        for my $n (@{$nodes}) {
            my $firstline = "[".$n->{'label'}."] ".Thruk::Utils::Filter::state2text($state);
            $firstline   .= " - ".(split(/\n/mx, $n->{'status_text'}))[0] if $n->{'status_text'};
            $long .= "\n- ".$firstline;
        }
    }
    if($num == 1) {
        return($labels[0].$long);
    }
    if($num == 2) {
        return($labels[0].' and '.$labels[1].$long);
    }
    my $last = pop @labels;
    my $label = join(', ', @labels).' and '.$last;
    if(length($label) > 150) {
        $label = substr($label,0,147).'...';
    }
    return($label.$long);
}

##########################################################

=head2 join_args

    join_args($args)

return string with joined args

=cut
sub join_args {
    my($args) = @_;
    my @arg;
    for my $e (@{$args}) {
        $e = '' unless defined $e;
        if($e =~ m/^(\d+|\d+\.\d+)$/mx) {
            push @arg, $e;
        } else {
            push @arg, "'".$e."'";
        }
    }
    return(join(', ', @arg));
}

##########################################################

=head2 state2text

    state2text($state)

return string of given state

=cut
sub state2text {
    return(Thruk::Utils::Filter::state2text(@_));
}

##########################################################

=head2 hoststate2text

    hoststate2text($state)

return string of given host state

=cut
sub hoststate2text {
    return(Thruk::Utils::Filter::hoststate2text(@_));
}

##########################################################

=head2 merge_obj_hash

    merge_obj_hash($hash, $data)

merge objects hash with more objects

=cut
sub merge_obj_hash {
    my($hash, $data) = @_;

    if(defined $data->{'hosts'}) {
        for my $hostname (keys %{$data->{'hosts'}}) {
            my $host = $data->{'hosts'}->{$hostname};
            $hash->{'hosts'}->{$hostname} = $host;
        }
    }

    if(defined $data->{'services'}) {
        for my $hostname (keys %{$data->{'services'}}) {
            for my $description (keys %{$data->{'services'}->{$hostname}}) {
                my $service = $data->{'services'}->{$hostname}->{$description};
                $hash->{'services'}->{$hostname}->{$description} = $service;
            }
        }
    }
    return($hash);
}

##########################################################

=head2 clean_nasty

    clean_nasty($string)

clean nasty chars from string

=cut
sub clean_nasty {
    my($str) = @_;
    confess("nothing?") unless defined $str;
    $str =~ s#[`~!\$%^&*\|'"<>\?,\(\)=]*##gmxo;
    return($str);
}

##########################################################

=head2 bp_base_folder

    bp_base_folder($c)

return base folder of business process files

=cut
sub bp_base_folder {
    my($c) = @_;
    return(Thruk::Utils::base_folder($c).'/bp');
}

##########################################################
# return objects in nagios format
sub _get_nagios_objects {
    my($c, $obj) = @_;

    my $str = "";
    for my $hostname (sort keys %{$obj->{'hosts'}}) {
        $str .= 'define host {'. "\n";
        my $keys = _get_sorted_keys([keys %{$obj->{'hosts'}->{$hostname}}]);
        for my $attr (@{$keys}) {
            $str .= ' '. $attr. ' '. $obj->{'hosts'}->{$hostname}->{$attr}. "\n";
        }
        $str .= "}\n";
    }
    for my $hostname (sort keys %{$obj->{'services'}}) {
        for my $description (sort keys %{$obj->{'services'}->{$hostname}}) {
            $str .= 'define service {'. "\n";
            my $keys = _get_sorted_keys([keys %{$obj->{'services'}->{$hostname}->{$description}}]);
            for my $attr (@{$keys}) {
                $str .= ' '. $attr. ' '. $obj->{'services'}->{$hostname}->{$description}->{$attr}. "\n"
            }
            $str .= "}\n";
        }
    }

    return($str);
}

##########################################################
# return objects in icinga2 format
sub _get_icinga2_objects {
    my($c, $obj) = @_;

    my $str = "";
    for my $hostname (sort keys %{$obj->{'hosts'}}) {
        $str .= 'object Host "'.$hostname.'" {'. "\n";
        my $keys = _get_sorted_keys([keys %{$obj->{'hosts'}->{$hostname}}]);
        for my $attr (@{$keys}) {
            next if $attr eq 'host_name';
            next if $attr eq 'alias';
            $str .= _get_icinga2_object_attr('host', $attr, $obj->{'hosts'}->{$hostname}->{$attr});
        }
        $str .= "}\n";
    }
    for my $hostname (sort keys %{$obj->{'services'}}) {
        for my $description (sort keys %{$obj->{'services'}->{$hostname}}) {
            $str .= 'object Service "'.$description.'" {'. "\n";
            my $keys = _get_sorted_keys([keys %{$obj->{'services'}->{$hostname}->{$description}}]);
            for my $attr (@{$keys}) {
                next if $attr eq 'service_description';
                next if $attr eq 'alias';
                $str .= _get_icinga2_object_attr('service', $attr, $obj->{'services'}->{$hostname}->{$description}->{$attr});
            }
            $str .= "}\n";
        }
    }

    return($str);
}

##########################################################
sub _get_icinga2_object_attr {
    my($type, $attr, $val) = @_;
    my $key = $attr;
    if($attr =~ m/^_(.*)$/mx) {
        $key = 'vars.'.$1;
    }
    if($attr eq 'use') {
        my @templates = split(/\s*,\s*/mx, $val);
        my $str = "";
        for my $tpl (@templates) {
            $str .= ' import "'.$tpl. "\"\n";
        }
        return($str);
    }
    if($attr =~ m/_interval$/mx) {
        $val = $val.'m';
    }
    return(' '. $key. ' = "'.$val. "\"\n");

}

##########################################################
sub _get_sorted_keys {
    my($keys) = @_;
    eval {
        require Monitoring::Config::Object::Parent;
        require Monitoring::Config;
        Monitoring::Config::set_save_config();
        my @keys = @{Monitoring::Config::Object::Parent::get_sorted_keys(undef, $keys)};
        $keys = \@keys;
    };
    if($@) {
        # do a normal alphanumeric sort otherwise
        $keys = [sort @{$keys}];
    }
    return $keys;
}

##########################################################

=head2 get_nodes_grouped_by_state

    get_nodes_grouped_by_state($c, $nodes, $bp, $aggregation)

return nodes grouped by state, downtime and acknowledged

=cut
sub get_nodes_grouped_by_state {
    my($c, $nodes, $bp, $aggregation) = @_;

    my $groups = {};
    for my $n (@{$nodes}) {
        my $key = lc(Thruk::Utils::Filter::state2text($n->{'status'}));
        if($n->{'acknowledged'} && $n->{'status'} != 0) {
            $key = 'acknowledged_'.$key;
        }
        elsif($n->{'scheduled_downtime_depth'}) {
            $key = 'downtime_'.$key;
        }
        $groups->{$key} = [] unless defined $groups->{$key};
        push @{$groups->{$key}}, $n;
    }

    my $order;
    if($aggregation eq 'worst') {
        $order = $bp->{'default_state_order'};
    } elsif($aggregation eq 'best') {
        $order = [reverse @{$bp->{'default_state_order'}}];
    } else {
        die("unknown aggregation: ".$aggregation);
    }

    for my $state (@{$order}) {
        if($groups->{$state}) {
            my $first = $groups->{$state}->[0];
            my $extra = {};
            if(!defined $c->config->{'Thruk::Plugin::BP'}->{'sync_downtime_ack_state'} || $c->config->{'Thruk::Plugin::BP'}->{'sync_downtime_ack_state'} >= 1) {
                $extra = {
                    'acknowledged'             => $first->{'acknowledged'} // 0,
                    'scheduled_downtime_depth' => $first->{'scheduled_downtime_depth'} // 0,
                };
            }
            return($first->{'status'}, $groups->{$state}, $extra);
        }
    }

    # nothing found
    return(3, [], {});
}

1;
