#!/bin/bash

source scripts/common.sh
deployment="CI/CD"
log_start_deployment
bootstrap_progress

jenkins_base_url="http://localhost:8070"
dashboard2_base_url="http://localhost:3002"

log_message "Checking Tyk Environment 2 deployment exists"
tyk2_dashboard_service=$(docker-compose -f deployments/tyk/docker-compose.yml -f deployments/cicd/docker-compose.yml -f deployments/tyk2/docker-compose.yml -p tyk-pro-docker-demo-extended --project-directory $(pwd) ps | grep "tyk2-dashboard")
# Warn is cicd deployment is made without the tyk2 deployment
if [[ "${#tyk2_dashboard_service}" -eq "0" ]]
then
  log_message "  WARNING: Tyk Environment 2 deployment not found."
  log_message "           CI/CD feature will not work as intended."
  log_message "           Ensure 'tyk2' parameter is used when calling up.sh script: ./up.sh tyk2 cicd"
else
  log_ok
fi
bootstrap_progress

log_message "Checking Jenkins plugin archive exists"
jenkins_plugin_path="deployments/cicd/volumes/jenkins/bootstrap-import/jenkins-plugins.tar.gz"
if [ ! -f $jenkins_plugin_path ]
then
  log_message "  Archive missing, downloading..."
  curl "https://www.dropbox.com/s/d561fgowioqbceb/jenkins-plugins.tar.gz?dl=0" -L -s -o $jenkins_plugin_path 2>> bootstrap.log
fi
log_ok
bootstrap_progress

log_message "Waiting for Jenkins to respond ok"
jenkins_status=""
# 403 indicates that at least Jenkins was able to recognise that the request was unauthorised, so we should be ok to proceed
jenkins_status_desired="403"
jenkins_tries=0
while [ "$jenkins_status" != "$jenkins_status_desired" ]
do
  jenkins_status=$(curl -I -s -m5 $jenkins_base_url 2>> bootstrap.log | head -n 1 | cut -d$' ' -f2)
  if [ "$jenkins_status" != "$jenkins_status_desired" ]
  then
    log_message "  Request unsuccessful, retrying..."
    sleep 2
  else
    log_ok
  fi
  bootstrap_progress
done

log_message "Getting Jenkins admin password"
jenkins_admin_password=$(docker-compose -f deployments/tyk/docker-compose.yml -f deployments/cicd/docker-compose.yml -p tyk-pro-docker-demo-extended --project-directory $(pwd) exec jenkins sh -c "cat /var/jenkins_home/secrets/initialAdminPassword | head -c32" 2>> bootstrap.log)
log_message "  Jenkins admin password = $jenkins_admin_password"
bootstrap_progress

log_message "Extracting Jenkins plugins and other configuration"
docker-compose -f deployments/tyk/docker-compose.yml -f deployments/cicd/docker-compose.yml -p tyk-pro-docker-demo-extended --project-directory $(pwd) exec \
  jenkins \
  tar -xzvf /var/jenkins_home/bootstrap-import/jenkins-plugins.tar.gz -C /var/jenkins_home 1> /dev/null 2>> bootstrap.log
log_ok
bootstrap_progress

log_message "Restarting Jenkins container to allow new config and plugins to be used"
docker-compose -f deployments/tyk/docker-compose.yml -f deployments/cicd/docker-compose.yml -p tyk-pro-docker-demo-extended --project-directory $(pwd) restart jenkins 2> /dev/null
log_ok
bootstrap_progress

log_message "Checking Tyk Environment 2 Dashboard API is accessible"
dashboard2_user_api_credentials=$(cat .context-data/dashboard2-user-api-credentials)
result=""
while [ "$result" != "200" ]
do
  result=$(curl $dashboard2_base_url/api/apis -s -o /dev/null -w "%{http_code}" -H "authorization: $dashboard2_user_api_credentials" 2>> bootstrap.log)
  if [ "$result" == "401" ]
  then
    log_message "  WARNING: Unable to make API calls to Tyk Environment 2 Dashboard."
    log_message "           CI/CD feature will not work as intended."
    log_message "           Rerun up.sh script with 'tyk2' parameter before 'cicd' parameter: ./up.sh tyk2 cicd"
    break
  else
    log_message "  Request unsuccessful, retrying..."
    sleep 2
  fi
done
log_ok
bootstrap_progress

log_message "Writing Jenkins credentials import file"
sed "s/TYK2_DASHBOARD_CREDENTIALS/$dashboard2_user_api_credentials/g" deployments/cicd/data/jenkins/credentials-global-template.xml > \
  deployments/cicd/volumes/jenkins/bootstrap-import/credentials-global.xml
log_ok

log_message "Importing credentials for 'global'"
jenkins_response=""
while [ "${jenkins_response:0:1}" != "0" ]
do
  jenkins_response=$(docker-compose -f deployments/tyk/docker-compose.yml -f deployments/cicd/docker-compose.yml -p tyk-pro-docker-demo-extended --project-directory $(pwd) exec jenkins bash -c "java -jar /var/jenkins_home/jenkins-cli.jar -s http://localhost:8080/ -auth admin:$jenkins_admin_password -webSocket import-credentials-as-xml system::system::jenkins < /var/jenkins_home/bootstrap-import/credentials-global.xml; echo $?")
  if [ "${jenkins_response:0:1}" != "0" ]
  then
    log_message "  Request unsuccessful, retrying..."
    sleep 2
  else
    log_ok
  fi
  bootstrap_progress
done

log_message "Creating job for 'APIs and Policies'"
jenkins_response=""
while [ "${jenkins_response:0:1}" != "0" ]
do
  jenkins_response=$(docker-compose -f deployments/tyk/docker-compose.yml -f deployments/cicd/docker-compose.yml -p tyk-pro-docker-demo-extended --project-directory $(pwd) exec jenkins bash -c "java -jar /var/jenkins_home/jenkins-cli.jar -s http://localhost:8080/ -auth admin:$jenkins_admin_password -webSocket create-job 'apis-and-policies' < /var/jenkins_home/bootstrap-import/job-apis-and-policies.xml; echo $?")
  if [ "${jenkins_response:0:1}" != "0" ]
  then
    log_message "  Request unsuccessful, retrying..."
    sleep 2
  else
    log_ok
  fi
  bootstrap_progress
done

log_end_deployment

echo -e "\033[2K 
▼ CI/CD
  ▽ Jenkins
               URL : $jenkins_base_url
          Username : admin
          Password : $jenkins_admin_password"