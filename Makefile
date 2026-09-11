COMPOSE = docker compose -f srcs/docker-compose.yml

DATA_DIR = /home/$(USER)/data
MARIADB_DATA = $(DATA_DIR)/mariadb
WORDPRESS_DATA = $(DATA_DIR)/wordpress

all: up

up:
	mkdir -p $(MARIADB_DATA)
	mkdir -p $(WORDPRESS_DATA)
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs

ps:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down

fclean:
	$(COMPOSE) down -v
	docker system prune -af

re: fclean all

.PHONY: all up down stop start restart logs ps clean fclean re