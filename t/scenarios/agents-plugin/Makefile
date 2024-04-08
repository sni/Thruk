include ../_common/Makefile.common

export THRUK_TEST_AUTH               = omdadmin:omd
export PLACK_TEST_EXTERNALSERVER_URI = http://127.0.0.3:60080/demo/

wait_start:
	for x in $$(seq $(STARTUPWAIT)); do \
	   if [ $$(docker compose logs | grep "failed=" | grep -v "failed=0" | wc -l) -gt 0 ]; then $(MAKE) wait_start_failed; exit 1; fi; \
	   if [ $$(curl -s http://127.0.0.3:60080/demo/thruk/cgi-bin/login.cgi | grep -c loginuser) -gt 0 ]; then break; else sleep 1; fi; \
	   if [ $$x -eq $(STARTUPWAIT) ]; then $(MAKE) wait_start_failed; exit 1; fi; \
	done

server:
	@echo -e "\n\n*** no server implemented, access via http://127.0.0.3:60080/demo/\n"

wait_start_failed_extra:
	-curl -kv http://127.0.0.3:60080/demo/thruk/cgi-bin/login.cgi

extra_prepare:
	@printf "%s:omd version: %s\n" "$(shell grep FROM omd/Dockerfile)" $$(docker compose exec $(DOCKER_COMPOSE_TTY) --user root omd sudo -iu demo omd version -b)

extra_test:
	docker compose exec $(DOCKER_COMPOSE_TTY) --user root omd sudo -iu demo /usr/local/bin/local_test.sh 0 /test/t/local/omd/*.t
	docker compose exec $(DOCKER_COMPOSE_TTY) --user root livestatus-backend sudo -iu demo /usr/local/bin/local_test.sh 0 /test/t/local/livestatus-backend/*.t

extra_test_verbose:
	docker compose exec $(DOCKER_COMPOSE_TTY) --user root omd sudo -iu demo /usr/local/bin/local_test.sh 1 /test/t/local/omd/*.t
	docker compose exec $(DOCKER_COMPOSE_TTY) --user root livestatus-backend sudo -iu demo /usr/local/bin/local_test.sh 1 /test/t/local/livestatus-backend/*.t
