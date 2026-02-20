.DEFAULT_GOAL := help

TUNNEL   ?= none
BASE_CMD  = docker compose -f docker-compose.yml

ifeq ($(TUNNEL), none)
  COMPOSE_CMD = $(BASE_CMD)
else
  COMPOSE_CMD = $(BASE_CMD) -f tunnels/$(TUNNEL).yml
endif

# Colors
CYAN  := \033[36m
GREEN := \033[32m
RESET := \033[0m

##@ Help

.PHONY: help
help: ## Display this help message
	@echo "=========================================="
	@echo "  Observability Stack - Make Commands"
	@echo "=========================================="
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(CYAN)<target>$(RESET)\n\nTargets:\n"} \
		/^[a-zA-Z][a-zA-Z0-9_-]*:.*##/ { printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 } \
		/^##@/ { printf "\n%s\n", substr($$0, 5) }' $(MAKEFILE_LIST)
	@echo ""

##@ Setup

.PHONY: setup
setup: ## Initialize secrets and .env file
	@mkdir -p secrets
	@if [ ! -f secrets/grafana_password.txt ]; then \
		read -sp "Enter Grafana admin password: " password; \
		echo ""; \
		echo "$$password" > secrets/grafana_password.txt; \
		chmod 600 secrets/grafana_password.txt; \
		echo "✓ Created secrets/grafana_password.txt"; \
	else \
		echo "✓ secrets/grafana_password.txt already exists"; \
	fi
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "✓ Created .env from .env.example — fill in your values."; \
	else \
		echo "✓ .env already exists"; \
	fi

.PHONY: validate-secrets
validate-secrets: ## Validate required secrets exist
	@if [ ! -f ./secrets/grafana_password.txt ]; then \
		echo "❌ secrets/grafana_password.txt not found. Run: make setup"; \
		exit 1; \
	fi
	@echo "✓ Secrets validated"

##@ Stack

.PHONY: up
up: validate-secrets ## Start the observability stack (TUNNEL=none|cloudflare|tailscale|wireguard)
	@echo "Starting observability stack (tunnel: $(TUNNEL))..."
	@$(COMPOSE_CMD) up -d
	@echo "$(GREEN)✓ Observability stack started$(RESET)"
	@echo ""
	@echo "Grafana:    http://localhost:3000"
	@echo "Prometheus: http://localhost:9090"
	@echo "Loki:       http://localhost:3100"

.PHONY: down
down: ## Stop the observability stack
	@echo "Stopping observability stack..."
	@$(COMPOSE_CMD) down
	@echo "$(GREEN)✓ Observability stack stopped$(RESET)"

.PHONY: restart
restart: down up ## Restart the observability stack

.PHONY: logs
logs: ## View logs (use SERVICE=name to filter)
	@$(COMPOSE_CMD) logs -f $(SERVICE)

.PHONY: status
status: ## Show stack status
	@$(COMPOSE_CMD) ps

##@ Tunnel Shortcuts

.PHONY: up-cloudflare
up-cloudflare: ## Start with Cloudflare Tunnel
	@$(MAKE) up TUNNEL=cloudflare

.PHONY: up-tailscale
up-tailscale: ## Start with Tailscale
	@$(MAKE) up TUNNEL=tailscale

.PHONY: up-wireguard
up-wireguard: ## Start with WireGuard
	@$(MAKE) up TUNNEL=wireguard

.PHONY: up-local
up-local: ## Start with no tunnel (local/LAN only)
	@$(MAKE) up TUNNEL=none

##@ Maintenance

.PHONY: clean
clean: ## Remove containers, networks, and volumes
	@echo "Removing all observability Docker resources..."
	@$(COMPOSE_CMD) down --volumes --rmi all
	@echo "$(GREEN)✓ Clean complete$(RESET)"
