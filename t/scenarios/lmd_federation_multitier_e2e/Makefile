include ../_common/Makefile.common
EXPECTED_BACKENDS=12

extra_wait_start:
	for x in $$(seq $(STARTUPWAIT)); do \
	   if [ $$($(THRUK) selfcheck lmd 2>/dev/null | grep 'backends online' | grep -c -- '- $(EXPECTED_BACKENDS)') -eq 1 ]; then break; else sleep 1; fi; \
	   if [ $$x -eq $(STARTUPWAIT) ]; then $(MAKE) wait_start_failed; exit 1; fi; \
	done
	$(THRUK) selfcheck lmd

wait_start_failed_extra:
	-$(THRUK) selfcheck lmd

extra_clean:
	-killall lmd

extra_test:
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root tier1a sudo -iu demo /usr/local/bin/local_test.sh 0

extra_test_verbose:
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root tier1a sudo -iu demo /usr/local/bin/local_test.sh 1
