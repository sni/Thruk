include ../Makefile.common

export THRUK_TEST_AUTH               = omdadmin:omd
export PLACK_TEST_EXTERNALSERVER_URI = http://127.0.0.3:60080/demo/

wait_start:
	for x in $$(seq $(STARTUPWAIT)); do \
	   if [ $$(docker ps | grep thruk | grep -c starting) -eq 0 ]; then break; else sleep 1; fi; \
	   if [ $$x -eq $(STARTUPWAIT) ]; then $(MAKE) wait_start_failed; exit 1; fi; \
	done
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root thruk1 sudo -iu demo thruk r -m POST /thruk/cluster/heartbeat
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root thruk2 sudo -iu demo thruk r -m POST /thruk/cluster/heartbeat
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root thruk3 sudo -iu demo thruk r -m POST /thruk/cluster/heartbeat

wait_start_failed_extra:
	-curl -kv http://127.0.0.3:60080/demo/thruk/cgi-bin/login.cgi

extra_clean:
	-docker volume rm clustere2e_shared_etc
	-docker volume rm clustere2e_shared_var

extra_test:
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root thruk1 sudo -iu demo /test/t/local_test.sh 0

extra_test_verbose:
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root thruk1 sudo -iu demo /test/t/local_test.sh 1
