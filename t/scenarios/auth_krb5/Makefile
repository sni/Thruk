include ../Makefile.common

export PLACK_TEST_EXTERNALSERVER_URI = http://127.0.0.3:60080/demo/
export THRUK_TEST_AUTH_KEY           = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

wait_start:
	for x in $$(seq $(STARTUPWAIT)); do \
	   if [ $$(curl -ks http://127.0.0.3:60080/demo/thruk/cgi-bin/remote.cgi | grep -c OK) -gt 0 ]; then break; else sleep 1; fi; \
	   if [ $$x -eq $(STARTUPWAIT) ]; then echo "ERROR: startup failed"; docker ps; curl -kv http://127.0.0.3:60080/demo/thruk/cgi-bin/remote.cgi; exit 1; fi; \
	done

extra_test:
	docker-compose exec -T --user root omd sudo -iu demo /test/t/local_test.sh 0

extra_test_verbose:
	docker-compose exec -T --user root omd sudo -iu demo /test/t/local_test.sh 1
