include ../_common/Makefile.common

extra_test:
	docker compose exec $(DOCKER_COMPOSE_TTY) --user root omd sudo -iu demo /usr/local/bin/local_test.sh 0

extra_test_verbose:
	docker compose exec $(DOCKER_COMPOSE_TTY) --user root omd sudo -iu demo /usr/local/bin/local_test.sh 1

