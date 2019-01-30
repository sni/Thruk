package Thruk::Utils::CLI::Plugin;

=head1 NAME

Thruk::Utils::CLI::Plugin - Plugin CLI module

=head1 DESCRIPTION

The cache handles thruk plugins itself.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] plugin <command>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<command>

    Available commands are:

        - list [enabled|all|installed] list all available (or enabled) plugins
        - enable <plugin>           enable this plugin
        - disable <plugin>          disable this plugin
        - search [<pattern>]        search internet plugin registry for plugins
        - update [<plugin>]         update all or specified plugin
        - install <plugin|tarball>  install and enable this plugin
        - remove <plugin>           uninstall and disable this plugin

=back

=cut

use warnings;
use strict;
use Data::Dumper;
use File::Temp qw/tempdir/;
use File::Copy qw/move/;
use Thruk::Utils::Log qw/_error _info _debug _trace/;

##############################################
# no backends required for this command
our $skip_backends = 1;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions, undef, undef, $globaloptions) = @_;
    $c->stats->profile(begin => "_cmd_plugin($action)");

    require Thruk::Utils::Plugin;

    # cache actions
    my $output = "";
    my $rc     = 0;
    my $command = shift @{$commandoptions} || 'help';
    if($command eq 'list') {
        if(!defined $commandoptions->[0]) {
            push @{$commandoptions}, 'local';
        }
        ($output, $rc) = _plugin_search($c, $commandoptions, $globaloptions);
    }
    elsif($command eq 'enable') {
        my $name = shift @{$commandoptions};
        eval {
            Thruk::Utils::Plugin::enable_plugin($c, $name);
        };
        if($@) {
            return("enabling plugin failed: ".$@, 1);
        }
        return("enabled plugin ".$name."\nYou need to restart the webserver to make the changes active.\n", 0);
    }
    elsif($command eq 'disable') {
        my $name = shift @{$commandoptions};
        eval {
            Thruk::Utils::Plugin::disable_plugin($c, $name);
        };
        if($@) {
            return("disabling plugin failed: ".$@, 1);
        }
        return("disabled plugin ".$name."\nYou need to restart the webserver to make the changes active.\n", 0);
    }
    elsif($command eq 'install') {
        ($output, $rc) = _plugin_install($c, $commandoptions, $globaloptions);
    }
    elsif($command eq 'remove') {
        ($output, $rc) = _plugin_remove($c, $commandoptions);
    }
    elsif($command eq 'search') {
        ($output, $rc) = _plugin_search($c, $commandoptions, $globaloptions);
    }
    elsif($command eq 'update') {
        ($output, $rc) = _plugin_update($c, $commandoptions, $globaloptions);
    }
    else {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    $c->stats->profile(end => "_cmd_plugin($action)");
    return($output, $rc);
}

##############################################
sub _get_plugin_list_header {
    return(sprintf("%-8s %-20s %-15s %-40s\n", "Enabled", "Name", "Version", "Description").('-'x100)."\n");
}

##############################################
sub _get_plugin_list_entry {
    my($plugin) = @_;
    my $output = sprintf("%-8s %-20s %-15s %-40s\n",
                       $plugin->{'enabled'} ? 'E' : ($plugin->{'installed'} ? ' I' : ''),
                       $plugin->{'dir'},
                       ($plugin->{'version'} || 'core'),
                       (split(/\n/mx, $plugin->{'description'}))[0],
                    );
    return($output);
}

##############################################
sub _plugin_search {
    my($c, $commandoptions, $globaloptions) = @_;
    my $output = "";
    my $search = shift @{$commandoptions};
    $search = 'all' unless $search;

    # add local plugins
    my $plugins = [values %{Thruk::Utils::Plugin::get_plugins($c)}];
    # get remote plugins
    if($search !~ m/^(local|enabled|installed)$/mx) {
        my $remote_plugins = Thruk::Utils::Plugin::get_online_plugins($c, $globaloptions->{'force'});
        push @{$plugins}, @{$remote_plugins};
    }

    my $dups = {};
    for my $plugin (sort _plugin_sort @{$plugins}) {
        if($search =~ /^(all|local|enabled|installed)$/mx || $plugin->{'name'} =~ m/\Q$search\E/gmxi || $plugin->{'dir'} =~ m/\Q$search\E/gmxi || $plugin->{'description'} =~ m/\Q$search\E/gmxi) {
            next if $search eq 'enabled' && !$plugin->{'enabled'};
            next if $search eq 'installed' && !$plugin->{'installed'};
            if(!$dups->{$plugin->{'dir'}}->{$plugin->{'version'}}) {
                $output .= _get_plugin_list_entry($plugin);
                $dups->{$plugin->{'dir'}}->{$plugin->{'version'}} = 1;
            }
        }
    }
    if($output) {
        $output = _get_plugin_list_header().$output;
    } else {
        $output = "nothing found for '".$search."'\n";
    }
    return($output, 0);
}

