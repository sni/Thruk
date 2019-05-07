#!/bin/bash

echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root';" | mysql
echo "FLUSH PRIVILEGES;" | mysql
