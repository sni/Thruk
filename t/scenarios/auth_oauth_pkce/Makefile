include ../_common/Makefile.common

wait_start:
	for x in $$(seq $(STARTUPWAIT)); do \
	   if [ $$(docker compose logs | grep "failed=" | grep -v "failed=0" | wc -l) -gt 0 ]; then $(MAKE) wait_start_failed; exit 1; fi; \
	   if [ $$(curl -ks http://127.0.0.3:60080/demo/thruk/cgi-bin/remote.cgi | grep -c OK) -gt 0 ]; then break; else sleep 1; fi; \
	   if [ $$x -eq $(STARTUPWAIT) ]; then $(MAKE) wait_start_failed; exit 1; fi; \
	done
