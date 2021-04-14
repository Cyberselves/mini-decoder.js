#!/usr/bin/env bash
docker build -f Dockerfile -t builder .

docker run --rm --init -v $PWD/output:/opt/output builder