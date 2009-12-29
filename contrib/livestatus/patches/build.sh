#!/bin/bash

autoheader && aclocal && autoconf && \
automake 2>&1 | grep -v 'is not a standard library name' | grep -v 'did you mean'
