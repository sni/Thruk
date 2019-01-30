#!/usr/bin/env perl

`touch Makefile`;

##################################
# patch our makefile
my $new_makefile = '';
open(my $fh, '<', 'Makefile') or die("cannot open Makefile");
my $found_make_create_distdir = 0;
while(<$fh>) {
    my $line = $_;
    if($line =~ m/^install\s*:/mx) {
        $line = <<EOT;
install :: local_install
EOT
    }
    # search the create_distdir part
    if($line =~ m/create_distdir\s*:/mx) {
        $found_make_create_distdir = 1;
    }
    if($found_make_create_distdir and $line =~ m/^\s*$/mx) {
        $found_make_create_distdir = 0;
        my $cp_option;
        $cp_option = "-d" if $^O eq 'linux';
        $cp_option = "-R" if $^O eq 'freebsd';
        $cp_option = "-R" if $^O eq 'darwin';
        $line = "\t".'for file in `cat MANIFEST`; do if [ -d $$file -a -L $$file ]; then $(CP) '.$cp_option.' $$file $(DISTVNAME)/`dirname $$file`/; fi; done'."\n".$line if defined $cp_option;
    }

    # set tests
    if($line =~ m/^TEST_FILES\s*=/mx) {
        $line = "TEST_FILES = t/*.t t/xt/*/*.t\n";
    }
    if($line =~ m/^\#\#\#\ THRUK/mx) {
        last;
    }
    $new_makefile .= $line;
}
close($fh);
open($fh, '>', 'Makefile') or die("cannot open Makefile for writing");
print $fh $new_makefile;
close($fh);
`cat script/Makefile.options >> Makefile` if -e 'script/Makefile.options';
`cat script/Makefile.thruk   >> Makefile`;
print "patched Makefile\n";

exit;

