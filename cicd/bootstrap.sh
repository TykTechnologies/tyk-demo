#!/bin/bash

function bootstrap_progress {
  dot_count=$((dot_count+1))
  dots=$(printf "%-${dot_count}s" ".")
  echo -ne "  Bootstrapping Jenkins ${dots// /.} \r"
}

jenkins_base_url="http://localhost:8070"
jenkins_status=""
# 403 indicates that at least Jenkins was able to recognise that the request was unauthorised, so we should be ok to proceed
jenkins_status_desired="403"
jenkins_tries=0

while [ "$jenkins_status" != "$jenkins_status_desired" ]
do
  jenkins_status=$(curl -I -m2 $jenkins_base_url 2>/dev/null | head -n 1 | cut -d$' ' -f2)
  if [ "$jenkins_status" != "$jenkins_status_desired" ]
  then
    sleep 1
  fi
  bootstrap_progress
done

jenkins_admin_password=$(docker-compose -f docker-compose.yml -f cicd/docker-compose.yml exec jenkins sh -c "cat /var/jenkins_home/secrets/initialAdminPassword | head -c32")
bootstrap_progress

# extract plugins and other configuration
docker-compose -f docker-compose.yml -f cicd/docker-compose.yml exec \
  jenkins \
  tar -xzvf /var/jenkins_home/jenkins.tar.gz -C /var/jenkins_home > /dev/null
bootstrap_progress

# restart contaner to allow new config and plugins to be used
docker-compose -f docker-compose.yml -f cicd/docker-compose.yml restart jenkins 2> /dev/null
bootstrap_progress

# create job for 'APIs and Policies'
jenkins_response=""
while [ "${jenkins_response:0:1}" != "0" ]
do
  jenkins_response=$(docker-compose -f docker-compose.yml -f cicd/docker-compose.yml exec jenkins bash -c "java -jar /var/jenkins_home/jenkins-cli.jar -s http://localhost:8080/ -auth admin:$jenkins_admin_password -webSocket create-job 'apis-and-policies'</var/jenkins_home/job-apis-and-policies.xml; echo $?")
  if [ "${jenkins_response:0:1}" != "0" ]
  then
    sleep 1
  fi
  bootstrap_progress
done

echo -e "\033[2K           Jenkins
               URL : $jenkins_base_url
          Username : admin
          Password : $jenkins_admin_password
"