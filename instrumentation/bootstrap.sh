#!/bin/bash

dot_count=""

function bootstrap_progress {
  dot_count=$((dot_count+1))
  dots=$(printf "%-${dot_count}s" ".")
  echo -ne "  Bootstrapping Graphite ${dots// /.} \r"
}

# check instrumentation env var is set correctly
instrumentation_setting=$(grep "INSTRUMENTATION_ENABLED" .env)
instrumentation_setting_desired="INSTRUMENTATION_ENABLED=1"

if [[ $instrumentation_setting != $instrumentation_setting_desired ]]
then
     # if missing
     if [ ${#instrumentation_setting} == 0 ]
     then
          # then add
          echo $instrumentation_setting_desired >> .env
     else
          # else replace (done this way to be compatible across different linux versions)
          sed -i.bak 's/'"$instrumentation_setting"'/'"$instrumentation_setting_desired"'/g' ./.env
          rm .env.bak
     fi
     bootstrap_progress
     
     # restart tyk containers to take effect
     docker-compose restart 2> /dev/null
     bootstrap_progress
fi

echo -e "\033[2K          Graphite
               URL : http://localhost:8060
"