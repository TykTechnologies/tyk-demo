This command calls a load balanced API (2 upstreams), using 1 client at 5 requests per second for a total of 10 requests:
```
hey -c 1 -q 5 -n 10 -H "Authorization: 5per1" http://localhost:8080/load-balanced-api-auth/anything/a
```

This command calls a standard API (1 upstream), using 1 client at 5 requests per second for a total of 20 requests:
```
hey -c 1 -q 5 -n 20 -H "Authorization: 5per1b" http://localhost:8080/basic-protected-api/anything/a
```


Don't run mongo query too soon after generating requests, as the pump needs time to generate the analytics records. This shouldn't need more than a few seconds.

This mongoDB query will show the last 10 requests, with the response code and timestamp:
```
db.getCollection('z_tyk_analyticz_5e9d9544a1dcd60001d0ed20').find({},{timestamp:1, responsecode:1}).sort({timestamp:-1}).limit(10)
```    

This command runs the query inside of the mongo docker container:
docker exec -it tyk-demo-tyk-mongo-1 mongo tyk_analytics --quiet --eval "db.getCollection('z_tyk_analyticz_5e9d9544a1dcd60001d0ed20').find({},{timestamp:1, responsecode:1}).sort({timestamp:-1}).limit(20)"



mongo tyk_analytics --quiet --eval "db.getCollection('z_tyk_analyticz_5e9d9544a1dcd60001d0ed20').find({},{timestamp:1, responsecode:1}).sort({timestamp:-1}).limit(10)"

mongoexport --db tyk_analytics --collection z_tyk_analyticz_5e9d9544a1dcd60001d0ed20 --type=csv --fields timestamp,responsecode --sort timestamp:-1 --limit 10 --out output.csv

mongoexport --db tyk_analytics --collection z_tyk_analyticz_5e9d9544a1dcd60001d0ed20 --type=csv --fields timestamp,responsecode --sort '{"timestamp": -1}' --limit 10 --out output.csv