#!/bin/bash

source scripts/common.sh
deployment="Mail Server"
log_start_deployment
log_end_deployment
echo -e "\033[2K
▼ Mailserver
  ▽ MailSlurper
            Browser URL : http://localhost:8089
               SMTP URL : http://localhost:2500"
