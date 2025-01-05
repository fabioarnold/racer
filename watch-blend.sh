#!/bin/bash

# install nodemon using `npm install -g nodemon`
nodemon -w data -x "zig build" -e ".blend"