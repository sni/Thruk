version:
	@newversion=$$(dialog --stdout --inputbox "New Version:" 0 0 "$(VERSION)") ; \
	if [ -n "$$newversion" ] && [ "$$newversion" != "$(VERSION)" ]; then \
		sed -ri "s/$(VERSION)/$$newversion/" lib/Thruk.pm docs/THRUK_MANUAL.txt; \
	fi ; \
	git mv plugins/plugins-available/mobile/root/mobile-$(VERSION).css plugins/plugins-available/mobile/root/mobile-$$newversion.css && \
	git mv plugins/plugins-available/mobile/root/mobile-$(VERSION).js plugins/plugins-available/mobile/root/mobile-$$newversion.js && \
	git mv root/thruk/javascript/thruk-$(VERSION).js root/thruk/javascript/thruk-$$newversion.js
	@./script/thruk_update_docs.sh > /dev/null
	@perl Makefile.PL > /dev/null
	@git co docs/FAQ.html
	@git status

.PHONY: docs

make docs:
	script/thruk_update_docs.sh
