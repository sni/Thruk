include ../_common/Makefile.common

export PLACK_TEST_EXTERNALSERVER_URI = http://127.0.0.3:60080/demo/
export THRUK_TEST_AUTH_KEY           = ff8cde7bc92c261a260a180ef4d35c456853b70d955c3eb1c41098d0d561268b_1

wait_start:
	for x in $$(seq $(STARTUPWAIT)); do \
	   if [ $$(docker-compose logs | grep "failed=" | grep -v "failed=0" | wc -l) -gt 0 ]; then $(MAKE) wait_start_failed; exit 1; fi; \
	   if [ $$(curl -ks http://127.0.0.3:60080/demo/thruk/cgi-bin/remote.cgi | grep -c OK) -gt 0 ]; then break; else sleep 1; fi; \
	   if [ $$x -eq $(STARTUPWAIT) ]; then $(MAKE) wait_start_failed; exit 1; fi; \
	done

wait_start_failed_extra:
	-curl -kv http://127.0.0.3:60080/demo/thruk/cgi-bin/remote.cgi

extra_test:
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root omd sudo -iu demo /test/t/local_test.sh 0

extra_test_verbose:
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root omd sudo -iu demo /test/t/local_test.sh 1
