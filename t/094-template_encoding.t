use strict;
use warnings;
use Test::More;

eval "use File::BOM";
plan skip_all => 'File::BOM required' if $@;
plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my @dirs = glob("./templates ./plugins/plugins-available/*/templates ./themes/themes-available/*/templates");
for my $dir (@dirs) {
    check_templates($dir.'/');
}
done_testing();


sub check_templates {
    my $dir = shift;
    my(@files, @folders);
    opendir(my $dh, $dir) || die $!;
    while(my $file = readdir $dh) {
        next if $file eq '.';
        next if $file eq '..';
        if($file =~ m/\.tt/mx) {
            push @files, $dir.$file;
        }
        elsif(-d $dir.$file) {
            push @folders, $dir.$file.'/';
        }
    }
    closedir $dh;

    for my $folder (sort @folders) {
        check_templates($folder);
    }
    for my $file (sort @files) {
        check_file($file);
    }
    return;
}

sub check_file {
    my $file = shift;
    my $type;
    eval {
        File::BOM::open_bom(my $fh, $file, 'bytes') or die($!);
        $type = File::BOM::get_encoding_from_filehandle($fh);
    };
    print $@ if $@;
    is( $type, 'UTF-8' , $file.' is utf-8');
}
