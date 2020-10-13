#!/bin/bash

command_to_run=$@
docker_compose_prefix_command_file=.bootstrap/docker-compose-prefix-command

if [ ! -f $docker_compose_prefix_command_file ]; then
    echo "File $docker_compose_prefix_command_file not found! Cannot run docker-compose command for you.\n"
    exit 1
fi

docker_compose_prefix_command=`cat $docker_compose_prefix_command_file`
echo "Running docker-compose with \"$command_to_run\": "
echo $docker_compose_prefix_command " " $command_to_run
eval $docker_compose_prefix_command $command_to_run
if [ "$?" != 0 ]
then
 echo "Error occurred during the execution of \"$0 $command_to_run\" command."
fi
