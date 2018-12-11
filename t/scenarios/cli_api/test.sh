#!/bin/bash

docker-compose exec --user root omd bash -ci "su - demo -c 'thruk -l'"
