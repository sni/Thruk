
build:
	docker compose build

prepare: build
	docker compose up --remove-orphans -d
	docker ps

update:
	docker compose pull --ignore-buildable --include-deps
	for IMG in $$(grep FROM */*/Dockerfile | awk '{ print $$2 }' | grep -v local/ | sort -u); do docker pull $$IMG; done

clean:
	docker compose down -v --rmi all
	docker compose kill -s INT
	docker compose kill
	docker compose rm -f
