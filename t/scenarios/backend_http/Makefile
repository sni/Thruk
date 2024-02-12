include ../_common/Makefile.common

extra_prepare:
	@printf "%s:omd version: %s\n" "$(shell grep FROM omd/Dockerfile)" $$(docker-compose exec $(DOCKER_COMPOSE_TTY) --user root site sudo -iu demo omd version -b)
