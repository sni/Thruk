package Thruk::Utils::Plugin;

=head1 NAME

Thruk::Utils::Plugin - Handles plugin related things

=head1 DESCRIPTION

Plugins Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Data::Dumper;
use File::Slurp qw/read_file/;
use Thruk::Utils::Log qw/:all/;
#use Thruk::Timer qw/timing_breakpoint/;

##############################################

=head1 METHODS

=head2 get_plugins

  get_plugins()

returns list of available plugins

=cut
sub get_plugins {
    my($c) = @_;

    my($plugin_enabled_dir, $plugin_available_dir) = get_plugin_paths($c);

    my $plugins = {};
    for my $addon (glob($plugin_available_dir.'/*/'), glob($plugin_enabled_dir.'/*/')) {
        my $plugin = read_plugin_details($addon);
        $plugin->{'installed'} = 1;
        $plugins->{$plugin->{'dir'}} = $plugin;
    }
    for my $addon (glob($plugin_enabled_dir.'/*/')) {
        my(undef, $dir) = nice_addon_name($addon);
        $plugins->{$dir}->{'enabled'}  = 1;
        $plugins->{$dir}->{'writable'} = 1 if -w $plugin_enabled_dir.'/'.$dir;
    }

    return($plugins);
}

##############################################

=head2 get_online_plugins

  get_online_plugins($c, [$force_refresh])

return list of online plugins and local plugins

=cut
sub get_online_plugins {
    my($c, $force_refresh) = @_;
    my $plugins = [];
    my $cache = {};
    my $cache_file = $c->config->{'tmp_path'}.'/plugin_repo.cache';
    if(-e $cache_file) {
        $cache = Thruk::Utils::IO::json_lock_retrieve($cache_file);
    }
    for my $url (@{$c->config->{'plugin_registry_url'}}) {
        if(!$force_refresh && $cache->{$url} && $cache->{$url}->{'time'} > time - 1800) {
            # fetch/update every 30 minutes
            _debug("loaded cached repository for: ".$url);
            next;
        }
        _debug("fetching plugin repository from: ".$url);
        my @res = Thruk::Utils::CLI::request_url($c, $url);
        if($res[0] != 200) {
            _error("Url ".$url." returned code: ".$res[0]);
            _debug(Dumper(\@res));
        } else {
            my $json = Cpanel::JSON::XS->new->utf8;
            $json->relaxed();
            my $data;
            eval {
                $data = $json->decode($res[1]->{'result'});
            };
            if($@) {
                _error("Url ".$url." did not return a plugin list: ".$@);
                _debug(Dumper(\@res));
            }
            elsif(ref $data ne 'ARRAY') {
                _error("Url ".$url." did not return a plugin list");
                _debug(Dumper(\@res));
            } else {
                $cache->{$url} = {
                    time => time(),
                    data => $data,
                }
            }
        }
    }
    Thruk::Utils::IO::json_lock_store($cache_file, $cache);

    for my $url (@{$c->config->{'plugin_registry_url'}}) {
        my $data = $cache->{$url}->{'data'};
        for my $plugin (@{$data}) {
            $plugin->{'repository'} = $url;
            $plugin->{'dir'}        = $plugin->{'name'};
            $plugin->{'name'}       = nice_addon_name($plugin->{'name'});
            $plugin->{'version'}    =~ s/^v//gmx;
            $plugin->{'installed'}  = 0;
        }
        push @{$plugins}, @{$data};
    }

    return($plugins);
}

##############################################

=head2 read_plugin_details

  read_plugin_details($dir)

return details from plugin folder

