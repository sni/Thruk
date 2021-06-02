include ../_common/Makefile.common


test_local:
	for x in $$(seq 200); do \
	   if [ $$($(THRUK) -l 2>&1 | grep -c ERROR) -eq 0 ]; then break; else sleep 1; fi; \
	done
	$(THRUK) -l
	$(THRUK) cache clean
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root omd bash -ci /root/test.sh

test: test_local
	cd ../../.. && PERL_DL_NONLAZY=1 /usr/bin/env perl "-MExtUtils::Command::MM" "-e" "test_harness(0)" $(shell pwd)/../_common/t/999*.t

test_verbose: test_local
	cd ../../.. && PERL_DL_NONLAZY=1 /usr/bin/env perl "-MExtUtils::Command::MM" "-e" "test_harness(1)" $(shell pwd)/../_common/t/999*.t
