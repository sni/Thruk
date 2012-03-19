newversion:
	test -d .git
	@make NEWVERSION="`./get_version`" version

version:
	test -d .git
	which dch
	@if [ ! -e "root/thruk/javascript/thruk-$(VERSION).js" ]; then echo "Makefile is out of date, please run 'perl Makefile.PL'"; exit 1; fi
	@if [ "$$NEWVERSION" = "" ]; then newversion=$$(dialog --stdout --inputbox "New Version:" 0 0 "$(VERSION)"); else newversion="$$NEWVERSION"; fi; \
	if [ -n "$$newversion" ]; then \
		date=`date "+%B %d, %Y"`; \
		branch=`echo "$$newversion" | awk '{ print $$2 }'`; \
		newversion=`echo "$$newversion" | awk '{ print $$1 }'`; \
	fi; \
	if [ -n "$$newversion" -a "$$newversion" != "$(VERSION)" ]; then \
		date=`date "+%B %d, %Y"`; \
		sed -r "s/'released'\s*=>\s*'.*',/'released'               => '$$date',/" -i lib/Thruk.pm && \
		debversion="$$newversion" && \
		if [ "$$branch" != "" ]; then sed -r "s/branch\s*= '';/branch = '$$branch';/" -i lib/Thruk.pm; debversion="$$newversion~$$branch"; fi && \
		dch --newversion "$$debversion" --package "thruk" -D "UNRELEASED" "new upstream release"; \
	fi; \
	if [ -n "$$newversion" -a "$$newversion" != "$(VERSION)" ]; then \
		sed -r "s/Version:\s*$(VERSION)/Version:       $$newversion/" -i support/thruk.spec && \
		sed -r "s/'$(VERSION)'/'$$newversion'/" -i lib/Thruk.pm -i support/thruk.spec && \
		sed -r "s/_$(VERSION)_/_$$newversion\_/" -i docs/THRUK_MANUAL.txt && \
		sed -r "s/\-$(VERSION)\./-$$newversion\./" -i MANIFEST -i docs/THRUK_MANUAL.txt -i root/thruk/startup.html && \
		sed -r "s/\-$(VERSION)\-/-$$newversion\-/" -i docs/THRUK_MANUAL.txt && \
		if [ -e ".git" ]; then git="git"; else git=""; fi && \
		$$git mv plugins/plugins-available/mobile/root/mobile-$(VERSION).css plugins/plugins-available/mobile/root/mobile-$$newversion.css && \
		$$git mv plugins/plugins-available/mobile/root/mobile-$(VERSION).js plugins/plugins-available/mobile/root/mobile-$$newversion.js && \
		$$git mv root/thruk/javascript/thruk-$(VERSION).js root/thruk/javascript/thruk-$$newversion.js && \
		$$git mv root/thruk/javascript/all_in_one-$(VERSION).js root/thruk/javascript/all_in_one-$$newversion.js && \
		$$git mv themes/themes-available/Thruk/stylesheets/all_in_one-$(VERSION).css themes/themes-available/Thruk/stylesheets/all_in_one-$$newversion.css && \
		$$git mv themes/themes-available/Thruk/stylesheets/all_in_one_noframes-$(VERSION).css themes/themes-available/Thruk/stylesheets/all_in_one_noframes-$$newversion.css; \
	fi;
	@./script/thruk_update_docs.sh > /dev/null
	@yes n | perl Makefile.PL > /dev/null
	@git add MANIFEST support/thruk.spec docs/THRUK_MANUAL.txt docs/THRUK_MANUAL.html lib/Thruk.pm debian/changelog docs/thruk.3 root/thruk/startup.html
	@git co docs/FAQ.html
	@git status

.PHONY: docs

make docs:
	script/thruk_update_docs.sh
