include ../Makefile.common

wait_start:
	-mkdir -p _run
	-chmod 777 _run
	for x in $$(seq $(STARTUPWAIT)); do \
	   curl http://localhost:60080/demo/thruk/cgi-bin/login.cgi >/dev/null 2>&1; \
	   if [ $$? -eq 0 ]; then break; else sleep 1; fi; \
	   if [ $$x -eq $(STARTUPWAIT) ]; then echo "ERROR: startup failed"; docker ps; curl http://localhost:60080/demo/thruk/cgi-bin/login.cgi; exit 1; fi; \
	done

test: test_chrome test_firefox

test_verbose: test

test_firefox: wait_start
	./failsafe.sh -browser firefox

test_chrome: wait_start
	./failsafe.sh -browser chrome

shell_sakuli:
	docker-compose exec sakuli /bin/bash

shell_omd:
	docker-compose exec omd /bin/bash
