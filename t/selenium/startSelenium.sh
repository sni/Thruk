#!/bin/bash

/usr/bin/Xvfb :43 -screen 0 1280x800x24
DISPLAY=:43 exec java -jar ...
