#!/bin/bash

./docker-compose-command.sh down -v --remove-orphans
if [ "$?" == 0 ]
then
  echo "All containers were stopped and removed"
else
 echo "Error occurred during the following the down command."
fi 
