#!/bin/bash

source scripts/common.sh
feature="Instrumentation"
log_start_feature
bootstrap_progress

echo "Checking instrumentation env var is set correctly" >> bootstrap.log
instrumentation_setting=$(grep "INSTRUMENTATION_ENABLED" .env)
instrumentation_setting_desired="INSTRUMENTATION_ENABLED=1"
if [[ $instrumentation_setting != $instrumentation_setting_desired ]]
then
     # if missing
     if [ ${#instrumentation_setting} == 0 ]
     then
          echo "  Adding instrumentation setting to docker env var file" >> bootstrap.log
          echo $instrumentation_setting_desired >> .env
     else
          echo "  Updating instrumentation docker env var" >> bootstrap.log
          sed -i.bak 's/'"$instrumentation_setting"'/'"$instrumentation_setting_desired"'/g' ./.env
          rm .env.bak
     fi
     bootstrap_progress

     echo "  Restarting tyk containers to take effect" >> bootstrap.log
     docker-compose restart 2> /dev/null
     bootstrap_progress
fi

log_end_feature

echo -e "\033[2K          
▼ Instrumentation
  ▽ Graphite
               URL : http://localhost:8060"