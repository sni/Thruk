version:
	@newversion=$$(dialog --stdout --inputbox "New Version:" 0 0 "$(VERSION)") ; \
	if [ -n "$$newversion" ] && [ "$$newversion" != "$(VERSION)" ]; then \
		sed -ri "s/$(VERSION)/$$newversion/" lib/Thruk.pm docs/THRUK_MANUAL.txt; \
	fi ;
	@./script/thruk_update_docs.sh > /dev/null
	@perl Makefile.PL > /dev/null
	@git co docs/FAQ.html
	@git status
