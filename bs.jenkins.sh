#!/bin/bash

echo "           Jenkins"

jenkins_base_url="http://localhost:8070"
jenkins_admin_password=$(docker-compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)

docker-compose exec \
  jenkins \
  curl -L -o /var/jenkins_home/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar > /dev/null

cat <<EOF
               URL : $jenkins_base_url
          Password : $jenkins_admin_password
          
EOF