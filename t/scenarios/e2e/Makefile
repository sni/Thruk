include ../Makefile.common

test:
	-mkdir -p _run
	-chmod 777 _run
	$(MAKE) prepare
	docker-compose start omd
	for x in $$(seq 50); do \
	   curl http://localhost:60080/demo/thruk/cgi-bin/login.cgi >/dev/null 2>&1; \
	   if [ $$? -eq 0 ]; then break; else sleep 0.5; fi; \
	done
	./failsafe.sh

shell_sakuli: prepare
	docker-compose exec sakuli /bin/bash

shell_omd: prepare
	docker-compose exec omd /bin/bash