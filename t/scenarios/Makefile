SHELL=bash
export TEST_AUTHOR=1
export THRUK_TEST_E2E=1

test:
	cd ../.. && PERL_DL_NONLAZY=1 /usr/bin/env perl "-MExtUtils::Command::MM" "-e" "test_harness(0)" $(shell pwd)/../600-scenarios.t

test_verbose:
	cd ../.. && PERL_DL_NONLAZY=1 /usr/bin/env perl "-MExtUtils::Command::MM" "-e" "test_harness(1)" $(shell pwd)/../600-scenarios.t