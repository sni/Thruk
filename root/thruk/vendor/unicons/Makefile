all: build clean

build: node_modules
	rm -rf fonts css
	cp -rp ./node_modules/@iconscout/unicons/fonts .
	cp -rp ./node_modules/@iconscout/unicons/css .
	# firefox: "downloadable font: rejected by sanitizer"
	sed -i '/unicons-1.woff2/d' ./css/line.css
	sed -i '/unicons-5.woff2/d' ./css/line.css
	sed -i '/unicons-6.woff2/d' ./css/line.css
	sed -i '/unicons-7.woff2/d' ./css/line.css
	sed -i '/unicons-8.woff2/d' ./css/line.css
	sed -i '/unicons-9.woff2/d' ./css/line.css
	sed -i '/unicons-13.woff2/d' ./css/line.css
	sed -i '/unicons-14.woff2/d' ./css/line.css
	sed -i '/unicons-16.woff2/d' ./css/line.css
	sed -i '/unicons-17.woff2/d' ./css/line.css
	sed -i '/unicons-18.woff2/d' ./css/line.css
	sed -i '/unicons-19.woff2/d' ./css/line.css
	rm -rf unicons-*
	set -x; VERSION=$$(npm info "@iconscout/unicons" version); \
		mkdir -p unicons-$$VERSION; \
		mv fonts css unicons-$$VERSION; \

node_modules:
	npm install --save @iconscout/unicons --prefix=$(shell pwd)/.

clean:
	rm -rf \
		node_modules \
		package.json \
		package-lock.json
