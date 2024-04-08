
build:
	docker compose build

prepare: build
	docker compose up --remove-orphans -d
	docker ps

update:
	docker compose pull
	for IMG in $$(grep FROM */*/Dockerfile | awk '{ print $$2 }' | sort -u); do docker pull $$IMG; done

clean:
	docker compose down -v --rmi all
	docker compose kill -s INT
	docker compose kill
	docker compose rm -f
