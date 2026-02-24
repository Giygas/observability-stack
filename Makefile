.DEFAULT_GOAL := help

TUNNEL   ?= none
BASE_CMD  = docker compose --env-file .env -f docker-compose.yml

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
		/^##@/ { printf "\n%s\n", substr($0, 5) }' $(MAKEFILE_LIST)
	@echo ""

##@ Setup

.PHONY: setup
setup: ## Initialize secrets and .env file
	@mkdir -p secrets
	@if [ ! -f secrets/grafana_password.txt ]; then \
		stty -echo; \
		printf "Enter Grafana admin password: "; \
		read password; \
		stty echo; \
		echo ""; \
		echo "$$password" > secrets/grafana_password.txt; \
		chmod 644 secrets/grafana_password.txt; \
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
validate-secrets:
	@if [ ! -f ./secrets/grafana_password.txt ]; then \
		echo "❌ secrets/grafana_password.txt not found. Run: make setup"; \
		exit 1; \
	fi
	@PERMS=$$(stat -c "%a" ./secrets/grafana_password.txt 2>/dev/null || stat -f "%OLp" ./secrets/grafana_password.txt); \
	if [ "$$PERMS" = "600" ] || [ "$$PERMS" = "700" ]; then \
		echo "❌ secrets/grafana_password.txt has permissions $$PERMS — container cannot read it."; \
		echo "   Run: chmod 644 secrets/grafana_password.txt"; \
		exit 1; \
	fi
	@echo "✓ Secrets validated"

##@ Stack

.PHONY: up
up: validate-secrets ## Start observability stack (TUNNEL=none|cloudflare|tailscale|wireguard)
	@echo "Starting observability stack (tunnel: $(TUNNEL))..."
	@$(BASE_CMD) up -d
	@if [ "$(TUNNEL)" != "none" ]; then \
		docker compose --env-file .env -f tunnels/$(TUNNEL).yml up -d; \
	fi
	@echo "$(GREEN)✓ Observability stack started$(RESET)"
	@echo ""
	@echo "Grafana:    http://localhost:3000"
	@echo "Prometheus: http://localhost:9090"
	@echo "Loki:       http://localhost:3100"

.PHONY: down
down: ## Stop observability stack
	@echo "Stopping observability stack..."
	@if [ "$(TUNNEL)" != "none" ]; then \
		docker compose --env-file .env -f tunnels/$(TUNNEL).yml down; \
	fi
	@$(BASE_CMD) down
	@echo "$(GREEN)✓ Observability stack stopped$(RESET)"
	
.PHONY: restart
restart: down up ## Restart the observability stack

.PHONY: logs
logs: ## View logs (use SERVICE=name to filter)
	@$(BASE_CMD) logs -f $(SERVICE)

.PHONY: status
status: ## Show stack status
	@$(BASE_CMD) ps

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
	@if [ "$(TUNNEL)" != "none" ]; then \
		docker compose --env-file .env -f tunnels/$(TUNNEL).yml down; \
	fi
		@$(BASE_CMD) down --volumes --rmi all
	@echo "$(GREEN)✓ Clean complete$(RESET)"

.PHONY: health-check
health-check: ## Quick health check (services, storage, resources)
	@echo "🏥 Observability Stack Health Check"
	@echo ""
	@echo "─────────────────────────────────"
	@echo "┌─ Services ─────────────────────┐"
	@$(COMPOSE_CMD) ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | sed '1d' | while read name status ports; do \
		service=$$(echo $$name | cut -d_ -f2); \
		if echo $$status | grep -q "healthy\|Up"; then \
			echo -e "│ $$service\t✅ $$status\tPorts: $$ports"; \
		else \
			echo -e "│ $$service\t❌ $$status\tPorts: $$ports"; \
		fi; \
	done
	@echo "└────────────────────────────────┘"
	@echo ""
	@echo "─────────────────────────────────"
	@echo "┌─ Health Endpoint Status ─────┐"
	@-curl -s -o /dev/null -w "Prometheus: %{http_code}\n" http://localhost:9090/-/healthy 2>/dev/null || echo "Prometheus:  Unreachable"
	@-curl -s -o /dev/null -w "Loki:        %{http_code}\n" http://localhost:3100/ready 2>/dev/null || echo "Loki:         Unreachable"
	@-curl -s -o /dev/null -w "Grafana:     %{http_code}\n" http://localhost:3000/api/health 2>/dev/null || echo "Grafana:      Unreachable"
	@echo "└────────────────────────────────┘"
	@echo ""
	@echo "✅ Health check complete"

.PHONY: validate
validate: ## Validate configuration and secrets
	@echo "🔍 Validating configuration..."
	@echo ""
	@echo "Checking secrets..."
	@if [ ! -f ./secrets/grafana_password.txt ]; then \
		echo "❌ secrets/grafana_password.txt not found"; \
		echo "Run: make setup"; \
		exit 1; \
	fi
	@echo "✓ secrets/grafana_password.txt exists"
	@echo ""
	@echo "Checking .env file..."
	@if [ ! -f .env ]; then \
		echo "❌ .env not found"; \
		echo "Run: cp .env.example .env"; \
		exit 1; \
	fi
	@echo "✓ .env exists"
	@echo ""
	@echo "Checking Docker daemon..."
	@if ! docker info > /dev/null 2>&1; then \
		echo "❌ Docker daemon is not running"; \
		exit 1; \
	fi
	@echo "✓ Docker daemon is running"
	@echo ""
	@echo "Checking docker compose..."
	@if ! docker compose version > /dev/null 2>&1; then \
		echo "❌ Docker Compose is not available"; \
		exit 1; \
	fi
	@echo "✓ Docker Compose is available"
	@echo ""
	@echo "Checking ports..."
	@for port in 3000 3100 9090; do \
		if lsof -Pi :$$port -sTCP:LISTEN -t > /dev/null 2>&1; then \
			echo "✓ Port $$port is available"; \
		else \
			echo "⚠️  Port $$port is in use or blocked"; \
		fi; \
	done
	@echo ""
	@echo "✅ Validation complete"
