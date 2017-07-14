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

        - list                  list all available plugins
        - enable <plugin>       enable this plugin
        - disable <plugin>      disable this plugin
        - search <patter>       search internet plugin registry for plugins
        - install <plugin>      install and enable this plugin
        - update [<plugin>]     update all or specified plugin

=back

=cut

use warnings;
use strict;
use Thruk::Utils::Log qw/_error _info _debug _trace/;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions) = @_;
    $c->stats->profile(begin => "_cmd_plugin($action)");

    require Thruk::Utils::Plugin;

    # cache actions
    my $output = "";
    my $rc     = 0;
    my $command = shift @{$commandoptions} || 'help';
    if($command eq 'list') {
        my $plugins  = Thruk::Utils::Plugin::get_plugins($c);
        $output .= sprintf("%-7s %-20s %-40s\n", "Active", "Name", "Description");
        $output .= ('-'x100)."\n";
        for my $name (sort keys %{$plugins} ) {
            my $plugin = $plugins->{$name};
            $output .= sprintf("%-7s %-20s %-40s\n",
                               $plugin->{'enabled'} ? 'X' : '',
                               $plugin->{'dir'},
                               (split(/\n/mx, $plugin->{'description'}))[0],
                            );
        }
    }
    elsif($command eq 'enable') {
        my $name = shift @{$commandoptions};
        eval {
            Thruk::Utils::Plugin::enable_plugin($c, $name);
        };
        if($@) {
            return("enabling plugin failed: ".$@, 1);
        }
        return("enabled plugin ".$name."\nYou need to restart the webserver to make the changes active.", 0);
    }
    elsif($command eq 'disable') {
        my $name = shift @{$commandoptions};
        eval {
            Thruk::Utils::Plugin::disable_plugin($c, $name);
        };
        if($@) {
            return("disabling plugin failed: ".$@, 1);
        }
        return("disabled plugin ".$name."\nYou need to restart the webserver to make the changes active.", 0);
    }
    elsif($command eq 'install') {
        return("not implemented yet", 1);
    }
    elsif($command eq 'search') {
        return("not implemented yet", 1);
    }
    elsif($command eq 'update') {
        return("not implemented yet", 1);
    }
    else {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    $c->stats->profile(end => "_cmd_plugin($action)");
    return($output, $rc);
}

##############################################

=head1 EXAMPLES

List all available plugins

  %> thruk plugin list

Enable config tool plugin

  %> thruk plugin enable conf

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
