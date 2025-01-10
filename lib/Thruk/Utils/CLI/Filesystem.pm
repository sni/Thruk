package Thruk::Utils::CLI::Filesystem;

=head1 NAME

Thruk::Utils::CLI::Filesystem - CLI module to synchronize var filesystem

=head1 DESCRIPTION

This module provides a CLI interface to synchronize the var filesystem.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] filesystem <command>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<command>

    Available commands are:

        - list                  list all files
        - cat <file>            print file content to STDOUT
        - sync <from> <to>      sync files from db to fs or the other way round
        - import [options]      alias for "sync fs db"
        - export [options]      alias for "sync db fs"
        - drop                  removes the var_path database

      options:

       --delete                 delete files on target which do not exist on source


=back

=cut

use warnings;
use strict;
use Getopt::Long ();

use Thruk::Utils::CLI ();
use Thruk::Utils::IO ();
use Thruk::Utils::Log qw/:all/;

##############################################
# no backends required for this command
our $skip_backends = 1;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions, $data) = @_;
    $c->stats->profile(begin => "_cmd_filesystem($action)");

    if(!$c->check_user_roles('authorized_for_admin')) {
        return("ERROR - authorized_for_admin role required\n", 1);
    }

    if(! $c->config->{'var_path_db'}) {
        return("ERROR - var_path_db must be enabled\n", 1);
    }

    # parse options
    my $opts = {
        delete => undef,
    };
    Getopt::Long::Configure('pass_through');
    Getopt::Long::GetOptionsFromArray($commandoptions,
         "delete"           => \$opts->{'delete'},
    ) || do {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    };

    # cache actions
    my $command = shift @{$commandoptions} || 'help';
    my($rc, $out) = (3, 'UNKNOWN command');
    if($command eq 'cat') {
        ($rc, $out) = _cmd_cat($c, $commandoptions);
    } elsif($command eq 'list') {
        ($rc, $out) = _cmd_list($c);
    } elsif($command eq 'import') {
        ($rc, $out) = _cmd_sync($c, ['fs', 'db', @{$commandoptions}], $opts);
    } elsif($command eq 'export') {
        ($rc, $out) = _cmd_sync($c, ['db', 'fs', @{$commandoptions}], $opts);
    } elsif($command eq 'sync') {
        ($rc, $out) = _cmd_sync($c, $commandoptions, $opts);
    } elsif($command eq 'drop') {
        ($rc, $out) = _cmd_drop($c);
    } else {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    $data->{'rc'}     = $rc;
    $data->{'output'} = $out;

    $c->stats->profile(end => "_cmd_filesystem($action)");
    return($data);
}

##############################################
sub _cmd_list {
    my($c) = @_;
    my $files = Thruk::Utils::IO::find_files($c->config->{'var_path'});
    my $out = join("\n", sort @{$files})."\n";
    return(0, $out);
}

##############################################
sub _cmd_cat {
    my($c, $commandoptions) = @_;
    my $file = shift @{$commandoptions};
    if(!$file) {
        return(1, "ERROR - missing file\n");
    }
    my $content = Thruk::Utils::IO::saferead($file);
    if(!defined $content) {
        return(1, "ERROR - not read file: $!\n");
    }
    return(0, $content);
}

##############################################
sub _cmd_drop {
    my($c) = @_;

    Thruk::Utils::IO::handle_io("_drop_tables", 0, $c->config->{'var_path'}, \@_);

    return(0, "OK - tables dropped\n");
}

##############################################
sub _cmd_sync {
    my($c, $commandoptions, $opts) = @_;
    my $from = shift @{$commandoptions};
    my $to   = shift @{$commandoptions};
    if(!$from || !$to) {
        return(3, "usage: filesystem sync <from> <to>\n");
    }

    my $action;
    $action = 'export' if $from eq 'db';
    $action = 'import' if $from eq 'fs';
    if(!$action) {
        return(3, "usage: filesystem sync <from> <to>\n");
    }
    if($action eq 'import' && $to ne 'db') {
        return(3, "usage: filesystem sync <from> <to>\n");
    }
    if($action eq 'export' && $to ne 'fs') {
        return(3, "usage: filesystem sync <from> <to>\n");
    }

    Thruk::Utils::IO::sync_db_fs($c, $from, $to, $opts);

    return(0, "");
}

##############################################

=head1 EXAMPLES

List all files:

  %> thruk filesystem list

Display specific file content:

  %> thruk filesystem cat VAR::/cluster/nodes

=cut

##############################################

1;
