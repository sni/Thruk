### THRUK

newversion:
	test -e .git
	make NEWVERSION="`./get_version`" version

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
	# breaks naemon travis tests
	#@if [ "x${DESTDIR}" = "x" ]; then echo "*** no DESTDIR set ***"; exit 1; fi
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
	cp -p script/thruk_fastcgi.pl ${DESTDIR}${DATADIR}/script/
	cp -p script/thruk_auth ${DESTDIR}${DATADIR}/
	[ ! -f script/wkhtmltopdf ] || cp -p script/wkhtmltopdf ${DESTDIR}${DATADIR}/script/
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
	cp -p docs/thruk.3 ${DESTDIR}${MANDIR}/man3/thruk.3
	cp -p docs/thruk.8 ${DESTDIR}${MANDIR}/man8/thruk.8
	cp -p docs/naglint.3 ${DESTDIR}${MANDIR}/man3/naglint.3
	cp -p docs/nagexp.3 ${DESTDIR}${MANDIR}/man3/nagexp.3
	############################################################################
	# docs
	mkdir -p                     ${DESTDIR}${DATADIR}/docs
	cp -p docs/FAQ.html          ${DESTDIR}${DATADIR}/docs/FAQ.html
	cp -p docs/THRUK_MANUAL.html ${DESTDIR}${DATADIR}/docs/THRUK_MANUAL.html
	############################################################################
	# logfiles
	mkdir -p ${DESTDIR}${LOGDIR}
	############################################################################
	# logrotation
	[ -z "${LOGROTATEDIR}" ] || { mkdir -p ${DESTDIR}${LOGROTATEDIR} && cp -p support/thruk.logrotate ${DESTDIR}${LOGROTATEDIR}/thruk && cd ${DESTDIR}${LOGROTATEDIR} && patch -p1 < $(shell pwd)/blib/replace/0006-logrotate.patch; }
	############################################################################
	# rc script
	[ -z "${INITDIR}" ] || { mkdir -p ${DESTDIR}${INITDIR} && cp -p support/thruk.init ${DESTDIR}${INITDIR}/thruk; }
	############################################################################
	# embedded thruk libs - handled in seperate package for naemon
	[ ! -d local-lib ] || { mkdir -p ${DESTDIR}${LIBDIR} && cp -rp local-lib ${DESTDIR}${LIBDIR}/perl5; }
	############################################################################
	# httpd config
	[ -z "${HTTPDCONF}" ] || { mkdir -p ${DESTDIR}${HTTPDCONF} && cp -p support/apache_fcgid.conf ${DESTDIR}${HTTPDCONF}/thruk.conf; }
	############################################################################
	# some patches
	cd ${DESTDIR}${SYSCONFDIR}/ && patch -p1 < $(shell pwd)/blib/replace/0001-thruk.conf.patch
	cd ${DESTDIR}${SYSCONFDIR}/ && patch -p1 < $(shell pwd)/blib/replace/0002-log4perl.conf.patch
	cd ${DESTDIR}${BINDIR}/     && patch -p1 < $(shell pwd)/blib/replace/0003-thruk-scripts.patch
	cd ${DESTDIR}${DATADIR}/    && patch -p1 < $(shell pwd)/blib/replace/0004-thruk_data_scripts.patch
	cd ${DESTDIR}${DATADIR}/    && patch -p1 < $(shell pwd)/blib/replace/0007-fcgish.patch
	find ${DESTDIR}${BINDIR}/ -name \*.orig -delete
	find ${DESTDIR}${DATADIR}/ -name \*.orig -delete
	find ${DESTDIR}${SYSCONFDIR}/ -name \*.orig -delete
	mkdir -p ${DESTDIR}${TMPDIR}/reports ${DESTDIR}${LOGDIR} ${DESTDIR}${SYSCONFDIR}/bp
	############################################################################
	# examples
	cp -p examples/bp_functions.pm ${DESTDIR}${SYSCONFDIR}/bp/

naemon-patch:
	[ -z "${INITDIR}" ] || { cd ${DESTDIR}${INITDIR}/ && patch -p1 < $(shell pwd)/blib/replace/0031-naemon-init.patch; }
	[ -z "${INITDIR}" ] || find ${DESTDIR}${INITDIR}/ -name \*.orig -delete
	[ -z "${HTTPDCONF}" ] || { cd ${DESTDIR}${HTTPDCONF}/  && patch -p1 < $(shell pwd)/blib/replace/0032-naemon-httpd.patch; }
	[ -z "${HTTPDCONF}" ] || find ${DESTDIR}${HTTPDCONF}/ -name \*.orig -delete
	[ -z "${HTTPDCONF}" ] || cp -p blib/replace/thruk_cookie_auth_vhost.conf ${DESTDIR}${HTTPDCONF}/thruk_cookie_auth_vhost.conf
	cd ${DESTDIR}${SYSCONFDIR}/ && patch -p1 < $(shell pwd)/blib/replace/0030-naemon.patch
	cd ${DESTDIR}${SYSCONFDIR}/ && patch -p1 < $(shell pwd)/blib/replace/0035-naemon-cgicfg.patch
	cd ${DESTDIR}${SYSCONFDIR}/ && patch -p1 < $(shell pwd)/blib/replace/0036-naemon-htpasswd.patch
	cd ${DESTDIR}${DATADIR}/    && patch -p1 < $(shell pwd)/blib/replace/0034-naemon-branding.patch
	find ${DESTDIR}${SYSCONFDIR}/ -name \*.orig -delete
	find ${DESTDIR}${BINDIR}/ -name \*.orig -delete
	mkdir -p ${DESTDIR}${SYSCONFDIR}/conf.d/
	[ -f ${DESTDIR}${SYSCONFDIR}/conf.d/thruk_templates.cfg ] || cp -p support/thruk_templates.cfg ${DESTDIR}${SYSCONFDIR}/conf.d/
	[ -f ${DESTDIR}${SYSCONFDIR}/conf.d/thruk_bp_generated.cfg ] ||  echo " " >> ${DESTDIR}${SYSCONFDIR}/conf.d/thruk_bp_generated.cfg
	rm -f ${DESTDIR}${DATADIR}/root/index.html
	cp -p blib/replace/thruk_cookie_auth.include ${DESTDIR}${DATADIR}/

quicktest:
	TEST_AUTHOR=1 PERL_DL_NONLAZY=1 perl "-MExtUtils::Command::MM" "-e" "test_harness(0, 'inc', 'lib/')" \
	    t/xt/panorama/javascript.t \
	    t/0*.t \
	    t/9*.t

