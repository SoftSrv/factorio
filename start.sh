#!/bin/bash
TAG=$1

if [ -z "$TAG" ]; then
  TAG=latest
fi

docker pull dtandersen/factorio:$TAG

ID=$(docker ps -aq --filter name=factorio)

if [ ! -z $ID ]; then
  docker stop -t=0 $ID
  docker rm $ID
fi

docker run -d  \
  -p 34197:34197/udp \
  -p 27015:27015/tcp \
  -v /opt/factorio:/factorio \
  --name factorio \
  --restart=always \
  dtandersen/factorio:$TAG