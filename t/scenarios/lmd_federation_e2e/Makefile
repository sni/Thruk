include ../Makefile.common

extra_wait_start:
	for x in $$(seq 120); do \
	   if [ $$($(THRUK) -l 2>&1 | grep -c OK) -eq 8 ]; then break; else sleep 0.5; fi; \
	done

extra_prepare:
	sudo ./docker_tc.sh lmdfederatione2e_slow_1

extra_clean:
	-killall lmd
