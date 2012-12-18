use strict;
use warnings;
use Test::More;
use Data::Dumper;
use File::Slurp;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

#################################################
my @jsfiles = glob('root/thruk/javascript/thruk-*.js
                    plugins/plugins-available/*/root/*.js
                    plugins/plugins-available/panorama/templates/./panorama_js.tt
                    plugins/plugins-available/panorama/templates/./_panorama_js_*.tt
                    ');
for my $file (@jsfiles) {
    ok(1, "checking ".$file);
    verify_js($file);
}

my @tplfiles = split(/\n/, `find templates plugins/plugins-available/*/templates/. themes/themes-available/*/templates -name \*.tt`);
for my $file (@tplfiles) {
    ok(1, "checking ".$file);
    verify_tt($file);
}

done_testing();

#################################################
# verify js syntax
sub verify_js {
    my($file) = @_;
    my $content = read_file($file);
    my $matches = _replace_with_marker($content);
    return unless scalar $matches > 0;
    _check_marker($file, $content);
    return;
}

#################################################
# verify js syntax in templates
sub verify_tt {
    my($file) = @_;
    my $content = read_file($file);
    $content =~ s/(<script.*?<\/script>)/&_extract_js($1)/misge;
    _check_marker($file, $content);
    return;
}

#################################################
# verify js syntax in templates
sub _extract_js {
    my($text) = @_;
    _replace_with_marker($text);
    return $text;
}

#################################################
# verify js syntax in templates
sub _replace_with_marker {
    my @matches = $_[0]  =~ s/(\,\s*[\)|\}|\]])/JS_ERROR_MARKER:$1/sgmxi;
    return scalar @matches;
}

#################################################
sub _check_marker {
    my($file, $content) = @_;
    my @lines = split/\n/mx, $content;
    my $x = 1;
    for my $line (@lines) {
        if($line =~ m/JS_ERROR_MARKER:/mx) {
            my $orig = $line;
            $orig   .= "\n".$lines[$x+1] if defined $lines[$x+1];
            $orig =~ s/JS_ERROR_MARKER://gmx;
            fail('found trailing comma in '.$file.' line: '.$x);
            diag($orig);
        }
        $x++;
    }
}
