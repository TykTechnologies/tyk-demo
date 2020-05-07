#!/bin/bash

echo -ne "  Bootstrapping Graphite \r"

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

     # restart tyk containers to take effect
     docker-compose restart 2> /dev/null
fi

echo -e "\033[2K          Graphite
               URL : http://localhost:8060
"