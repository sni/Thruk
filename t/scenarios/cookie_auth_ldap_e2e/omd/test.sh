#/bin/bash

# verify ldap credential is working
sudo su - demo -c 'ldapwhoami -H ldap://127.0.0.1:9000/ -w ldap -x -D "uid=ldap,ou=People,dc=test,dc=local"'
if [ $? -ne 0 ]; then
    echo "ldap credential check failed"
    exit 1
fi
sudo su - demo -c 'ldapwhoami -H ldap://127.0.0.1:9000/ -w wrong -x -D "uid=ldap,ou=People,dc=test,dc=local"'
if [ $? -eq 0 ]; then
    echo "ldap credential check failed for wrong password"
    exit 1
fi

# check omdadmin from htpasswd
curl -kv https://omdadmin:omd@localhost/demo/thruk/cgi-bin/tac.cgi | grep "Tactical Monitoring Overview"
if [ $? -ne 0 ]; then
    echo "login with htpasswd user failed"
    exit 1
fi
curl -kv https://omdadmin:wrong@localhost/demo/thruk/cgi-bin/tac.cgi | grep "Tactical Monitoring Overview"
if [ $? -eq 0 ]; then
    echo "htpasswd login with wrong credentials should fail"
    exit 1
fi

# check ldap user
curl -kv https://ldap:ldap@localhost/demo/thruk/cgi-bin/tac.cgi | grep "Tactical Monitoring Overview"
if [ $? -ne 0 ]; then
    echo "login with ldap user failed"
    exit 1
fi
curl -kv https://ldap:wrong@localhost/demo/thruk/cgi-bin/tac.cgi | grep "Tactical Monitoring Overview"
if [ $? -eq 0 ]; then
    echo "ldap login with wrong credentials should fail"
    exit 1
fi

# normal htpassd login
curl -kv 'https://localhost/demo/thruk/cgi-bin/login.cgi' -H 'User-Agent: Mozilla/5.0' -H 'Cookie: thruk_test=****' --data 'login=omdadmin&password=omd&submit=Login' 2>&1 | grep 'Set-Cookie: thruk_auth='
if [ $? -ne 0 ]; then
    echo "normal login with htpasswd user failed"
    exit 1
fi

# normal ldap login
curl -kv 'https://localhost/demo/thruk/cgi-bin/login.cgi' -H 'User-Agent: Mozilla/5.0' -H 'Cookie: thruk_test=****' --data 'login=ldap&password=ldap&submit=Login' 2>&1 | grep 'Set-Cookie: thruk_auth='
if [ $? -ne 0 ]; then
    echo "normal login with ldap user failed"
    exit 1
fi

if ! test -f /omd/sites/demo/tmp/hook.log; then
    echo "hook did not create logfile"
    exit 1
fi

exit 0
