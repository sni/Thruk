include ../Makefile.common


test:
	for x in $$(seq 200); do \
	   if [ $$($(THRUK) -l 2>&1 | grep -c ERROR) -eq 0 ]; then break; else sleep 1; fi; \
	done
	$(THRUK) -l
	$(THRUK) cache clean
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root omd bash -ci /root/test.sh

test_verbose: test
