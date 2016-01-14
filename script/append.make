### THRUK

DAILYVERSION=$(shell ./get_version)
DAILYVERSIONFILES=$(shell ./get_version | tr -d '-' | tr ' ' '-')

newversion: versionprecheck
	test -e .git
	make NEWVERSION="$(DAILYVERSION)" version

dailyversion: newversion

dailydist: cleandist
	# run in own make process, otherwise VERSION variable would not be updated
	$(MAKE) newversion
	$(MAKE) dist
	$(MAKE) resetdaily
	mv Thruk-*.tar.gz Thruk-$$(echo "$(DAILYVERSION)" | tr ' ' '~').tar.gz
	rm -f plugins/plugins-available/panorama/root/all_in_one-$(DAILYVERSIONFILES)_panorama.js \
		root/thruk/javascript/all_in_one-$(DAILYVERSIONFILES).js \
		themes/themes-available/Thruk/stylesheets/all_in_one-$(DAILYVERSIONFILES).css \
		themes/themes-available/Thruk/stylesheets/all_in_one_noframes-$(DAILYVERSIONFILES).css
	ls -la *.gz

releasedist: cleandist dist
	git describe --tag --exact-match
	if [ "$(VERSION)" != "$(DAILYVERSION)" ]; then \
	    tar zxf Thruk-$(VERSION).tar.gz; \
	    mv Thruk-$(VERSION) Thruk-$(DAILYVERSION); \
	    tar cfz Thruk-$(DAILYVERSION).tar.gz Thruk-$(DAILYVERSION); \
	    rm -f Thruk-$(VERSION).tar.gz; \
	    rm -rf Thruk-$(DAILYVERSION); \
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

staticfiles:
	script/thruk_create_combined_static_content.pl

local_patches:
	mkdir -p blib/replace
	cp -rp support/*.patch                      blib/replace
	cp -rp support/thruk_cookie_auth_vhost.conf blib/replace
	cp -rp support/thruk_cookie_auth.include    blib/replace
	sed -i blib/replace/* -e 's+@SYSCONFDIR@+${SYSCONFDIR}+g'
	sed -i blib/replace/* -e 's+@DATADIR@+${DATADIR}+g'
	sed -i blib/replace/* -e 's+@LOGDIR@+${LOGDIR}+g'
	sed -i blib/replace/* -e 's+@TMPDIR@+${TMPDIR}+g'
	sed -i blib/replace/* -e 's+@LOCALSTATEDIR@+${LOCALSTATEDIR}+g'
	sed -i blib/replace/* -e 's+@BINDIR@+${BINDIR}+g'
	sed -i blib/replace/* -e 's+@INITDIR@+${INITDIR}+g'
	sed -i blib/replace/* -e 's+@LIBDIR@+${LIBDIR}+g'
	sed -i blib/replace/* -e 's+@CHECKRESULTDIR@+${CHECKRESULTDIR}+g'
	sed -i blib/replace/* -e 's+@THRUKLIBS@+${THRUKLIBS}+g'
	sed -i blib/replace/* -e 's+@THRUKUSER@+${THRUKUSER}+g'
	sed -i blib/replace/* -e 's+@THRUKGROUP@+${THRUKGROUP}+g'
	sed -i blib/replace/* -e 's+@HTMLURL@+${HTMLURL}+g'
	sed -i blib/replace/* -e 's+@HTTPDCONF@+${HTTPDCONF}+g'
	sed -i blib/replace/* -e 's+log4perl.conf.example+log4perl.conf+g'

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
	cp -p thruk.conf ${DESTDIR}${SYSCONFDIR}/thruk.conf
	echo "do '${DATADIR}/menu.conf';" > ${DESTDIR}${SYSCONFDIR}/menu_local.conf
	cp -p support/thruk_local.conf.example ${DESTDIR}${SYSCONFDIR}/thruk_local.conf
	cp -p cgi.cfg ${DESTDIR}${SYSCONFDIR}/cgi.cfg
	sed -e 's/^default_user_name=.*$$/default_user_name=/' -i ${DESTDIR}${SYSCONFDIR}/cgi.cfg
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
	cp -rp lib root templates ${DESTDIR}${DATADIR}/
	rm -f ${DESTDIR}${DATADIR}/root/thruk/themes
	mkdir -p ${DESTDIR}${SYSCONFDIR}/usercontent/
	rm -rf ${DESTDIR}${DATADIR}/root/thruk/usercontent
	ln -fs ${SYSCONFDIR}/usercontent ${DESTDIR}${DATADIR}/root/thruk/
	cp -rp root/thruk/usercontent/* ${DESTDIR}${SYSCONFDIR}/usercontent/
	cp -rp support/fcgid_env.sh ${DESTDIR}${DATADIR}/
	chmod 755 ${DESTDIR}${DATADIR}/fcgid_env.sh
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
	cp -p script/thruk_auth ${DESTDIR}${DATADIR}/
	[ ! -f script/phantomjs ] || cp -p script/phantomjs ${DESTDIR}${DATADIR}/script/
	echo " " > ${DESTDIR}${DATADIR}/dist.ini
	############################################################################
	# bin files
	mkdir -p ${DESTDIR}${BINDIR}
	cp -p script/thruk   ${DESTDIR}${BINDIR}/
	cp -p script/naglint ${DESTDIR}${BINDIR}/
	cp -p script/nagexp  ${DESTDIR}${BINDIR}/
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

DOCKERRESULTS=$(shell pwd)/t/docker/results/$(shell date +'%Y-%m-%d_%H.%M')
DOCKERCMD=cd t/docker && \
            docker run \
                -p 5901:5901 \
                --rm \
                -v $(shell pwd)/.:/src \
                -v $(shell pwd)/t/docker/cases:/root/cases \
                -v $(DOCKERRESULTS):/root/cases/_logs \
                -v /etc/localtime:/etc/localtime
t/docker/Dockerfile:
	cp -p t/docker/Dockerfile.in t/docker/Dockerfile
	cd t/docker && docker build -t="local/thruk_panorama_test" .

dockerbuild:
	rm -f t/docker/Dockerfile
	$(MAKE) t/docker/Dockerfile

dockertest: t/docker/Dockerfile dockertestfirefox dockertestchrome

dockertestchrome:
	mkdir -p $(DOCKERRESULTS)
	$(DOCKERCMD) local/thruk_panorama_test /root/failsafe.sh -b chrome
	rm -rf $(DOCKERRESULTS)

dockertestfirefox:
	mkdir -p $(DOCKERRESULTS)
	$(DOCKERCMD) local/thruk_panorama_test /root/failsafe.sh -b firefox
	rm -rf $(DOCKERRESULTS)

dockershell: t/docker/Dockerfile
	mkdir -p $(DOCKERRESULTS)
	$(DOCKERCMD) -it local/thruk_panorama_test /bin/bash
