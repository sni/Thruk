export TEST_MYSQL=mysql://thruk:thruk@127.0.0.1:63306/thruk

include ../Makefile.common

wait_start_extra:
	for x in $$(seq 50); do \
	   if [ $$($(THRUK) logcache stats 2>&1 | grep -c failed:) -eq 0 ]; then break; else sleep 0.5; fi; \
	done
	$(THRUK) logcache stats
