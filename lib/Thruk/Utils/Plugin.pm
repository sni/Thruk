package Thruk::Utils::Plugin;

=head1 NAME

Thruk::Utils::Plugin - Handles plugin related things

=head1 DESCRIPTION

Plugins Utilities Collection for Thruk

=cut

use strict;
use warnings;
use File::Slurp qw/read_file/;
#use Thruk::Timer qw/timing_breakpoint/;

##############################################

=head1 METHODS

=head2 get_plugins

  get_plugins()

returns list of available plugins

=cut
sub get_plugins {
    my($c) = @_;
    my $project_root         = $c->config->{home};
    my $plugin_dir           = $c->config->{'plugin_path'} || $project_root."/plugins";
    my $plugin_enabled_dir   = $plugin_dir.'/plugins-enabled';
    my $plugin_available_dir = $project_root.'/plugins/plugins-available';

    my $plugins = {};
    for my $addon (glob($plugin_available_dir.'/*/'), glob($plugin_enabled_dir.'/*/')) {
        my($addon_name, $dir) = nice_addon_name($addon);
        $plugins->{$dir} = {
                enabled     => 0,
                dir         => $dir,
                description => '(no description available.)',
                url         => '',
                name        => $addon_name,
                writable    => 0,
        };
        my $desc_file = $plugin_available_dir.'/'.$dir.'/description.txt';
        if(-e $plugin_enabled_dir.'/'.$dir.'/description.txt') {
            $desc_file = $plugin_enabled_dir.'/'.$dir.'/description.txt';
        }
        if(-e $desc_file) {
            my $description = read_file($desc_file);
            my $url         = "";
            if($description =~ s/^Url:\s*(.*)$//gmx) { $url = $1; }
            $plugins->{$dir}->{'description'} = $description;
            $plugins->{$dir}->{'url'}         = $url;
        }
    }
    for my $addon (glob($plugin_enabled_dir.'/*/')) {
        my(undef, $dir) = nice_addon_name($addon);
        $plugins->{$dir}->{'enabled'}  = 1;
        $plugins->{$dir}->{'writable'} = 1 if -w $plugin_enabled_dir.'/'.$dir;
    }

    return($plugins);
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
    my $nicename = join(' ', map(ucfirst, split(/_/mx, $dir)));
    return($nicename, $dir);
}

##############################################

=head2 enable_plugin

  enable_plugin($name)

enable plugin by name

=cut
sub enable_plugin {
    my($c, $dir) = @_;

    my $project_root         = $c->config->{home};
    my $plugin_dir           = $c->config->{'plugin_path'} || $project_root."/plugins";
    my $plugin_enabled_dir   = $plugin_dir.'/plugins-enabled';
    my $plugin_available_dir = $project_root.'/plugins/plugins-available';

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
            $plugin_src_dir = '../../../share/thruk/plugins/plugins-available/'.$dir;
        }
        die($plugin_src_dir." does not exist") unless -e $plugin_src_dir;
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
    my $project_root         = $c->config->{home};
    my $plugin_dir           = $c->config->{'plugin_path'} || $project_root."/plugins";
    my $plugin_enabled_dir   = $plugin_dir.'/plugins-enabled';
    if(!-e $plugin_enabled_dir.'/'.$dir) {
        die("plugin ".$dir." is not enabled");
    }
    unlink($plugin_enabled_dir.'/'.$dir) or die($!);
    return;
}

##############################################

1;

__END__

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
