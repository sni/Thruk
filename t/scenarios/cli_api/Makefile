include ../_common/Makefile.common

test:
	@echo "### $@: $$(date "+%FT%T.%N")"
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root omd sudo -iu demo /test/t/test.sh 0 \
		|| ( cd $(shell pwd) && $(MAKE) failed_test )
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root omd /test/t/test_root.sh 0 \
		|| ( cd $(shell pwd) && $(MAKE) failed_test )
	cd ../../.. && PERL_DL_NONLAZY=1 /usr/bin/env perl "-MExtUtils::Command::MM" "-e" "test_harness(0)" $(shell pwd)/../_common/t/999*.t

test_verbose:
	@echo "### $@: $$(date "+%FT%T.%N")"
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root omd sudo -iu demo /test/t/test.sh 1 \
		|| ( cd $(shell pwd) && $(MAKE) failed_test )
	docker-compose exec $(DOCKER_COMPOSE_TTY) --user root omd /test/t/test_root.sh 1 \
		|| ( cd $(shell pwd) && $(MAKE) failed_test )
	cd ../../.. && PERL_DL_NONLAZY=1 /usr/bin/env perl "-MExtUtils::Command::MM" "-e" "test_harness(1)" $(shell pwd)/../_common/t/999*.t