=cut
sub read_plugin_details {
    my($folder) = @_;
    my($addon_name, $dir) = nice_addon_name($folder);
    my $plugin = {
            enabled     => 0,
            dir         => $dir,
            description => '(no description available.)',
            url         => '',
            name        => $addon_name,
            writable    => 0,
            version     => '',
            repository  => 'local',
    };
    my $desc_file = $folder.'/description.txt';
    if(-e $desc_file) {
        my $description = read_file($desc_file);
        my $url         = "";
        if($description =~ s/^Url:\s*(.*)$//gmx) { $url = $1; }
        $plugin->{'description'} = $description;
        $plugin->{'url'}         = $url;
        if($description =~ s/^Version:\s*(.*)$//gmx) {
            my $version = $1;
            $version =~ s/^v//gmx;
            $plugin->{'version'} = $version;
        }
    }
    return($plugin);
}

##############################################

=head2 nice_addon_name

  nice_addon_name()

return nicer addon name

=cut
sub nice_addon_name {
    my($name) = @_;
    my $dir = $name;
    $dir =~ s/\/+$//gmx;
    $dir =~ s/^.*\///gmx;
    # ex.: thruk-plugin-editor-1.0.0
    if($dir =~ m/^thruk\-plugin\-(.*)\-[\d\.]+$/mx) {
        $dir = $1;
    }
    # ex.: editor-1.0.0
    elsif($dir =~ m/^(.*)\-[\d\.]+$/mx) {
        $dir = $1;
    }
    my $nicename = join(' ', split(/_/mx, $dir));
    return($nicename, $dir);
}

##############################################

=head2 get_plugin_paths

  get_plugin_paths($c)

return path to enabled and available plugins

=cut
sub get_plugin_paths {
    my($c) = @_;

    my $project_root         = $c->config->{home};
    my $plugin_dir           = $c->config->{'plugin_path'} || $project_root."/plugins";
    my $plugin_enabled_dir   = $plugin_dir.'/plugins-enabled';
    my $plugin_available_dir = $project_root.'/plugins/plugins-available';

    return($plugin_enabled_dir, $plugin_available_dir);
}

##############################################

=head2 enable_plugin

  enable_plugin($name)

enable plugin by name

=cut
sub enable_plugin {
    my($c, $dir) = @_;

    my($plugin_enabled_dir, $plugin_available_dir) = get_plugin_paths($c);

    if(-e $plugin_enabled_dir.'/'.$dir) {
        die("plugin ".$dir." is enabled already");
    }
    elsif(!-e $plugin_enabled_dir.'/'.$dir) {
        my $plugin_src_dir = $plugin_available_dir.'/'.$dir;
        # make nicer and maintainable symlinks by not using absolute paths if possible
        if(-d $plugin_enabled_dir.'/../plugins-available/'.$dir) {
            $plugin_src_dir = '../plugins-available/'.$dir;
        }
        elsif($ENV{'OMD_ROOT'}) {
            if(-d $plugin_enabled_dir.'/../plugins-available/'.$dir) {
                $plugin_src_dir = '../plugins-available/'.$dir;
            } else {
                $plugin_src_dir = '../../../share/thruk/plugins/plugins-available/'.$dir;
            }
        }
        die($plugin_src_dir." does not exist") unless -d $plugin_enabled_dir.'/'.$plugin_src_dir;
        symlink($plugin_src_dir,
                $plugin_enabled_dir.'/'.$dir)
            or die("cannot create ".$plugin_enabled_dir.'/'.$dir." : ".$!);
    }

    return;
}

##############################################

=head2 disable_plugin

  disable_plugin()

disable plugin by name

=cut
sub disable_plugin {
    my($c, $dir) = @_;

    my($plugin_enabled_dir) = get_plugin_paths($c);

    if(!-e $plugin_enabled_dir.'/'.$dir) {
        die("plugin ".$dir." is not enabled");
    }
    unlink($plugin_enabled_dir.'/'.$dir) or die($!);
    return;
}

##############################################

=head2 verify_plugin_name

  verify_plugin_name($name)

returns true if this is a valid name for a plugin

=cut
sub verify_plugin_name {
    my($name) = @_;
    if($name =~ m/^[a-zA-Z0-9\-\_]+$/mx) {
        return 1;
    }
    return;
}

##############################################

1;
