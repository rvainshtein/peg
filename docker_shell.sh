#!/usr/bin/env bash

if hash nvidia-docker 2>/dev/null; then
  cmd=nvidia-docker
else
  cmd=docker
fi

${cmd} run --rm -p 8022:22 -v `pwd`:/home/user/peg -it peg:v1
