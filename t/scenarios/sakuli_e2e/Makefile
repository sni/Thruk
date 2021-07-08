include ../_common/Makefile.common

wait_start:
	-mkdir -p _run
	-chmod 777 _run
	for x in $$(seq $(STARTUPWAIT)); do \
	   if [ $$(docker-compose logs | grep "failed=" | grep -v "failed=0" | wc -l) -gt 0 ]; then $(MAKE) wait_start_failed; exit 1; fi; \
	   curl http://127.0.0.3:60080/demo/thruk/cgi-bin/login.cgi >/dev/null 2>&1; \
	   if [ $$? -eq 0 ]; then break; else sleep 1; fi; \
	   if [ $$x -eq $(STARTUPWAIT) ]; then $(MAKE) wait_start_failed; exit 1; fi; \
	done

wait_start_failed_extra:
	-curl -kv http://127.0.0.3:60080/demo/thruk/cgi-bin/login.cgi

test: test_chrome test_firefox
	cd ../../.. && PERL_DL_NONLAZY=1 /usr/bin/env perl "-MExtUtils::Command::MM" "-e" "test_harness(0)" $(shell pwd)/../_common/t/999*.t

test_verbose: test_chrome test_firefox
	cd ../../.. && PERL_DL_NONLAZY=1 /usr/bin/env perl "-MExtUtils::Command::MM" "-e" "test_harness(1)" $(shell pwd)/../_common/t/999*.t

test_firefox: wait_start
	./failsafe.sh -browser firefox

test_chrome: wait_start
	./failsafe.sh -browser chrome

shell_sakuli:
	docker-compose exec sakuli /bin/bash

shell_omd:
	docker-compose exec omd /bin/bash
