#!/bin/bash

# build the Springboot docker image
cd ../example
docker build -t example -f Dockerfile .

# build RIG docker image from project root
# cd ../../../
# docker build -t reactive-interaction-gateway -f Dockerfile .
# docker build -t accenture/reactive-interaction-gateway -f Dockerfile

cd ../docker-starter

# back to docker starter
# cd examples/rig-kafka-pub-sub-example/docker-starter/

# run docker compose
set -e
docker-compose down; docker-compose up --build -d
