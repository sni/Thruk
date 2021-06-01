#/bin/bash

set -ex

cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)

# newer version are broken when using symlinks
cpanm -n http://search.cpan.org/CPAN/authors/id/F/FL/FLORA/ExtUtils-Manifest-1.63.tar.gz
./.ci/install_javascript_spidermonkey.sh
cpanm -q -f --installdeps --notest --no-man-pages .

# required for plugins test
cpanm -q -f --notest --no-man-pages Spreadsheet/ParseExcel.pm

# use latest version of critics
cpanm -q -f --notest --no-man-pages Perl::Critic
cpanm -q -f --notest --no-man-pages Test::Vars
git config --global user.email "test@localhost"
git config --global user.name "Test Testuser"
echo "export PERL5LIB=\$PERL5LIB:$HOME/perl5/lib/perl5" > ~/.thruk

# ensure we have all modules loaded
perl Makefile.PL
if [ $(perl Makefile.PL 2>&1 | grep -c missing) -ne 0 ]; then exit 1; fi
