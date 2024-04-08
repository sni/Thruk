include ../_common/Makefile.common

preparepre:
	cp -p ../../../.ci/prepare_machine.sh citest/
	wget https://raw.githubusercontent.com/abbbi/github-actions-tune/master/speedup.sh -O citest/speedup.sh
	chmod 755 citest/speedup.sh

extra_prepare:
	rm -rf citest/prepare_machine.sh
	rm  -f citest/speedup.sh
	docker exec citest_site_1 /thruk/t/scenarios/citest/extra_prepare.sh

wait_start:
	for x in $$(seq $(STARTUPWAIT)); do \
	   if [ $$(docker compose logs | grep "failed=" | grep -v "failed=0" | wc -l) -gt 0 ]; then $(MAKE) wait_start_failed; exit 1; fi; \
	   if [ $$(docker compose logs | grep "| ERROR" | wc -l) -gt 0 ]; then $(MAKE) wait_start_failed; exit 1; fi; \
	   if [ $$(docker compose logs | grep "ci container ready" | wc -l) -eq 1 ]; then break; else sleep 1; fi; \
	   if [ $$x -eq $(STARTUPWAIT) ]; then $(MAKE) wait_start_failed; exit 1; fi; \
	done
	docker ps

test: test_prepare wait_start
	docker exec citest_site_1 /thruk/t/scenarios/citest/test.sh $(filter-out $@,$(MAKECMDGOALS))

test_verbose: test_prepare wait_start
	docker exec citest_site_1 /thruk/t/scenarios/citest/test.sh 1 $(filter-out $@,$(MAKECMDGOALS))

test_prepare:
	docker exec citest_site_1 rsync -a --delete --exclude=Makefile --exclude=thruk_local.conf --exclude=thruk_local.d --exclude=tmp/ --exclude=var/ --chown=naemon:naemon /thruk/. /var/lib/naemon/thruk/.