##############################################
sub _plugin_install {
    my($c, $commandoptions, $globaloptions) = @_;

    my $name = shift @{$commandoptions};
    if(!$name) {
        return("usage: $0 plugin install <name|tarball>\n", 1);
    }

    return("ERROR: bogus plugin name\n", 1) unless Thruk::Utils::Plugin::verify_plugin_name($name);

    my($output, $rc, $plugin) = _do_plugin_install($c, $name, $globaloptions);
    if($rc != 0) {
        return($output, $rc);
    }

    _debug("enabling plugin");
    Thruk::Utils::Plugin::enable_plugin($c, $plugin->{'dir'});

    return("Installed ".$plugin->{'name'}." ".$plugin->{'version'}." successfully\nYou need to restart the webserver to make the changes active.\n", 0);
}

##############################################
sub _do_plugin_install {
    my($c, $name, $globaloptions) = @_;

    # check/create available folder
    my(undef, $plugin_available_dir) = Thruk::Utils::Plugin::get_plugin_paths($c);
    if($ENV{'OMD_ROOT'}) {
        $plugin_available_dir = $ENV{'OMD_ROOT'}.'/etc/thruk/plugins-available';
        Thruk::Utils::IO::mkdir($plugin_available_dir);
    }
    if(! -w $plugin_available_dir) {
        return("ERROR: cannot write to $plugin_available_dir\n", 1);
    }

    # create tmp folder
    my $tmpdir = tempdir( CLEANUP => 1 );

    my $tarball;
    if(-e $name) {
        # install from file
        $tarball = $name;
    } else {
        my $plugin;
        # get remote plugins
        my $plugins = Thruk::Utils::Plugin::get_online_plugins($c, $globaloptions->{'force'});
        for my $p (sort _plugin_sort @{$plugins}) {
            if($p->{'name'} eq $name) {
                $plugin = $p;
                last;
            }
        }
        if(!$plugin) {
            return("no plugin name '$name' found\n", 1);
        }
        my $url = $plugin->{'tarball'};
        _debug("fetching ".$url);
        my @res = Thruk::Utils::CLI::request_url($c, $url);
        if($res[0] != 200) {
            _error("Url ".$url." returned code: ".$res[0]);
            _debug(Dumper(\@res));
            return("installation failed\n", 1);
        }
        $tarball = $tmpdir.'/'.$plugin->{'name'}.'.tar.gz';
        Thruk::Utils::IO::write($tarball, $res[1]->{'result'});
    }
    _debug("inspecting tarball");
    my $tar_out = Thruk::Utils::IO::cmd($c, ["tar", "tvfz", $tarball]);
    my $root = {};
    for my $line (split/\n/mx, $tar_out) {
        my @info = split(/\s+/mx, $line, 6);
        my $path = $info[5];
        if($path =~ m/^\//mx) {
            `rm -rf $tmpdir`;
            return("ERROR: tarball must not contain files with leading /: ".$path."\n", 1);
        }
        if($path =~ m/^\./mx && $path !~ m/^\.\//mx) {
            `rm -rf $tmpdir`;
            return("ERROR: tarball must not contain files with relative path: ".$path."\n", 1);
        }
        my @path = split(/\//mx, $path);
        if($path[0] eq '.') {
            $root->{$path[1]} = 1;
        } else {
            $root->{$path[0]} = 1;
        }
    }
    if(scalar keys %{$root} != 1) {
        `rm -rf $tmpdir`;
        return("ERROR: tarball must contain exactly one folder\n", 1);
    }

    _debug("unpacking");
    Thruk::Utils::IO::cmd($c, ["tar", "xfz", $tarball, "-C", $tmpdir]);
    $root = $tmpdir.'/'.(keys %{$root})[0];
    move($root, $tmpdir.'/'.$name);
    $root = $tmpdir.'/'.$name;
    my $plugin = Thruk::Utils::Plugin::read_plugin_details($root);

    # do we overwrite an existing plugin?
    if(!$globaloptions->{'force'} && -e $plugin_available_dir.'/'.$plugin->{'dir'}) {
        my $existing = Thruk::Utils::Plugin::read_plugin_details($plugin_available_dir.'/'.$plugin->{'dir'});
        if(Thruk::Utils::version_compare($existing->{'version'}, $plugin->{'version'})) {
            `rm -rf $tmpdir`;
            return("ERROR: plugin does update existing installed ".$existing->{'dir'}." (".$existing->{'version'}.")"." plugin, use --force to reinstall.\n", 1);
        }
    }

    my $target = $plugin_available_dir.'/'.$plugin->{'dir'};
    `rm -rf $target`;
    if(-e  $target) {
        `rm -rf $tmpdir`;
        return("ERROR: could not remove existing folder prior installation: $target\n", 1);
    }
    move($root, $target) or die("cannot move ".$root.' to '.$target.": $!");

    # cleanup
    `rm -rf $tmpdir`;

    return("OK", 0, $plugin);
}

##############################################
sub _plugin_remove {
    my($c, $commandoptions) = @_;

    my $name = shift @{$commandoptions};
    if(!$name) {
        return("usage: $0 plugin install <name|tarball>\n", 1);
    }
    return("ERROR: bogus plugin name\n", 1) unless Thruk::Utils::Plugin::verify_plugin_name($name);

    my($plugin_enabled_dir, $plugin_available_dir) = Thruk::Utils::Plugin::get_plugin_paths($c);
    if(-d $plugin_enabled_dir.'/'.$name) {
        eval {
            Thruk::Utils::Plugin::disable_plugin($c, $name);
        };
        if($@) {
            return("disabling plugin failed: ".$@, 1);
        }
    }

    if($ENV{'OMD_ROOT'} && -d $ENV{'OMD_ROOT'}.'/etc/thruk/plugins-available/'.$name) {
        $plugin_available_dir = $ENV{'OMD_ROOT'}.'/etc/thruk/plugins-available';
    }

    if(! -w $plugin_available_dir) {
        return("ERROR: cannot write to $plugin_available_dir\n", 1);
    }

    my $plugin_dir = $plugin_available_dir.'/'.$name;
    `rm -rf $plugin_dir`;
    if(-d $plugin_dir) {
        return("Removing plugin ".$name." failed\n", 1);
    }

    return("Removed plugin ".$name." successfully\nYou need to restart the webserver to make the changes active.\n", 0);
}

##############################################
sub _plugin_update {
    my($c, $commandoptions, $globaloptions) = @_;

    my $name = shift @{$commandoptions};

    # add local plugins
    my $local_plugins = [values %{Thruk::Utils::Plugin::get_plugins($c)}];

    # get remote plugins
    my $remote_plugins = Thruk::Utils::Plugin::get_online_plugins($c, $globaloptions->{'force'});

    my $updated = 0;
    for my $plugin (sort _plugin_sort @{$local_plugins}) {
        if($plugin->{'installed'}) {
            next if($name && $plugin->{'dir'} ne $name);
            next unless $plugin->{'version'}; # skip internal core plugins
            for my $remote (sort _plugin_sort @{$remote_plugins}) {
                next unless $plugin->{'dir'} eq $remote->{'dir'};
                if($remote->{'version'} ne $plugin->{'version'} && Thruk::Utils::version_compare($remote->{'version'}, $plugin->{'version'})) {
                    _info("updating plugin ".$plugin->{'dir'}." from version ".$plugin->{'version'}.' to '.$remote->{'version'});
                    _do_plugin_install($c, $plugin->{'dir'}, $globaloptions);
                    $updated++;
                }
            }
        }
    }
    if($updated) {
        return($updated." plugins successfully updated\n", 0);
    }
    return("no updates available\n", 0);
}

##############################################
sub _plugin_sort {
    return($a->{'dir'} cmp $b->{'dir'} || $b->{'installed'} <=> $a->{'installed'} || Thruk::Utils::version_compare($a->{'version'}, $b->{'version'}));
}

##############################################

=head1 EXAMPLES

List all available plugins

  %> thruk plugin list

Enable config tool plugin

  %> thruk plugin enable conf

=cut

##############################################

1;
