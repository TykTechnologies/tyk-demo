#!/bin/bash

source scripts/common.sh
deployment="MQTT"
log_start_deployment
log_end_deployment
echo -e "\033[2K
▼ MQTT
  ▽ Node-Red
                    URL : http://localhost:1880
  ▽ Mosquitto (Broker)
                    URL : http://localhost:1883"
