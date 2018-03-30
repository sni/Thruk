#!/bin/bash
# call this script with an email address (valid or not).
# like:
# ./makecert.sh <common name> <email>

cn=$1
email=$2
echo "make server cert"
openssl req -new -nodes -x509 -out server.pem -keyout server.key -days 20000 -subj "/C=DE/ST=NRW/L=Earth/O=Random Company/OU=IT/CN=$cn/emailAddress=$email"
echo "make client cert"
openssl req -new -nodes -x509 -out client.pem -keyout client.key -days 20000 -subj "/C=DE/ST=NRW/L=Earth/O=Random Company/OU=IT/CN=$cn/emailAddress=$email"
