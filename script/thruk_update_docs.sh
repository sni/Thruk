#!/bin/bash

cd docs || ( echo "please run from the project root dir"; exit 1; )
asciidoc --unsafe -a toc -a icons -a data-uri -a max-width=800 INSTALL
chmod 644 INSTALL.html
