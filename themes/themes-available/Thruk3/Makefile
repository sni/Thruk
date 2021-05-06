
build: webfonts node_modules
	mkdir -p stylesheets
	NODE_ENV=production \
		./node_modules/postcss-cli/bin/postcss src/ --no-map --dir stylesheets/

webfonts:
	cp -rp node_modules/@fortawesome/fontawesome-free/webfonts .
	chmod 0755 webfonts
	chmod 0644 webfonts/*

dev: webfonts node_modules
	mkdir -p stylesheets
	NODE_ENV=dev \
		./node_modules/postcss-cli/bin/postcss src/ --no-map --dir stylesheets/

watch: node_modules
	mkdir -p stylesheets
	NODE_ENV=dev \
		./node_modules/postcss-cli/bin/postcss src/ -w --verbose --no-map --dir stylesheets/

node_modules:
	npm i -D \
		tailwindcss@latest \
		postcss@latest \
		postcss-cli@latest \
		autoprefixer@latest \
		postcss-nested@latest \
		postcss-import@latest \
		@fortawesome/fontawesome-free \


clean:
	rm -rf \
		node_modules \
		package.json \
		package-lock.json \
		stylesheets \


