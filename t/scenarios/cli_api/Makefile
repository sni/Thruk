include ../Makefile.common

test:
	COMPOSE_INTERACTIVE_NO_CLI=0 docker-compose exec --user root omd sudo -iu demo /test/t/test.sh 0

test_verbose:
	COMPOSE_INTERACTIVE_NO_CLI=0 docker-compose exec --user root omd sudo -iu demo /test/t/test.sh 1
