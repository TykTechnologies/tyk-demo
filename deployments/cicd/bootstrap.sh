#!/bin/bash

source scripts/common.sh
deployment="CI/CD"
log_start_deployment
bootstrap_progress

jenkins_base_url="http://localhost:8070"
gitea_base_url="http://localhost:13000"
dashboard2_base_url="http://localhost:3002"

log_message "Checking Tyk Environment 2 deployment exists"
command_docker_compose="$(generate_docker_compose_command) ps | grep \"tyk2-dashboard\""
tyk2_dashboard_service=$(eval $command_docker_compose)
# Fail if cicd deployment is made without the tyk2 deployment
if [[ "${#tyk2_dashboard_service}" -eq "0" ]]
then
  log_message "  ERROR: Tyk Environment 2 deployment not found."
  log_message "         CI/CD feature will not work as intended."
  log_message "         Ensure 'tyk2' parameter is used when calling up.sh script: ./up.sh tyk2 cicd"
  exit 1
else
  log_ok
fi
bootstrap_progress

log_message "Waiting for Gitea to be ready"
wait_for_response $gitea_base_url "200"

log_message "Initialising Gitea"
gitea_username="gitea-user"
gitea_password="qx3zZ9VAgyLVjemSJWeYF6e8"
echo $gitea_username > .context-data/gitea-username
echo $gitea_password > .context-data/gitea-password
result=$(curl $gitea_base_url/install \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data 'db_type=SQLite3&db_host=localhost%3A3306&db_user=root&db_passwd=&db_name=gitea&ssl_mode=disable&charset=utf8&db_path=%2Fdata%2Fgitea%2Fgitea.db&app_name=Gitea%3A+Git+with+a+cup+of+tea&repo_root_path=%2Fdata%2Fgit%2Frepositories&lfs_root_path=%2Fdata%2Fgit%2Flfs&run_user=git&domain=localhost&ssh_port=22&http_port=13000&app_url=http%3A%2F%2Flocalhost%3A13000%2F&log_root_path=%2Fdata%2Fgitea%2Flog&smtp_host=&smtp_from=&smtp_user=&smtp_passwd=&enable_federated_avatar=on&enable_open_id_sign_in=on&enable_open_id_sign_up=on&default_allow_create_organization=on&default_enable_timetracking=on&no_reply_address=noreply.localhost&admin_name=gitea-admin&admin_passwd=x%23UF80R%26NOan&admin_confirm_passwd=x%23UF80R%26NOan&admin_email=gitea-admin%40example.org' -s -o /dev/null -w "%{http_code}")
if [ "$result" == "302" ]
then
  log_ok
else
  log_message "  ERROR: Expected 302 status, but got $result"
  log_message "  Please check Gitea container logs for more information"
  exit 1
fi
bootstrap_progress

log_message "Restoring Gitea database"
command_docker_compose="$(generate_docker_compose_command) exec -T gitea sh -c \"./data/restore.sh\" 1>> /dev/null 2>> bootstrap.log" 
eval $command_docker_compose
log_ok
bootstrap_progress

log_message "Regenerating Gitea hooks"
command_docker_compose="$(generate_docker_compose_command) exec -T -u git gitea sh -c \"gitea admin regenerate hooks;\" 1>> /dev/null 2>> bootstrap.log" 
eval $command_docker_compose
log_ok
bootstrap_progress

log_message "Restarting Gitea container"
command_docker_compose="$(generate_docker_compose_command) restart gitea 2> /dev/null" 
eval $command_docker_compose
log_ok
bootstrap_progress

log_message "Waiting for Gitea to be ready after restart"
wait_for_response $gitea_base_url "200"

log_message "Setting up repository"
gitea_tyk_data_repo_path="/tmp/tyk-demo/tyk-data"
echo $gitea_tyk_data_repo_path > .context-data/gitea-tyk-data-repo-path
# delete any repo data which may already exist
rm -rf $gitea_tyk_data_repo_path > /dev/null
bootstrap_progress
# clone repo
git clone -q http://localhost:13000/gitea-user/tyk-data.git $gitea_tyk_data_repo_path 2>> bootstrap.log
bootstrap_progress
# commit Jenkinsfile to repo (left uncommitted until now so it can be easily edited)
cp ./deployments/cicd/data/jenkins/Jenkinsfile $gitea_tyk_data_repo_path
git -C $gitea_tyk_data_repo_path add . 1> /dev/null 2>> bootstrap.log
git -C $gitea_tyk_data_repo_path commit -m "Adding Jenkinsfile" 1> /dev/null 2>> bootstrap.log
git -C $gitea_tyk_data_repo_path push "http://$gitea_username:$gitea_password@localhost:13000/gitea-user/tyk-data.git/" 1> /dev/null 2>> bootstrap.log
log_ok

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
# 403 indicates that at least Jenkins was able to recognise that the request was unauthorised, so we should be ok to proceed
wait_for_response "$jenkins_base_url" "403"

