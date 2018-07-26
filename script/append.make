### THRUK

SED=sed
DAILYVERSION=$(shell ./get_version)
DAILYVERSIONFILES=$(shell ./get_version | tr -d '-' | tr ' ' '-')
DAILYTARBALL=$(shell ./get_version | tr ' ' '~')

newversion: versionprecheck
	test -e .git
	make NEWVERSION="$(DAILYVERSION)" version

dailyversion: newversion

dailydist: cleandist
	# run in own make process, otherwise VERSION variable would not be updated
	$(MAKE) newversion
	$(MAKE) dist
	$(MAKE) resetdaily
	mv thruk-*.tar.gz thruk-$(DAILYTARBALL).tar.gz
	rm -f plugins/plugins-available/panorama/root/all_in_one-$(DAILYVERSIONFILES)_panorama.js \
		root/thruk/javascript/all_in_one-$(DAILYVERSIONFILES).js \
		themes/themes-available/Thruk/stylesheets/all_in_one-$(DAILYVERSIONFILES).css \
		themes/themes-available/Thruk/stylesheets/all_in_one_noframes-$(DAILYVERSIONFILES).css \
		themes/themes-available/Thruk2/stylesheets/all_in_one-$(DAILYVERSIONFILES).css \
		themes/themes-available/Thruk2/stylesheets/all_in_one_noframes-$(DAILYVERSIONFILES).css
	ls -la *.gz

releasedist: cleandist dist
	git describe --tag --exact-match
	# required for servicepack releases, like 2.10-2
	if [ "$(VERSION)" != "$(DAILYVERSION)" ]; then \
		tar zxf thruk-$(VERSION).tar.gz; \
		mv thruk-$(VERSION) thruk-$(DAILYVERSION); \
		tar cfz thruk-$(DAILYVERSION).tar.gz thruk-$(DAILYVERSION); \
		rm -f thruk-$(VERSION).tar.gz; \
		rm -rf thruk-$(DAILYVERSION); \
	fi
	ls -la *.gz

cleandist:
	rm -f *.gz

resetdaily:
	git reset --hard HEAD
	git checkout .
	yes n | perl Makefile.PL || yes n | perl Makefile.PL

versionprecheck:
	[ -e .git ] || { echo "changing versions only works in git clones!"; exit 1; }
	[ `git status | grep -c 'working directory clean'` -eq 1 ] || { echo "git project is not clean, cannot tag version"; exit 1; }

version:
	script/thruk_version.sh

.PHONY: docs

docs:
	script/thruk_update_docs.sh
	script/thruk_update_docs_rest.pl

staticfiles:
	script/thruk_create_combined_static_content.pl

