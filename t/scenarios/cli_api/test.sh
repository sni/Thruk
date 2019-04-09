#!/bin/bash

FLAGS=""
if [ ! -t 0 ]; then
  FLAGS="-T"
fi
docker-compose exec $FLAGS --user root omd bash -ci "su - demo -c 'thruk -l'"
