package Catalyst::Plugin::Thruk::ConfigLoader;
use parent 'Catalyst::Plugin::ConfigLoader';

use strict;
use Thruk::Backend::Pool;

########################################

=head2 finalize_config

    adjust config items which have to be set before anything else

=cut

sub finalize_config {
    my($c)= @_;
    return _do_finalize_config($c->config);
}

########################################

=head2 finalize

    restore used specific settings from global hash

=cut

sub finalize {
    my($c) = @_;
    # restore user adjusted config
    if($c->stash->{'config_adjustments'}) {
        for my $key (keys %{$c->stash->{'config_adjustments'}}) {
            $c->config->{$key} = $c->stash->{'config_adjustments'}->{$key};
        }
    }

    if($Thruk::deprecations_log) {
        for my $warning (@{$Thruk::deprecations_log}) {
            $c->log->info($warning);
        }
        undef $Thruk::deprecations_log;
    }

    return $c->next::method(@_);
}

########################################
sub _do_finalize_config {
    my($config) = @_;

    ###################################################
    # set var dir
    $config->{'var_path'} = $config->{'home'}.'/var' unless defined $config->{'var_path'};
    $config->{'var_path'} =~ s|/$||mx;

    ###################################################
    # switch user when running as root
    my $var_path = $config->{'var_path'} or die("no var path!");
    if($> != 0 and !-d ($var_path.'/.')) { CORE::mkdir($var_path); }
    die("'".$var_path."/.' does not exist, make sure it exists and has proper user/groups/permissions") unless -d ($var_path.'/.');
    my ($uid, $groups) = get_user($var_path);
    $ENV{'THRUK_USER_ID'}  = $uid;
    $ENV{'THRUK_GROUP_ID'} = $groups->[0];
    $ENV{'THRUK_GROUPS'}   = join(',', @{$groups});
    if(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'CLI') {
        if(defined $uid and $> == 0) {
            switch_user($uid, $groups);
        }
    }

    ###################################################
    # get installed plugins
    $config->{'plugin_path'} = $config->{home}.'/plugins' unless defined $config->{'plugin_path'};
    my $plugin_dir = $config->{'plugin_path'};
    $plugin_dir = $plugin_dir.'/plugins-enabled/*/';

    print STDERR "using plugins: ".$plugin_dir."\n" if $ENV{'THRUK_PLUGIN_DEBUG'};

    for my $addon (glob($plugin_dir)) {

        my $addon_name = $addon;
        $addon_name =~ s/\/+$//gmx;
        $addon_name =~ s/^.*\///gmx;

        # does the plugin directory exist?
        if(! -d $config->{home}.'/root/thruk/plugins/' and -w $config->{home}.'/root/thruk' ) {
            CORE::mkdir($config->{home}.'/root/thruk/plugins');
        }

        print STDERR "loading plugin: ".$addon_name."\n" if $ENV{'THRUK_PLUGIN_DEBUG'};

        # lib directory included?
        if(-d $addon.'lib') {
            print STDERR " -> lib\n" if $ENV{'THRUK_PLUGIN_DEBUG'};
            unshift(@INC, $addon.'lib');
        }

        # template directory included?
        if(-d $addon.'templates') {
            print STDERR " -> templates\n" if $ENV{'THRUK_PLUGIN_DEBUG'};
            unshift @{$config->{templates_paths}}, $addon.'templates';
        }

        # static content included?
        # only needed for development server, handled by apache aliasmatch otherwise
        if( -d $addon.'root' and -w $config->{home}.'/root/thruk/plugins/' ) {
            print STDERR " -> root\n" if $ENV{'THRUK_PLUGIN_DEBUG'};
            my $target_symlink = $config->{home}.'/root/thruk/plugins/'.$addon_name;
            if(-e $target_symlink) {
                my @s1 = stat($target_symlink."/.");
                my @s2 = stat($addon.'root/.');
                if($s1[1] != $s2[1]) {
                    print STDERR " -> inodes mismatch, trying to delete\n" if $ENV{'THRUK_PLUGIN_DEBUG'};
                    unlink($target_symlink) or die("failed to unlink: ".$target_symlink." : ".$!);
                }
            }
            if(!-e $target_symlink) {
                symlink($addon.'root', $target_symlink) or die("cannot create ".$target_symlink." : ".$!);
            }
        }
    }

    ###################################################
    # get installed / enabled themes
    my $themes_dir = $config->{'themes_path'} || $config->{home}."/themes";
    $themes_dir = $themes_dir.'/themes-enabled/*/';

    my @themes;
    for my $theme (sort glob($themes_dir)) {
        $theme =~ s/\/$//gmx;
        $theme =~ s/^.*\///gmx;
        print STDERR "theme -> $theme\n" if $ENV{'THRUK_PLUGIN_DEBUG'};
        push @themes, $theme;
    }

    print STDERR "using themes: ".$themes_dir."\n" if $ENV{'THRUK_PLUGIN_DEBUG'};

    $config->{'View::TT'}->{'PRE_DEFINE'}->{'themes'} = \@themes;

    ###################################################
    # use uid to make tmp dir more uniq
    $config->{'tmp_path'} = '/tmp/thruk_'.$> unless defined $config->{'tmp_path'};
    $config->{'tmp_path'} =~ s|/$||mx;
    $config->{'View::TT'}->{'COMPILE_DIR'} = $config->{'tmp_path'}.'/ttc_'.$>;

    $config->{'ssi_path'} = $config->{'ssi_path'} || $config->{home}.'/ssi';

    # set default config
    Thruk::Backend::Pool::set_default_config($config);

    return;
}

######################################

=head2 get_user

  get_user($from_folder)

return user and groups thruk runs with

=cut

sub get_user {
    my($from_folder) = @_;
    confess($from_folder." ".$!) unless -d $from_folder;
    my $uid = (stat $from_folder)[4];
    my($name,$gid) = (getpwuid($uid))[0, 3];
    my @groups = ( $gid );
    while ( my ( $gid, $users ) = ( getgrent )[ 2, -1 ] ) {
        $users =~ /\b$name\b/mx and push @groups, $gid;
    }
    return($uid, \@groups);
}

######################################

=head2 switch_user

  switch_user($uid, $groups)

switch user and groups

=cut

sub switch_user {
    my($uid, $groups) = @_;
    $) = join(" ", @{$groups});
    # using POSIX::setuid here leads to
    # 'Insecure dependency in eval while running setgid'
    $> = $uid or confess("setuid failed: ".$!);
    return;
}

######################################

1;

__END__

=head1 NAME

Catalyst::Plugin::Thruk::ConfigLoader - rearrange config just before application starts

=head1 SYNOPSIS

    use Catalyst qw[Thruk::ConfigLoader];


=head1 DESCRIPTION

Used to set and change some config options after the config has been loaded but
before the application has started

=head1 OVERLOADED METHODS

=over

=item finalize_config

rearrange config

=back

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHORS

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software . You can redistribute it and/or modify
it under the same terms as perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
