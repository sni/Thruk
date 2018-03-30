#/bin/bash

sudo su - demo -c 'thruk report mail 1'
if [ $? -ne 0 ]; then
    exit 1
fi

# wait 60 seconds for mail to arrive
for x in $(seq 600); do \
    if test -e /var/spool/mail/demo && [ $(grep -c 'report.pdf' /var/spool/mail/demo) -gt 0 ]; then break; else sleep 0.1; fi;
done

grep 'report.pdf' /var/spool/mail/demo
rc=$?
if [ $rc -ne 0 ]; then
  echo "did not receive email within 60 seconds"
  set -x
  ls -la /var/spool/mail/demo
  cat /var/spool/mail/demo
fi
exit $rc
