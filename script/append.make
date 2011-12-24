version:
	@newversion=$$(dialog --stdout --inputbox "New Version:" 0 0 "$(VERSION)") ; \
	if [ -n "$$newversion" ] && [ "$$newversion" != "$(VERSION)" ]; then \
		sed -ri "s/$(VERSION)/$$newversion/" lib/Thruk.pm docs/THRUK_MANUAL.txt; \
	fi ; \
	cd plugins/plugins-available/mobile/root/ && git mv mobile-$(VERSION).css mobile-$$newversion.css && git mv mobile-$(VERSION).js mobile-$$newversion.js
	@./script/thruk_update_docs.sh > /dev/null
	@perl Makefile.PL > /dev/null
	@git co docs/FAQ.html
	@git status

.PHONY: docs

make docs:
	script/thruk_update_docs.sh
