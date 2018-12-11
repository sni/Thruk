include ../Makefile.common
EXPECTED_BACKENDS=7

extra_wait_start:
	for x in $$(seq $(STARTUPWAIT)); do \
	   if [ $$($(THRUK) selfcheck lmd 2>/dev/null | grep 'backends online' | grep -c -- '- $(EXPECTED_BACKENDS)') -eq 1 ]; then break; else sleep 1; fi; \
	   if [ $$x -eq $(STARTUPWAIT) ]; then echo "ERROR: startup failed"; docker ps; $(THRUK) selfcheck lmd; exit 1; fi; \
	done
	$(THRUK) selfcheck lmd

extra_prepare:
	#sudo ./docker_tc.sh lmdfederatione2e_slow_1 slow

extra_clean:
	-killall lmd
