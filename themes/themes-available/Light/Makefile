SHELL=/bin/bash
NAME=$(notdir $(abspath .))
N_PREFIX=$(shell pwd)/node
NODEVERSION=16

build: stylesheets/$(NAME).css

stylesheets/$(NAME).css: node_modules src/$(NAME).css
	mkdir -p stylesheets
	NODE_ENV=production \
	N_PREFIX=$(N_PREFIX) \
		./node_modules/.bin/n exec $(NODEVERSION) \
			npx tailwindcss -o stylesheets/${NAME}.css --input ./src/${NAME}.css --postcss ./postcss.config.js --minify
	touch stylesheets/${NAME}.css

dev: node_modules
	mkdir -p stylesheets
	NODE_ENV=dev \
	N_PREFIX=$(N_PREFIX) \
		./node_modules/.bin/n exec $(NODEVERSION) \
			npx tailwindcss -o stylesheets/${NAME}.css --input ./src/${NAME}.css --postcss ./postcss.config.js

watch: node_modules
	mkdir -p stylesheets
	NODE_ENV=dev \
	N_PREFIX=$(N_PREFIX) \
		./node_modules/.bin/n exec $(NODEVERSION) \
			npx tailwindcss -o stylesheets/${NAME}.css --input ./src/${NAME}.css --postcss ./postcss.config.js --watch

node: node_modules/.bin/n

node_modules/.bin/n:
	npm install n --no-audit --no-fund --prefix=$(shell pwd)/.
	N_PREFIX=$(N_PREFIX) \
		./node_modules/.bin/n $(NODEVERSION)

node_modules: node
	N_PREFIX=$(N_PREFIX) \
		./node_modules/.bin/n exec $(NODEVERSION) npm i -D --no-audit --no-fund --prefix=$(shell pwd)/. \
			tailwindcss@latest \
			postcss@latest \
			autoprefixer@latest \
			postcss-import@latest \
			@tailwindcss/forms@latest \
	# sometimes .bin dissapears after installing modules
	test -e ./node_modules/.bin/n || $(MAKE) node

clean:
	rm -rf \
		node \
		node_modules \
		package.json \
		package-lock.json \
		stylesheets \
