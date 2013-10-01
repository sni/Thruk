package Thruk::BP::Utils;

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use File::Temp qw/tempfile/;
use File::Copy qw/move/;
use Thruk::BP::Components::BP;

use Carp;
use Config::General;

=head1 NAME

Thruk::BP::Utils - Helper for the business process addon

=head1 DESCRIPTION

Helper for the business process addon

=head1 METHODS

=cut

##########################################################

=head2 load_bp_data

    load_bp_data($c, [$num], [$editmode])

load all or specific business process

=cut
sub load_bp_data {
    my($c, $num, $editmode) = @_;
    my $bps   = [];
    my $pattern = '*.tbp';
    if($num) {
        return($bps) unless $num =~ m/^\d+$/mx;
        $pattern = $num.'.tbp';
    }
    my @files = glob($c->config->{'home'}.'/bp/'.$pattern);
    for my $file (@files) {
        my $bp = Thruk::BP::Components::BP->new($c, $file, undef, $editmode);
        push @{$bps}, $bp if $bp;
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
    while(-e $c->config->{'home'}.'/bp/'.$num.'.tbp' || -e $c->config->{'var_path'}.'/bp/'.$num.'.tbp.edit') {
        $num++;
    }
    return($c->config->{'home'}.'/bp/'.$num.'.tbp', $num);
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

    save_bp_objects($c, $bps)

save business processes objects to object file

=cut
sub save_bp_objects {
    my($c, $bps) = @_;

    my $file = $c->config->{'Thruk::Plugin::BP'}->{'objects_save_file'};
    return unless $file;

    my($fh, $filename) = tempfile();
    for my $bp (@{$bps}) {
        print $fh $bp->get_objects_string();
    }
    Thruk::Utils::IO::close($fh, $filename);

    my $new_hex = md5_hex($filename);
    my $old_hex = md5_hex($file);

    # check if something changed
    if($new_hex ne $old_hex) {
        move($filename, $file) or die('move failed: '.$!);
        # and reload
        my $cmd = $c->config->{'Thruk::Plugin::BP'}->{'objects_reload_cmd'};
        if($cmd) {
            `$cmd >/dev/null 2>&1 &`;
        }
    } else {
        # discard file
        unlink($filename);
    }

    return;
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
    my @files = glob($c->config->{'var_path'}.'/bp/*.tbp.edit');
    for my $file (@files) {
        my $bpfile = $file;
        $bpfile =~ s/\.edit$//mx;
        $bpfile =~ s/^.*\///mx;
        if(!-e $c->config->{'home'}.'/'.$bpfile) {
            my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
            next if $mtime > (time() - $threshold);
            unlink($file);
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
    my @files = glob($c->config->{'home'}.'/bp/*.tbp');
    if(scalar @files > 0) {
        open(my $fh, '>>', $c->config->{'var_path'}.'/cron.log');
        Thruk::Utils::IO::close($fh, $c->config->{'var_path'}.'/cron.log');
        my $cmd = sprintf("cd %s && %s '%s -a bpd' >/dev/null 2>>%s/cron.log",
                                $c->config->{'project_root'},
                                $c->config->{'thruk_shell'},
                                $c->config->{'thruk_bin'},
                                $c->config->{'var_path'},
                        );
        push @{$cron_entries}, ['* * * * *', $cmd] if $rate == 1;
        push @{$cron_entries}, ['*/'.$rate.' * * * *', $cmd] if $rate != 1;
    }

    Thruk::Utils::update_cron_file($c, 'reports', $cron_entries);
    return 1;
}

##########################################################

=head2 join_labels

    join_labels($nodes)

return string with joined labels

=cut
sub join_labels {
    my($nodes) = @_;
    my @labels;
    for my $n (@{$nodes}) {
        push @labels, $n->{'label'};
    }
    my $num = scalar @labels;
    if($num == 0) {
        return('');
    }
    if($num == 1) {
        return($labels[0]);
    }
    if($num == 2) {
        return($labels[0].' and '.$labels[1]);
    }
    my $last = pop @labels;
    return(join(', ', @labels).' and '.$last);
}

##########################################################

=head2 join_args

    join_args($args)

return string with joined args

=cut
sub join_args {
    my($args) = @_;
    my @arg;
    for my $a (@{$args}) {
        if($a =~ m/^(\d+|\d+\.\d+)$/mx) {
            push @arg, $a;
        } else {
            push @arg, "'".$a."'";
        }
    }
    return(join(', ', @arg));
}

##########################################################

=head2 state2text

    status2text($state)

return string of given state

=cut
sub state2text {
    my($nr) = @_;
    if($nr == 0) { return 'OK'; }
    if($nr == 1) { return 'WARNING'; }
    if($nr == 2) { return 'CRITICAL'; }
    if($nr == 3) { return 'UNKOWN'; }
    if($nr == 4) { return 'PENDING'; }
    return;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2013, <sven.nierlein@consol.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
