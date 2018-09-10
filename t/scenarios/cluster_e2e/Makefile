include ../Makefile.common

export THRUK_TEST_AUTH               = omdadmin:omd
export PLACK_TEST_EXTERNALSERVER_URI = http://localhost:60080/demo/

wait_start:
	for x in $$(seq $(STARTUPWAIT)); do \
	   if [ $$(curl -s http://localhost:60080/demo/thruk/cgi-bin/login.cgi | grep -c Login) -gt 0 ]; then break; else sleep 1; fi; \
	   if [ $$x -eq $(STARTUPWAIT) ]; then echo "ERROR: startup failed"; docker ps; curl http://localhost:60080/demo/thruk/cgi-bin/login.cgi; exit 1; fi; \
	done

extra_clean:
	-docker volume rm clustere2e_shared_etc
	-docker volume rm clustere2e_shared_var
