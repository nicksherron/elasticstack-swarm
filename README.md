# elastic-stack-swarm


[![Build Status](https://api.travis-ci.org/nsherron90/elastic-swarm.svg?branch=master)](https://travis-ci.org/nsherron90/elastic-swarm)



## Usage

```bash
$ ./machine.sh --help

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

```