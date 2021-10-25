include ../_common/Makefile.common

extra_wait_start:
	for x in $$(seq $(STARTUPWAIT)); do \
	   if [ 0$$(echo "select count(*) from icinga_statehistory;" | mysql -u root -h 127.0.0.3 -P 60306 -proot icinga 2>/dev/null | grep -v ^count) -gt 0 ]; then break; else sleep 1; fi; \
	done
	echo "select count(*) from icinga_statehistory;" | mysql -u root -h 127.0.0.3 -P 60306 -proot icinga

extra_failed_test:
	echo "select count(*) from icinga_statehistory;" | mysql -u root -h 127.0.0.3 -P 60306 -proot icinga
	IDO_DB_HOST=127.0.0.3 IDO_DB_PORT=60306 IDO_DB_USER=root IDO_DB_PW=root IDO_DB_NAME=icinga ../../../support/icinga2_ido_fetchlogs.sh mysql | head -n 30
