#!/bin/bash

jenkins_base_url="http://localhost:8070"
jenkins_status=""
# 403 indicates that at least Jenkins was able to recognise that the request was unauthorised, so we should be ok to proceed
jenkins_status_desired="403"
jenkins_tries=0

while [ "$jenkins_status" != "$jenkins_status_desired" ]
do
  jenkins_tries=$((jenkins_tries+1))
  dot=$(printf "%-${jenkins_tries}s" ".")
  echo -ne "  Bootstrapping Jenkins ${dot// /.} \r"
  jenkins_status=$(curl -I -m2 $jenkins_base_url 2>/dev/null | head -n 1 | cut -d$' ' -f2)

  if [ "$jenkins_status" != "$jenkins_status_desired" ]
  then
    sleep 1
  fi
done

jenkins_admin_password=$(docker-compose -f dc.jenkins.yml exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)

docker-compose -f dc.jenkins.yml exec \
  jenkins \
  curl -L -o /var/jenkins_home/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar > /dev/null

echo -e "\033[2K           Jenkins
               URL : $jenkins_base_url
          Password : $jenkins_admin_password
"