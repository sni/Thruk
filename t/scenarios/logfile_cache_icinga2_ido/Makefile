include ../Makefile.common

extra_wait_start:
	for x in $$(seq $(STARTUPWAIT)); do \
	   if [ 0$$(echo "select count(*) from icinga_statehistory;" | mysql -u root -h 127.0.0.1 -P 60306 -proot icinga 2>/dev/null | grep -v ^count) -gt 0 ]; then break; else sleep 1; fi; \
	done
	echo "select count(*) from icinga_statehistory;" | mysql -u root -h 127.0.0.1 -P 60306 -proot icinga
