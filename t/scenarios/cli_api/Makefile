include ../Makefile.common

test:
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root omd sudo -iu demo /test/t/test.sh 0

test_verbose:
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root omd sudo -iu demo /test/t/test.sh 1
