#!/bin/bash

num_clients=1
num_requests=20
requests_per_second=5
temp_data_path=deployments/test-rate-limit/temp.json

echo "Generating requests - $num_clients clients, sending $num_requests requests at $requests_per_second per second"
hey -c $num_clients -q $requests_per_second -n $num_requests -H "Authorization: 5per1b" http://localhost:8080/basic-protected-api/anything/a

echo "Waiting for analytics data to be available"
sleep 3

echo "Processing analytics data"
analytics_data=$(docker exec -it tyk-demo-tyk-mongo-1 mongo tyk_analytics --quiet --eval "db.getCollection('z_tyk_analyticz_5e9d9544a1dcd60001d0ed20').find({},{timestamp:1, responsecode:1}).sort({timestamp:-1}).limit($num_requests)")

# Write the data to the file after processing
echo "$analytics_data" > $temp_data_path

while read -r data; do
  echo "$data"
done < $temp_data_path

# Clean up
rm $temp_data_path