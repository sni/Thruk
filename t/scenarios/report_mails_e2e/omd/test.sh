#/bin/bash

sudo su - demo -c 'thruk report mail 1'
if [ $? -ne 0 ]; then
    exit 1
fi

# wait 30 seconds for mail to arrive
for x in $(seq 300); do \
    if test -e /var/spool/mail/demo && [ $(grep -c 'Subject: Report: Test Report' /var/spool/mail/demo) -gt 0 ]; then break; else sleep 0.1; fi;
done

grep 'Subject: Report: Test Report' /var/spool/mail/demo
exit $?
