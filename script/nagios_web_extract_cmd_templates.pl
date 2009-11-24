#!/usr/bin/env perl

=head1 NAME

nagios_web_extract_cmd_templates.pl - extract cmd templates

=head1 SYNOPSIS

./nagios_web_extract_cmd_templates.pl [ -h ] [ -v ] <file[s]>

=head1 DESCRIPTION

this script opens templates and extracts the needed information and writes out new templates

=head1 ARGUMENTS

script has the following arguments

=over 4

=item help

    -h

print help and exit

=item verbose

    -v

verbose output

=item files

    files    path to files to parse

=back

=head1 EXAMPLE

./nagios_web_extract_cmd_templates.pl templates/cmd_type_*.tt

=head1 AUTHOR

2009, Sven Nierlein, <nierlein@cpan.org>


=head1 EXAMPLE

create cmd templates like this:
x=1; while [ $x -lt 169 ]; do QUERY_STRING="cmd_typ=$x" REMOTE_USER=nagiosadmin REQUEST_METHOD=GET ./cmd.cgi | tidy -config ~/.tidyrc > /tmp/cmd_typ_$x.tt; x=$((x+1)); done

use a ~/.tidyrc like this:

    indent: autouppercase-tags: no
    clean: no
    numeric-entities: no
    markup: yes
    quiet: yes
    output-html: yes
    language: en

 then use this script to clean up the templates

=cut

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;

$Data::Dumper::Sortkeys = 1;

#########################################################################
# parse and check cmd line arguments
my ($opt_h, $opt_v, @opt_files);
Getopt::Long::Configure('no_ignore_case');
if(!GetOptions (
   "h"              => \$opt_h,
   "v"              => \$opt_v,
   "<>"             => \&add_files,
)) {
    pod2usage( { -verbose => 1, -message => 'error in options' } );
    exit 3;
}

if(defined $opt_h) {
    pod2usage( { -verbose => 1 } );
    exit 3;
}
my $verbose = 0;
if(defined $opt_v) {
    $verbose = 1;
}

if(scalar @opt_files <= 0) {
    pod2usage( { -verbose => 1, -message => 'no files specified' } );
    exit 3;
}

#########################################################################
for my $file (@opt_files) {
    open(my $fh, '<', $file) or die("cannot open file $file: $!");
    my $text = "";
    while(my $line = <$fh>) {
        $text .= $line;
    }
    close($fh);

    $text =~ s/>\s+</></gmx;
    $text =~ s/\n/ /gmx;

    if($text =~ m/You\ are\ requesting\ to\ execute\ an\ unknown\ command/mx) {
        unlink($file);
        next;
    }

    #print Dumper($text);

    my($commandDescription, $commandRequest, $commandForm);
    my $date = '';
    if($text =~ m/<td\ class='commandDescription'>(.*?)<\/td>/gmx) {
        $commandDescription = $1;
    }

    if($text =~ m/(You\ are\ requesting.*?)\s*</mx) {
        $commandRequest = $1;
    }

    if($text =~ m/<input\s*type=\s*'hidden'\s*name='cmd_mod'\s*value='2'>\s*<\/td>\s*<\/tr>(.*)<tr>\s*<td\s*class='optBoxItem'\s*colspan="2">\s*<\/td>\s*<\/tr>.*?<input\s*type='submit'/mx) {
        $commandForm = $1;
        $commandForm =~ s/<\/tr>/<\/tr>\n/gmx;

        # replace some default values
        my $replace_cgi_vars = {
            'down_id'       => 'down_id',
            'com_id'        => 'com_id',
            'host'          => 'host',
            'service'       => 'service',
            'servicegroup'  => 'servicegroup',
            'hostgroup'     => 'hostgroup',
        };
        for my $name (keys %{$replace_cgi_vars}) {
            $commandForm =~ s/type='text'\s+name='$name'\s+value='[^']*'/type='text'\ name='$name'\ value='[%\ c.request.parameters.$replace_cgi_vars->{$name} %]'/gmx;
        }

        # replace start time
        if($commandForm =~ s/type='text'\s+name='start_time'\s+value=\s*'[^']+'/type='text'\ name='start_time'\ value='[%\ date.format(date.now,\ '%Y-%m-%d\ %H:%M:%S')\ %]'/gmx) {
            $date = "[% USE date %]\n";
        }

        # replace end time
        if($commandForm =~ s/type='text'\s+name='end_time'\s+value=\s*'[^']+'/type='text'\ name='end_time'\ value='[%\ date.format(date.now+7200,\ '%Y-%m-%d\ %H:%M:%S')\ %]'/gmx) {
            $date = "[% USE date %]\n";
        }

        # replace (locked) author
        $commandForm =~ s/type='text'\ name='com_author'\ value='nagiosadmin'\ readonly\ disabled/type='text'\ name='com_author'\ value='[%\ comment_author\ %]'[%\ IF\ c.cgi_cfg.lock_author_names\ %]\ readonly\ disabled[%\ END\ %]/gmx;

        # replace downtime trigger
        if($commandForm =~ s/<tr><td\ class='optBoxItem'>Triggered\ By:<\/td>.*?<\/option><\/select><\/td><\/tr>/<tr><td\ class='optBoxItem'>Triggered\ By:<\/td><td><select\ name='trigger'><option\ value='0'>\ N\/A\ <\/option>[%\ FOREACH\ d\ =\ hostdowntimes\ %]<option\ value='[%\ d.id\ %]'>\ ID:\ [%\ d.id\ %],\ Host\ '[%\ d.host_name %]'\ starting\ @\ [%\ date.format(d.start_time,\ '%Y-%m-%d\ %H:%M:%S')\ %]\ <\/option>[%\ END\ %][%\ FOREACH\ d\ =\ servicedowntimes\ %]<option\ value='[% d.id %]'>\ ID:\ [%\ d.id\ %],\ Service\ '[%\ d.service_description\ %]'\ on\ host\ '[%\ d.host_name\ %]'\ starting\ @\ [%\ date.format(d.start_time,\ '%Y-%m-%d\ %H:%M:%S') %]\ <\/option>[%\ END\ %]<\/select><\/td><\/tr>/gmx) {
            $date = "[% USE date %]\n";
        }

        #print $commandForm;
    }

    if(!defined $commandDescription or !defined $commandRequest or !defined $commandForm) {
        die("error in $file");
    }

    my $newContent = $date."[% WRAPPER cmd.tt
   request = '".$commandRequest."'
   description = '".$commandDescription."'
%]
$commandForm
[% END %]";

    open($fh, '>', $file) or die("cannot write file $file: $!");
    print $fh $newContent;
    close($fh);
    print "$file written\n";
}

#########################################################################
sub add_files {
    my $file = shift;
    push @opt_files, $file;
}
