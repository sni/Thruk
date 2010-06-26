use strict;
use warnings;
use Test::More;
use Data::Dumper;

eval "use File::BOM";
plan skip_all => 'File::BOM required'.$@ if $@;
plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my @dirs = glob("templates plugins/plugins-available/statusmap/templates root/thruk/themes/*/templates");
for my $dir (@dirs) {
    check_templates($dir.'/');
}
done_testing();


sub check_templates {
    my $dir = shift;
    opendir(my $dh, $dir) || die $!;
    while(my $file = readdir $dh) {
        next if $file eq '.';
        next if $file eq '..';

        if($file =~ m/\.tt/mx) {
            check_file($dir.$file);
        }
        elsif(-d $dir.$file) {
            check_templates($dir.$file.'/');
        }
    }
    closedir $dh;
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
