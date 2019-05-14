#!/bin/bash -   
#title          :machine
#description    :Script that uses docker-machine to create and manage docker-swarm cluster running elastic stack.
#author         :Nick Sherron (@nsherron90)
#date           :20190514
#version        :0.1.0  
#usage          :./machine.sh
#notes          :       
#bash_version   :3.2.57(1)-release
#license: GPL-3.0
#============================================================================

set -euf -o pipefail

# get variables from .env
. .env

# set defaults
machine=${MACHINE:-virtualbox}
manager=${MANAGER:-1}
worker=${WORKER:-2}

let nodes=manager+worker


# TODO add swarm-restart function
# TODO add show config function


usage() {
cat <<"EOF"

Script that uses docker-machine to create and manage docker-swarm cluster running elastic stack.

IMPORTANT: environment variables are read via .env file located within this directory.


Usage: ./machine.sh COMMAND

Commands:
   dm-init                  Create docker machines named manager-1 , worker-1, worker-2 etc.
                            Machine driver (aws, virtualbox(default), gce) and quantity are
                            read from .env file or environment variables.

   dm-destroy               Destroys machines created by dm-init.

   dm-restart               Runs dm-destroy then dm-init

   swarm-init               Initializes swarm on machines created by dm-init.
                            Machines named manager-[n]  and worker-[n] are created as swarm managers and workers.

   swarm-destroy            Destroys the swarm-created by swarm-init.

   swarm-ls                 Runs docker node ls on the manager-1 node to list the swarm.

   stack-init               Runs `docker stack deploy -c elastic-stack.yml elastic`
                            as swarm manager, deploying elastic-stack.yml as a swarm stack.

   stack-destroy            Destroys stack created by stack-init

   stack-restart            Runs stack-destroy followed by stack-init

  ./machine.sh  -h,--help             : show this message
EOF
}


dm-init() {
    echo "### Initializing docker-machine for managers"

    if [[ "$machine" == "amazon" ]]; then
        for i in $(seq 1 ${manager}); do
            docker-machine create \
              --driver amazonec2 \
              --amazonec2-region us-east-2 \
              manager-${i}
        done

        echo "### Initializing docker-machine for workers"

        for i in $(seq 1 ${worker}); do
            docker-machine create \
              --driver amazonec2 \
              --amazonec2-region us-east-2 \
              worker-${i}
        done

    elif [[ "${machine}" == "google" ]]; then

        echo "### Initializing docker-machine for managers"
        gcloud_project=$(gcloud config list 2> /dev/null | grep 'project =' |  sed 's/project = //g' | head -n 1)
        export GOOGLE_PROJECT="${gcloud_project}"


        for i in $(seq 1 ${manager}); do
            docker-machine create \
              --driver google \
              manager-${i}
        done

        echo "### Initializing docker-machine for workers"

        for i in $(seq 1 ${worker}); do
            docker-machine create \
              --driver google \
              worker-${i}
        done

    else
        echo "### Initializing docker-machine for managers"

        for i in $(seq 1 ${manager}); do
            docker-machine create \
              --driver virtualbox \
              --virtualbox-no-vtx-check \
              manager-${i}
        done

        echo "### Initializing docker-machine for workers"

        for i in $(seq 1 ${worker}); do
            docker-machine create \
              --driver virtualbox \
              --virtualbox-no-vtx-check \
              worker-${i}
        done
    fi
#    increase vm.max_map_count to 262144 for elasticsearch
#    https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html
    echo "### Increasing vm.max_map_count on managers"

    for i in $(seq 1 ${manager}); do
        docker-machine ssh manager-${i} sudo sysctl -w vm.max_map_count=262144
    done

    echo "### Increasing vm.max_map_count on workers "

    for i in $(seq 1 ${worker}); do
        docker-machine ssh worker-${i}  sudo sysctl -w vm.max_map_count=262144
    done
}


dm-destroy() {
    echo "### Destroying docker-machine nodes ..."

    for i in $(seq 1 ${manager}); do
        docker-machine rm -y manager-${i}
    done

     for i in $(seq 1 ${worker}); do
        docker-machine rm -y worker-${i}
    done


}


dm-restart() {
    dm-destroy 2> /dev/null
    dm-init
}


swarm-init() {
    echo "### Creating Docker Machine nodes ..."
    leader_ip=$(docker-machine ip manager-1)

    echo "### Initializing Swarm mode ..."
    eval $(docker-machine env manager-1)
    docker swarm init --advertise-addr ${leader_ip} || true

    # Swarm tokens
    manager_token=$(docker swarm join-token manager -q)
    worker_token=$(docker swarm join-token worker -q)

    echo "### Joining manager nodes ..."
    for i in $(seq 1 ${manager}); do
        eval $(docker-machine env manager-${i})
        docker swarm join --token ${manager_token} ${leader_ip}:2377 2> /dev/null || true
    done


    echo "### Joining worker nodes ..."
    for i in $(seq 1 ${worker}); do
        eval $(docker-machine env worker-${i})
        docker swarm join --token ${worker_token} ${leader_ip}:2377  || true
    done

    eval $(docker-machine env manager-1)
    docker node ls

}


swarm-destroy() {
    echo "### Destroying swarm ..."
    for i in $(seq 1 ${manager}); do
        eval $(docker-machine env manager-${i})
        docker swarm leave -f
    done
    for i in $(seq 1 ${worker}); do
        eval $(docker-machine env worker-${i})
        docker swarm leave -f
    done
}


swarm-ls() {
    eval $(docker-machine env manager-1)
    docker node ls
}


stack-init(){
    eval $(docker-machine env manager-1)
#    docker network create --driver overlay --attachable backend
    docker stack deploy -c elastic-stack.yml elastic

}


stack-destroy(){
    eval $(docker-machine env manager-1)
    docker stack rm  elastic

}


stack-ls(){
    eval $(docker-machine env manager-1)
    docker service ls

}


stack-restart(){
    stack-destroy
    sleep 5
    stack-init
}


init() {
    dm-init
    swarm-init
    stack-init
}


destroy() {
    dm-destroy 2> /dev/null
}


restart() {
    destroy
    sleep 5
    init
}


main() {
    if [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
        usage
        exit 1
    else
        "${1}"
    fi
}


main "${@:--h}"
