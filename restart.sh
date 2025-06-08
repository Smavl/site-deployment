#!/bin/bash
docker compose down -v
git pull --recurse-submodules
git submodule update --init --recursive
docker compose up -d --build --force-recreate 
