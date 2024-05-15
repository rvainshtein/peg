#!/usr/bin/env bash
# Get ssh_port from user, if not then default to 8022 and alert the user about the ssh_port
if [ -z "$1" ]; then
  echo "No ssh_port provided, defaulting to 8022"
  ssh_port=8022
else
  ssh_port=$1
fi
# Get tensorboard_port from user, if not then default to one above ssh_port and alert the user about the tensorboard_port
if [ -z "$2" ]; then
  echo "No tensorboard_port provided, defaulting to $((ssh_port+1))"
  tensorboard_port=$((ssh_port+1))
else
  tensorboard_port=$2
fi

if hash nvidia-docker 2>/dev/null; then
  cmd=nvidia-docker
else
  cmd=docker
fi

${cmd} run --rm -p ${ssh_port}:22 -v /home/ronv/dev/peg/docker_mem:/home/root/docker_mem -it peg:v1
