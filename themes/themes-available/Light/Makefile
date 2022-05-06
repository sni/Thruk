SHELL=/bin/bash
NAME=$(notdir $(abspath .))

build: node_modules
	mkdir -p stylesheets
	NODE_ENV=production \
		npx tailwindcss -o stylesheets/${NAME}.css --input ./src/${NAME}.css --postcss ./postcss.config.js --minify

dev: node_modules
	mkdir -p stylesheets
	NODE_ENV=dev \
		npx tailwindcss -o stylesheets/${NAME}.css --input ./src/${NAME}.css --postcss ./postcss.config.js

watch: node_modules
	mkdir -p stylesheets
	NODE_ENV=dev \
		npx tailwindcss -o stylesheets/${NAME}.css --input ./src/${NAME}.css --postcss ./postcss.config.js --watch

node_modules:
	npm i -D \
		tailwindcss@latest \
		postcss@latest \
		autoprefixer@latest \
		postcss-import@latest \
		@tailwindcss/forms@latest \

clean:
	rm -rf \
		node_modules \
		package.json \
		package-lock.json \
		stylesheets \
