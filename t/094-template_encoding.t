use warnings;
use strict;
use Test::More;

use Thruk::Utils::IO ();

eval "use File::BOM";
plan skip_all => 'File::BOM required' if $@;
plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $filter = $ARGV[0];
my @dirs = glob("./templates ./plugins/plugins-available/*/templates ./themes/themes-available/*/templates");
for my $dir (@dirs) {
    for my $file (@{Thruk::Utils::IO::find_files($dir, '\.tt$')}) {
        check_template($file);
    }
}
done_testing();

sub check_template {
    my($file) = @_;
    return if($filter && $file !~ m%$filter%mx);
    my $type;
    eval {
        File::BOM::open_bom(my $fh, $file, 'bytes') or die($!);
        $type = File::BOM::get_encoding_from_filehandle($fh);
    };
    print $@ if $@;
    is( $type, 'UTF-8' , $file.' is utf-8');

    my $content = Thruk::Utils::IO::read($file);
    if($content =~ m/PROCESS\s+_header\.tt/mx && $content !~ m/PROCESS\s+_footer\.tt/mx) {
        fail($file." does not process _footer.tt");
    }
}
