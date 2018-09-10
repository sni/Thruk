include ../Makefile.common

test:
	docker-compose exec -T --user root omd sudo -iu demo /test/t/test.sh 0

test_verbose:
	docker-compose exec -T --user root omd sudo -iu demo /test/t/test.sh 1
