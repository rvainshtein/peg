#!/usr/bin/env bash

if hash nvidia-docker 2>/dev/null; then
  cmd=nvidia-docker
else
  cmd=docker
fi

${cmd} exec -it $(docker ps --filter "ancestor=peg:v1" --format "{{.Names}}") bash
