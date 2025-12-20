#!/bin/bash
# Module: docker
# Version: 0.1.0
# Description: Docker cleanup and management functions
# BashMod Dependencies: none
# ~/.bashrc.d/docker.sh

function docker-nukec {
    all_ids=`docker ps -aq`
    docker stop $all_ids; docker rm $all_ids
}

function docker-purge-all {
    docker system prune -a --volumes
}