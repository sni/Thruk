use strict;
use warnings;
use Test::More;
use Data::Dumper;
use File::BOM qw( :all );

# ensure that all config options are well documented

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
        open_bom(FH, $file, 'bytes') or die($!);
        $type = get_encoding_from_filehandle(FH);
    };
    is( $type, 'UTF-8' , $file.' is utf-8');
}
