use strict;
use warnings;
use Test::More;
use File::Slurp qw/read_file/;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my @dirs = glob("./templates ./plugins/plugins-available/*/templates ./themes/themes-available/*/templates");
for my $dir (@dirs) {
    check_templates($dir.'/');
}
done_testing();

sub check_templates {
    my($dir) = @_;
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
    my($file) = @_;
    my $content = read_file($file);
    my $nr = 0;
    for my $line (split/\n/mx, $content) {
        $nr++;
        if($line =~ m/value='[^']*\[%/mx) {
            fail(sprintf("%s:%d uses single quotes in value='' but html filter only escapes double quotes", $file, $nr));
            diag($line);
        }
        elsif($line =~ m/value="([^"]*\[%[^"]*)"/mx) {
            my $match = $1;
            if($match !~ m/(
                             \|\s*html
                            |escape_html\(
                            |get_user_token\(
                            |object\.get_id\(
                            |format_date\(
                            |md5
                            |%\s+hour\s+%
                            |%\s+min\s+%
                            |%\s+day\s+%
                            |monthday
                            |r\.nr
                            |\.id
                            |short_uri\(
                            |uri_with\(
                            |date\.now
                            |sites\.down
                            |sites\.up
                            |sites\.disabled
                            |play_sounds
                            |fav_counter
                        )/mx) {
                fail(sprintf("%s:%d uses value without html filter in: %s", $file, $nr, $match));
                diag($line);
            }
        }
    }
}
