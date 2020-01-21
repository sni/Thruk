include ../Makefile.common

export PLACK_TEST_EXTERNALSERVER_URI = https://127.0.0.3:60443/demo/

wait_start:
	for x in $$(seq $(STARTUPWAIT)); do \
	   if [ $$(curl -ks $(PLACK_TEST_EXTERNALSERVER_URI)thruk/cgi-bin/login.cgi | grep -c Login) -gt 0 ]; then break; else sleep 1; fi; \
	   if [ $$x -eq $(STARTUPWAIT) ]; then $(MAKE) wait_start_failed; exit 1; fi; \
	done

wait_start_failed_extra:
	-curl -kv $(PLACK_TEST_EXTERNALSERVER_URI)thruk/cgi-bin/login.cgi

server:
	@echo -e "\n\n*** no server implemented, access via https://$(shell hostname):60443/demo/\n"

extra_test:
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root site sudo -iu demo /test/t/local_test.sh 0

extra_test_verbose:
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root site sudo -iu demo /test/t/local_test.sh 1
