version:
	@if [ "$$NEWVERSION" = "" ]; then newversion=$$(dialog --stdout --inputbox "New Version:" 0 0 "$(VERSION)"); else newversion=$$NEWVERSION; fi; \
	if [ -n "$$newversion" -a "$$newversion" != "$(VERSION)" ]; then \
		sed -r "s/$(VERSION)/$$newversion/" -i lib/Thruk.pm -i docs/THRUK_MANUAL.txt -i MANIFEST -i support/thruk.spec && \
		git mv plugins/plugins-available/mobile/root/mobile-$(VERSION).css plugins/plugins-available/mobile/root/mobile-$$newversion.css && \
		git mv plugins/plugins-available/mobile/root/mobile-$(VERSION).js plugins/plugins-available/mobile/root/mobile-$$newversion.js && \
		git mv root/thruk/javascript/thruk-$(VERSION).js root/thruk/javascript/thruk-$$newversion.js && \
		git mv root/thruk/javascript/all_in_one-$(VERSION).js root/thruk/javascript/all_in_one-$$newversion.js && \
		git mv themes/themes-available/Thruk/stylesheets/all_in_one-$(VERSION).css themes/themes-available/Thruk/stylesheets/all_in_one-$$newversion.css && \
		git mv themes/themes-available/Thruk/stylesheets/all_in_one_noframes-$(VERSION).css themes/themes-available/Thruk/stylesheets/all_in_one_noframes-$$newversion.css; \
	fi;
	@./script/thruk_update_docs.sh > /dev/null
	@perl Makefile.PL > /dev/null
	@git co docs/FAQ.html
	@git status

.PHONY: docs

make docs:
	script/thruk_update_docs.sh
