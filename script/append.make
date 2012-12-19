newversion:
	test -d .git
	make NEWVERSION="`./get_version`" version

version:
	script/thruk_version.sh

.PHONY: docs

make docs:
	script/thruk_update_docs.sh