log_message "Getting Jenkins admin password"
command_docker_compose="$(generate_docker_compose_command) exec -T jenkins sh -c \"cat /var/jenkins_home/secrets/initialAdminPassword | head -c32\" 2>> bootstrap.log"
jenkins_admin_password=$(eval $command_docker_compose)
log_message "  Jenkins admin password = $jenkins_admin_password"
bootstrap_progress

log_message "Extracting Jenkins plugins and other configuration"
command_docker_compose="$(generate_docker_compose_command) exec -T \
  jenkins \
  tar -xzvf /var/jenkins_home/bootstrap-import/jenkins-plugins.tar.gz -C /var/jenkins_home 1> /dev/null 2>> bootstrap.log"
eval $command_docker_compose
log_ok
bootstrap_progress

log_message "Restarting Jenkins container to allow new config and plugins to be used"
command_docker_compose="$(generate_docker_compose_command) restart jenkins 2> /dev/null"
eval $command_docker_compose
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
    log_message "  ERROR: Unable to make API calls to Tyk Environment 2 Dashboard."
    log_message "         CI/CD feature will not work as intended."
    log_message "         Rerun up.sh script with 'tyk2' parameter before 'cicd' parameter: ./up.sh tyk2 cicd"
    log_message "         If 'tyk2' was provided, then check the tyk2_dashboard container logs for more information"
    exit 1
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

log_message "Waiting for Jenkins CLI to be ready"
# After the container restart, Jenkins functionality will not work for a little while, so we have to test if it's ready be checking if we can make a successful CLI call
jenkins_response=""
while [ "$jenkins_response" == "" ]
do
  command_docker_compose="$(generate_docker_compose_command) exec -T jenkins bash -c \"java -jar /var/jenkins_home/jenkins-cli.jar -s http://localhost:8080/ -auth admin:$jenkins_admin_password -webSocket who-am-i\" 2>> /dev/null"
  jenkins_response=$(eval $command_docker_compose)
  if [ "$jenkins_response" == "" ]
  then
    log_message "  Request unsuccessful, retrying..."
    # Jenkins CLI calls are generally pretty slow, so there's no need to sleep before retrying
  else
    log_ok
  fi
  bootstrap_progress
done

log_message "Importing credentials for 'global'"
jenkins_response=""
while [ "${jenkins_response:0:1}" != "0" ]
do
  command_docker_compose="$(generate_docker_compose_command) exec -T jenkins bash -c \"java -jar /var/jenkins_home/jenkins-cli.jar -s http://localhost:8080/ -auth admin:$jenkins_admin_password -webSocket import-credentials-as-xml system::system::jenkins < /var/jenkins_home/bootstrap-import/credentials-global.xml; echo $?\""
  jenkins_response=$(eval $command_docker_compose)
  if [ "${jenkins_response:0:1}" != "0" ]
  then
    log_message "  Request unsuccessful, retrying..."
  else
    log_ok
  fi
  bootstrap_progress
done

log_message "Creating job for 'APIs and Policies'"
jenkins_response=""
while [ "${jenkins_response:0:1}" != "0" ]
do
  command_docker_compose="$(generate_docker_compose_command) exec -T jenkins bash -c \"java -jar /var/jenkins_home/jenkins-cli.jar -s http://localhost:8080/ -auth admin:$jenkins_admin_password -webSocket create-job 'apis-and-policies' < /var/jenkins_home/bootstrap-import/job-apis-and-policies.xml; echo $?\""
  jenkins_response=$(eval $command_docker_compose)
  if [ "${jenkins_response:0:1}" != "0" ]
  then
    log_message "  Request unsuccessful, retrying..."
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
               Password : $jenkins_admin_password
  ▽ Gitea
                    URL : $gitea_base_url
               Username : $gitea_username
               Password : $gitea_password"