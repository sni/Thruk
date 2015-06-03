package Thruk::Utils::Panorama;

use strict;
use warnings;

=head1 NAME

Thruk::Utils::Panorama - Thruk Utils for Panorama Dashboard

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

BEGIN {
    #use Thruk::Timer qw/timing_breakpoint/;
}

##########################################################

=head2 get_static_panorama_files

    get_static_panorama_files($config)

return all static js files required for panorama

=cut
sub get_static_panorama_files {
    my($config) = @_;
    my @files;
    for my $file (sort glob($config->{'plugin_path'}.'/plugins-enabled/panorama/root/js/*.js')) {
        next if $file =~ m|track_timers|mx;
        next if $file =~ m|panorama_js_functions|mx;
        $file =~ s|^.*/root/js/|plugins/panorama/js/|gmx;
        push @files, $file;
    }
    unshift(@files, 'plugins/panorama/js/panorama_js_functions.js');
    return(\@files);
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
