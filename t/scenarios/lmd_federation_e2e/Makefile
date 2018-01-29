include ../Makefile.common

wait_start_extra:
	for x in $$(seq 120); do \
	   if [ $$($(THRUK) -l 2>&1 | grep -c OK) -eq 4 ]; then break; else sleep 0.5; fi; \
	done

extra_clean:
	-killall lmd