local_patches:
	mkdir -p blib/replace
	cp -rp support/*.patch                      blib/replace
	cp -rp support/thruk_cookie_auth_vhost.conf blib/replace
	cp -rp support/thruk_cookie_auth.include    blib/replace
	${SED} -i blib/replace/* -e 's+@SYSCONFDIR@+${SYSCONFDIR}+g'
	${SED} -i blib/replace/* -e 's+@DATADIR@+${DATADIR}+g'
	${SED} -i blib/replace/* -e 's+@LOGDIR@+${LOGDIR}+g'
	${SED} -i blib/replace/* -e 's+@TMPDIR@+${TMPDIR}+g'
	${SED} -i blib/replace/* -e 's+@LOCALSTATEDIR@+${LOCALSTATEDIR}+g'
	${SED} -i blib/replace/* -e 's+@BINDIR@+${BINDIR}+g'
	${SED} -i blib/replace/* -e 's+@INITDIR@+${INITDIR}+g'
	${SED} -i blib/replace/* -e 's+@LIBDIR@+${LIBDIR}+g'
	${SED} -i blib/replace/* -e 's+@CHECKRESULTDIR@+${CHECKRESULTDIR}+g'
	${SED} -i blib/replace/* -e 's+@THRUKLIBS@+${THRUKLIBS}+g'
	${SED} -i blib/replace/* -e 's+@THRUKUSER@+${THRUKUSER}+g'
	${SED} -i blib/replace/* -e 's+@THRUKGROUP@+${THRUKGROUP}+g'
	${SED} -i blib/replace/* -e 's+@HTMLURL@+${HTMLURL}+g'
	${SED} -i blib/replace/* -e 's+@HTTPDCONF@+${HTTPDCONF}+g'
	${SED} -i blib/replace/* -e 's+log4perl.conf.example+log4perl.conf+g'

local_install: local_patches
	mkdir -p ${DESTDIR}${TMPDIR}
	mkdir -p ${DESTDIR}${LOCALSTATEDIR}
	############################################################################
	# etc files
	mkdir -p ${DESTDIR}${SYSCONFDIR}
	mkdir -p ${DESTDIR}${SYSCONFDIR}/themes/themes-available
	mkdir -p ${DESTDIR}${SYSCONFDIR}/themes/themes-enabled
	mkdir -p ${DESTDIR}${SYSCONFDIR}/plugins/plugins-available
	mkdir -p ${DESTDIR}${SYSCONFDIR}/plugins/plugins-enabled
	mkdir -p ${DESTDIR}${SYSCONFDIR}/ssi
	mkdir -p ${DESTDIR}${SYSCONFDIR}/action_menus
	cp -p thruk.conf ${DESTDIR}${SYSCONFDIR}/thruk.conf
	echo "do '${DATADIR}/menu.conf';" > ${DESTDIR}${SYSCONFDIR}/menu_local.conf
	cp -p support/thruk_local.conf.example ${DESTDIR}${SYSCONFDIR}/thruk_local.conf
	cp -p cgi.cfg ${DESTDIR}${SYSCONFDIR}/cgi.cfg
	${SED} -e 's/^default_user_name=.*$$/default_user_name=/' -i ${DESTDIR}${SYSCONFDIR}/cgi.cfg
	cp -p log4perl.conf.example ${DESTDIR}${SYSCONFDIR}/log4perl.conf
	cp -p support/naglint.conf.example ${DESTDIR}${SYSCONFDIR}/naglint.conf
	cp -p support/htpasswd ${DESTDIR}${SYSCONFDIR}/htpasswd
	cp -p ssi/status-header.ssi-pnp ${DESTDIR}${SYSCONFDIR}/ssi/status-header.ssi.example
	cp -p ssi/status-header.ssi-pnp ${DESTDIR}${SYSCONFDIR}/ssi/extinfo-header.ssi.example
	for file in $$(ls -1 plugins/plugins-enabled); do ln -fs "../plugins-available/$$file" ${DESTDIR}${SYSCONFDIR}/plugins/plugins-enabled/$$file; done
	for file in $$(ls -1 plugins/plugins-available); do ln -fs ${DATADIR}/plugins/plugins-available/$$file ${DESTDIR}${SYSCONFDIR}/plugins/plugins-available/$$file; done
	for file in $$(ls -1 themes/themes-enabled); do ln -fs "../themes-available/$$file" ${DESTDIR}${SYSCONFDIR}/themes/themes-enabled/$$file; done
	for file in $$(ls -1 themes/themes-available); do ln -fs ${DATADIR}/themes/themes-available/$$file ${DESTDIR}${SYSCONFDIR}/themes/themes-available/$$file; done
	############################################################################
	# data files
	mkdir -p ${DESTDIR}${DATADIR}
	mkdir -p ${DESTDIR}${DATADIR}/plugins
	mkdir -p ${DESTDIR}${DATADIR}/themes
	mkdir -p ${DESTDIR}${DATADIR}/script
	cp -rp lib root templates support ${DESTDIR}${DATADIR}/
	rm -rf ${DESTDIR}${DATADIR}/root/thruk/themes
	mkdir -p ${DESTDIR}${SYSCONFDIR}/usercontent/
	rm -rf ${DESTDIR}${DATADIR}/root/thruk/usercontent
	ln -fs ${SYSCONFDIR}/usercontent ${DESTDIR}${DATADIR}/root/thruk/
	cp -rp root/thruk/usercontent/* ${DESTDIR}${SYSCONFDIR}/usercontent/
	cp -rp support/fcgid_env.sh ${DESTDIR}${DATADIR}/
	chmod 755 ${DESTDIR}${DATADIR}/fcgid_env.sh
	cp -rp support/thruk_authd.pl ${DESTDIR}${DATADIR}/
	chmod 755 ${DESTDIR}${DATADIR}/thruk_authd.pl
	cp -rp menu.conf ${DESTDIR}${DATADIR}/
	cp -rp plugins/plugins-available ${DESTDIR}${DATADIR}/plugins/
	cp -rp themes/themes-available ${DESTDIR}${DATADIR}/themes/
	cp -p LICENSE Changes ${DESTDIR}${DATADIR}/
	cp -p script/thruk_fastcgi.pl  ${DESTDIR}${DATADIR}/script/
	cp -p script/thruk.psgi        ${DESTDIR}${DATADIR}/script/
	cp -p script/grafana_export.sh ${DESTDIR}${DATADIR}/script/
	cp -p script/html2pdf.js       ${DESTDIR}${DATADIR}/script/
	cp -p script/html2pdf.sh       ${DESTDIR}${DATADIR}/script/
	cp -p script/pnp_export.sh     ${DESTDIR}${DATADIR}/script/
	cp -p support/convert_old_datafile.pl ${DESTDIR}${DATADIR}/script/convert_old_datafile
	cp -p script/thruk_auth ${DESTDIR}${DATADIR}/
	[ ! -f script/phantomjs ] || cp -p script/phantomjs ${DESTDIR}${DATADIR}/script/
	echo " " > ${DESTDIR}${DATADIR}/dist.ini
	############################################################################
	# bin files
	mkdir -p ${DESTDIR}${BINDIR}
	cp -p script/thruk   ${DESTDIR}${BINDIR}/
	cp -p script/naglint ${DESTDIR}${BINDIR}/
	cp -p script/nagexp  ${DESTDIR}${BINDIR}/
	# rpmlint requires absolute perl path
	${SED} -e 's+/usr/bin/env perl+/usr/bin/perl+g' \
		-i ${DESTDIR}${BINDIR}/nagexp \
		-i ${DESTDIR}${DATADIR}/script/thruk_fastcgi.pl \
		-i ${DESTDIR}${DATADIR}/script/thruk.psgi
	############################################################################
	# man pages
	mkdir -p ${DESTDIR}${MANDIR}/man3
	mkdir -p ${DESTDIR}${MANDIR}/man8
	cp -p docs/manpages/thruk.3 ${DESTDIR}${MANDIR}/man3/thruk.3
	cp -p docs/manpages/thruk.8 ${DESTDIR}${MANDIR}/man8/thruk.8
	cp -p docs/manpages/naglint.3 ${DESTDIR}${MANDIR}/man3/naglint.3
	cp -p docs/manpages/nagexp.3 ${DESTDIR}${MANDIR}/man3/nagexp.3
	############################################################################
	# logfiles
	mkdir -p ${DESTDIR}${LOGDIR}
	############################################################################
	# logrotation
	[ -z "${LOGROTATEDIR}" ] || { mkdir -p ${DESTDIR}${LOGROTATEDIR} && cp -p support/thruk.logrotate ${DESTDIR}${LOGROTATEDIR}/thruk-base && cd ${DESTDIR}${LOGROTATEDIR} && patch -p1 < $(shell pwd)/blib/replace/0006-logrotate.patch; }
	############################################################################
	# bash completion
	[ -z "${BASHCOMPLDIR}" ] || { mkdir -p ${DESTDIR}${BASHCOMPLDIR} && cp -p support/thruk_bash_completion ${DESTDIR}${BASHCOMPLDIR}/thruk-base; }
	############################################################################
	############################################################################
	# rc script
	[ -z "${INITDIR}" ] || { mkdir -p ${DESTDIR}${INITDIR} && cp -p support/thruk.init ${DESTDIR}${INITDIR}/thruk; }
	############################################################################
	# httpd config
	[ -z "${HTTPDCONF}" ] || { mkdir -p ${DESTDIR}${HTTPDCONF} && cp -p support/apache_fcgid.conf ${DESTDIR}${HTTPDCONF}/thruk.conf; }
	[ -z "${HTTPDCONF}" ] || cp -p blib/replace/thruk_cookie_auth_vhost.conf ${DESTDIR}${HTTPDCONF}/thruk_cookie_auth_vhost.conf
	cp -p blib/replace/thruk_cookie_auth.include ${DESTDIR}${DATADIR}/
	############################################################################
	# some patches
	cd ${DESTDIR}${SYSCONFDIR}/ && patch -p1 < $(shell pwd)/blib/replace/0001-thruk.conf.patch
	cd ${DESTDIR}${SYSCONFDIR}/ && patch -p1 < $(shell pwd)/blib/replace/0002-log4perl.conf.patch
	cd ${DESTDIR}${BINDIR}/     && patch -p1 < $(shell pwd)/blib/replace/0003-thruk-scripts.patch
	cd ${DESTDIR}${DATADIR}/    && patch -p1 < $(shell pwd)/blib/replace/0004-thruk_data_scripts.patch
	cd ${DESTDIR}${DATADIR}/    && patch -p1 < $(shell pwd)/blib/replace/0005-thruk_auth.patch
	cd ${DESTDIR}${DATADIR}/    && patch -p1 < $(shell pwd)/blib/replace/0007-fcgish.patch
	find ${DESTDIR}${BINDIR}/ -name \*.orig -delete
	find ${DESTDIR}${DATADIR}/ -name \*.orig -delete
	find ${DESTDIR}${SYSCONFDIR}/ -name \*.orig -delete
	mkdir -p ${DESTDIR}${TMPDIR}/reports ${DESTDIR}${LOGDIR} ${DESTDIR}${SYSCONFDIR}/bp
	############################################################################
	# examples
	cp -p examples/bp_functions.pm ${DESTDIR}${SYSCONFDIR}/bp/
	cp -p examples/bp_filter.pm    ${DESTDIR}${SYSCONFDIR}/bp/

quicktest:
	TEST_AUTHOR=1 PERL_DL_NONLAZY=1 perl "-MExtUtils::Command::MM" "-e" "test_harness(0, 'inc', 'lib/')" \
	    t/xt/panorama/javascript.t \
	    t/0*.t \
	    t/9*.t

timedtest:
	for file in $(TEST_FILES); do \
		printf "%-60s" $$file; \
		output=$$(TEST_AUTHOR=1 PERL_DL_NONLAZY=1 /usr/bin/time -f %e perl "-MExtUtils::Command::MM" "-e" "test_harness(0, 'inc', 'lib/')" $$file 2>&1); \
		if [ $$? != 0 ]; then \
			printf "% 8s \n" "FAILED"; \
		else \
			time=$$(echo "$$output" | tail -n1); \
			printf "% 8ss\n" $$time; \
		fi; \
	done

scenariotest:
	$(MAKE) test_scenarios

test_scenarios:
	cd t/scenarios && $(MAKE) test

e2etest:
	cd t/scenarios/sakuli_e2e && $(MAKE) clean update prepare test

rpm: $(NAME)-$(VERSION).tar.gz
	rpmbuild -ta $(NAME)-$(VERSION).tar.gz

deb: $(NAME)-$(VERSION).tar.gz
	tar zxvf $(NAME)-$(VERSION).tar.gz
	debuild -rfakeroot -i -us -uc -b
	rm -rf $(NAME)-$(VERSION)
