options:
	@echo "You can use make with the following options: \n \
    boot - Boot the deployments using up.sh.\n \
           Using "deploy" arg, you can use add combination of the following arguments is possible: instrumentation, analytics, sso, tracing, cicd, tls  \n \
           For example you can run: \n \
             make boot \n \
             make boot deploy=\"sso tracing cicd\" \n \
    up - To start up all the containers (docker-compose up)\n \
    ps - To list the containers (docker-compose ps) \n \
    stop - To stop the containers (docker-compose stop) \n \
    down - To stop the containers and umunt the volumes (docker-compose down -v)  \n \
    restart - To restart the containers and umunt the volumes (docker-compose restart)  \n \
    gateway-log - To fetch the logs of the gateway (docker-compose logs -f)  \n \
    pump-log - To fetch the logs of the pump (docker-compose logs -f)  \n \
    dashboard-log - To fetch the logs of the dashboard (docker-compose logs -f)  \n \
    dashbord-log-saved - To saved the log of the dashboard to a local file(docker-compose logs -f)  \n \
    hello - To test the gateway's responsivity using the /hello endpoint\n \
		\n "

boot:
	./up.sh $(deploy)

up:
	docker-compose -f deployments/tyk/docker-compose.yml -p tyk-demo --project-directory $(pwd) . up -d

ps:
	docker-compose -f deployments/tyk/docker-compose.yml -p tyk-demo --project-directory $(pwd) . ps

stop:
	docker-compose -f deployments/tyk/docker-compose.yml -p tyk-demo --project-directory $(pwd) . stop

restart:
	docker-compose -f deployments/tyk/docker-compose.yml -p tyk-demo --project-directory $(pwd) . restart

down:
	./down.sh

gateway-log:
	docker-compose -f deployments/tyk/docker-compose.yml -p tyk-demo --project-directory $(pwd) . logs -f tyk-gateway

pump-log:
	docker-compose -f deployments/tyk/docker-compose.yml -p tyk-demo --project-directory $(pwd) . logs -f tyk-pump

dashboard-log:
	docker-compose -f deployments/tyk/docker-compose.yml -p tyk-demo --project-directory $(pwd) . logs -f tyk-dashboard

dashbord-log-saved:
	docker-compose -f deployments/tyk/docker-compose.yml -p tyk-demo --project-directory $(pwd) . logs tyk-dashboard > /tmp/dashboard-log 2>&1
	@echo "Saved dashboard logs to /tmp/dashboard-log"

hello:
	curl -s http://tyk-gateway.localhost:8080/hello
