export TEST_MYSQL=mysql://thruk:thruk@127.0.0.3:63306/thruk

include ../_common/Makefile.common

extra_wait_start:
	for x in $$(seq 120); do \
	   if [ $$($(THRUK) logcache stats 2>&1 | grep -c failed:) -eq 0 ]; then break; else sleep 0.5; fi; \
	done
	$(THRUK) logcache stats

extra_test:
	$(THRUK) logcache stats | grep " core "
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root backend sudo -iu demo /test/t/local_test.sh 0

extra_test_verbose:
	$(THRUK) logcache stats | grep " core "
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root backend sudo -iu demo /test/t/local_test.sh 1

mysql:
	mysql -u thruk -pthruk -h 127.0.0.3 -P 63306 thruk
