#!/bin/bash

if [ -z "$fVersion" ]; then
  echo "factorio version not defined"
fi

docker pull dtandersen/factorio:$fVersion

ID=$(docker ps -aq --filter name=factorio)

if [ ! -z $ID ]; then
  docker stop -t=0 $ID
  docker rm $ID
fi

docker run -d  \
  -p 34197:34197/udp \
  -p 27015:27015/tcp \
  -v /home/factorio:/factorio \
  --name factorio \
  --restart=always \
  --user=root \
  dtandersen/factorio:$fVersion