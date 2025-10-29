# IndiesShuffle - Development Commands
.PHONY: help dev up down build rebuild logs shell db-shell test clean

# Default docker-compose file for development
COMPOSE_FILE := docker-compose.dev.yml

help: ## Show this help message
	@echo "IndiesShuffle Development Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

dev: up ## Start development environment (alias for up)

up: ## Start all services in development mode
	docker compose -f $(COMPOSE_FILE) up -d
	@echo "🚀 Development environment started!"
	@echo "   Web: http://localhost:4000"
	@echo "   Admin: http://localhost:4000/admin (admin/admin123)"
	@echo "   Database: localhost:5432"

down: ## Stop all services
	docker compose -f $(COMPOSE_FILE) down

build: ## Build all services
	docker compose -f $(COMPOSE_FILE) build

rebuild: down build up ## Rebuild and restart all services

logs: ## Show logs for all services
	docker compose -f $(COMPOSE_FILE) logs -f

logs-web: ## Show logs for web service only
	docker compose -f $(COMPOSE_FILE) logs -f web

logs-db: ## Show logs for database service only
	docker compose -f $(COMPOSE_FILE) logs -f db

shell: ## Open shell in web container
	docker compose -f $(COMPOSE_FILE) exec web bash

db-shell: ## Open PostgreSQL shell
	docker compose -f $(COMPOSE_FILE) exec db psql -U postgres -d indies_shuffle_dev

migrate: ## Run database migrations
	docker compose -f $(COMPOSE_FILE) exec web mix ecto.migrate

seed: ## Seed database with initial data
	docker compose -f $(COMPOSE_FILE) exec web mix run priv/repo/seeds.exs

reset-db: ## Reset database (drop, create, migrate)
	docker compose -f $(COMPOSE_FILE) exec web mix ecto.reset

test: ## Run tests
	docker compose -f $(COMPOSE_FILE) exec web mix test

format: ## Format Elixir code
	docker compose -f $(COMPOSE_FILE) exec web mix format

deps: ## Get dependencies
	docker compose -f $(COMPOSE_FILE) exec web mix deps.get

clean: ## Remove all containers, volumes and images
	docker compose -f $(COMPOSE_FILE) down -v --remove-orphans
	docker compose -f $(COMPOSE_FILE) down --rmi all

status: ## Show status of all services
	docker compose -f $(COMPOSE_FILE) ps

# Production commands
prod-up: ## Start production environment
	docker compose -f docker-compose.prod.yml up -d

prod-down: ## Stop production environment
	docker compose -f docker-compose.prod.yml down

prod-logs: ## Show production logs
	docker compose -f docker-compose.prod.yml logs -f

# Health checks
health: ## Check health of all services
	@echo "🔍 Checking service health..."
	@docker compose -f $(COMPOSE_FILE) ps --format "table {{.Service}}\t{{.Status}}\t{{.Health}}"