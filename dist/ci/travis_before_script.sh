#!/bin/bash
# This script prepares the CI build for running

echo "Configure docker"
docker-compose --version
docker -v
CONTAINER_USERID=$(id -u)
printf "version: '2'\nservices:\n  frontend:\n    build:\n      args:\n        CONTAINER_USERID: $CONTAINER_USERID" >> docker-compose.override.yml
docker-compose build frontend
