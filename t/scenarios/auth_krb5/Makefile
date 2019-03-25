include ../Makefile.common

export PLACK_TEST_EXTERNALSERVER_URI = https://127.0.0.3:60443/demo/
export THRUK_TEST_AUTH_KEY           = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
export PERL_LWP_SSL_VERIFY_HOSTNAME  = 0

wait_start:
	for x in $$(seq $(STARTUPWAIT)); do \
	   if [ $$(curl -ks https://127.0.0.3:60443/demo/thruk/cgi-bin/remote.cgi | grep -c OK) -gt 0 ]; then break; else sleep 1; fi; \
	   if [ $$x -eq $(STARTUPWAIT) ]; then echo "ERROR: startup failed"; docker ps; curl -kv https://127.0.0.3:60443/demo/thruk/cgi-bin/remote.cgi; exit 1; fi; \
	done
