# =============================================================================
# openclaw-box Makefile
# =============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# -----------------------------------------------------------------------------
# 变量定义
# -----------------------------------------------------------------------------
COMPOSE      := docker compose
SERVICE      := openclaw-box
PORT_GATEWAY := 18789
PORT_WS      := 18790

-include .env
HOST_UID := $(shell echo $${HOST_UID:-$$(id -u)})
HOST_GID := $(shell echo $${HOST_GID:-$$(id -g)})

# -----------------------------------------------------------------------------
# 前置检查 (内部使用，不显示在帮助中)
# -----------------------------------------------------------------------------
.PHONY: check-env check-running
check-env:
	@if [ ! -f .env ]; then \
		echo "❌ .env 不存在，请先运行 make env"; \
		exit 1; \
	fi

check-running:
	@if ! $(COMPOSE) ps $(SERVICE) 2>/dev/null | grep -q "Up"; then \
		echo "❌ 容器 $(SERVICE) 未运行，请先运行 make up"; \
		exit 1; \
	fi

# =============================================================================
# 默认目标: 帮助 (自动从 ## 注释生成)
# =============================================================================
.PHONY: help
help: ## 显示帮助
	@echo "🦞 openclaw-box"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		sed 's/^[^:]*://' | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "变量:"
	@echo "  NO_CACHE=1         强制构建时不使用缓存"
	@echo "  ARGS=\"...\"         传递参数给 opencode"

# =============================================================================
# 1. 首次初始化
# =============================================================================
.PHONY: env
env: ## 生成 .env 配置文件
	@echo "📝 生成 .env 配置文件..."
	@echo "# 用户 ID" > .env
	@echo "HOST_UID=$$(id -u)" >> .env
	@echo "HOST_GID=$$(id -g)" >> .env
	@echo "" >> .env
	@echo "# 卷挂载" >> .env
	@echo "WORKSPACE=./workspace" >> .env
	@echo "SSH_DIR=$$HOME/.ssh" >> .env
	@echo "" >> .env
	@echo "# Docker 构建" >> .env
	@echo "DOCKER_BUILDKIT=0" >> .env
	@echo "" >> .env
	@echo "# Homebrew 镜像" >> .env
	@echo "HOMEBREW_NO_INSTALL_UPGRADE=1" >> .env
	@echo "HOMEBREW_API_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles/api" >> .env
	@echo "HOMEBREW_BOTTLE_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles" >> .env
	@echo "✅ .env 已生成"

# =============================================================================
# 2. 配置 openclaw
# =============================================================================
.PHONY: onboard
onboard: check-env ## 交互式配置向导
	$(COMPOSE) run --rm -it $(SERVICE) openclaw onboard

# =============================================================================
# 3. 启动/运行
# =============================================================================
.PHONY: build up
build: check-env ## 构建镜像 (NO_CACHE=1 强制)
	DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) $(COMPOSE) build \
		--build-arg UID=$(HOST_UID) --build-arg GID=$(HOST_GID) \
		$(if $(NO_CACHE),--no-cache,)

up: check-env ## 启动容器
	$(COMPOSE) up -d

# =============================================================================
# 4. 查看状态/日志
# =============================================================================
.PHONY: logs status
logs: check-running ## 查看日志
	$(COMPOSE) logs -f $(SERVICE)

status: ## 查看状态
	@$(COMPOSE) ps $(SERVICE)

# =============================================================================
# 5. 重启/停止
# =============================================================================
.PHONY: restart down
restart: check-running ## 重启容器
	$(COMPOSE) restart $(SERVICE)

down: ## 停止容器
	$(COMPOSE) down

# =============================================================================
# 6. 运行命令
# =============================================================================
.PHONY: dashboard tui shell opencode
dashboard: check-running ## Dashboard 链接
	@TOKEN=$$($(COMPOSE) exec $(SERVICE) bash -c 'cat ~/.openclaw/openclaw.json | jq -r ".gateway.auth.token"') && \
	echo "Dashboard: http://127.0.0.1:$(PORT_GATEWAY)/?authToken=$$TOKEN"

tui: check-running ## 终端 UI
	$(COMPOSE) exec -it $(SERVICE) openclaw tui

shell: check-running ## 进入 shell
	$(COMPOSE) exec $(SERVICE) bash

opencode: check-running ## 运行 opencode
	$(COMPOSE) exec $(SERVICE) opencode $(ARGS)

# =============================================================================
# 7. 信息
# =============================================================================
.PHONY: info doctor
info: check-env ## 环境信息
	@$(COMPOSE) run --rm $(SERVICE) bash -c '\
		echo "=== 环境 ==="; \
		echo "用户: $$(whoami) (uid=$$(id -u))"; \
		echo "Node: $$(node --version)"; \
		echo "brew: $$(brew --version 2>&1 | head -1)"; \
		echo "opencode: $$(command -v opencode && opencode --version 2>&1 | head -1)"; \
		echo "openclaw: $$(command -v openclaw && openclaw --version 2>&1 | head -1)"'

doctor: check-running ## 诊断检查
	$(COMPOSE) exec $(SERVICE) openclaw doctor

# =============================================================================
# 8. 清理
# =============================================================================
.PHONY: clean
clean: ## 清理容器和镜像
	@$(COMPOSE) down --rmi local --volumes 2>/dev/null || true
