# =============================================================================
# openclaw-box Makefile
# =============================================================================

SHELL := /bin/bash
.COMPILER := classic

# 默认目标: 帮助
.PHONY: help
help: ## 显示帮助
	@echo "🦞 openclaw-box"
	@echo ""
	@echo "1️⃣ 首次:    make env"
	@echo "2️⃣ 配置:    make onboard"
	@echo "3️⃣ 启动:    make build && make up"
	@echo "4️⃣ 状态:    make status | make logs"
	@echo "5️⃣ 重启停止: make restart | make down"
	@echo "6️⃣ 运行:    make dashboard | make tui | make shell | make opencode"
	@echo "7️⃣ 信息:    make info | make help"
	@echo "8️⃣ 清理:    make clean"
	@echo ""
	@echo "完整命令:"
	@echo "  make env             生成 .env"
	@echo "  make build           构建镜像 (NO_CACHE=1 强制)"
	@echo "  make up              启动"
	@echo "  make logs            日志"
	@echo "  make status          状态"
	@echo "  make restart         重启"
	@echo "  make down            停止"
	@echo "  make dashboard       Dashboard 链接"
	@echo "  make tui             终端 UI"
	@echo "  make shell           进入 shell"
	@echo "  make opencode        运行 opencode"
	@echo "  make info            环境信息"
	@echo "  make help            帮助"
	@echo "  make clean           清理"

# -----------------------------------------------------------------------------
# 变量定义
# -----------------------------------------------------------------------------
COMPOSE := docker compose
-include .env
HOST_UID := $(shell echo $${HOST_UID:-$$(id -u)})
HOST_GID := $(shell echo $${HOST_GID:-$$(id -g)})

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
onboard: ## 交互式配置向导
	$(COMPOSE) exec -it openclaw-box openclaw onboard

# =============================================================================
# 3. 启动/运行
# =============================================================================
.PHONY: build up
build: ## 构建镜像 (NO_CACHE=1 强制)
	DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) $(COMPOSE) build \
		--build-arg UID=$(HOST_UID) --build-arg GID=$(HOST_GID) \
		$(if $(NO_CACHE),--no-cache,)

up: ## 启动容器
	$(COMPOSE) up -d

# =============================================================================
# 4. 查看状态/日志
# =============================================================================
.PHONY: logs status
logs: ## 查看日志
	$(COMPOSE) logs -f openclaw-box

status: ## 查看状态
	@$(COMPOSE) ps openclaw-box

# =============================================================================
# 5. 重启/停止
# =============================================================================
.PHONY: restart down
restart: ## 重启容器
	$(COMPOSE) restart openclaw-box

down: ## 停止容器
	$(COMPOSE) down

# =============================================================================
# 6. 运行命令
# =============================================================================
.PHONY: dashboard tui shell opencode
dashboard: ## Dashboard 链接
	@TOKEN=$$($(COMPOSE) exec openclaw-box bash -c 'cat ~/.openclaw/openclaw.json | jq -r ".gateway.auth.token"') && \
	echo "Dashboard: http://127.0.0.1:18789/?authToken=$$TOKEN"

tui: ## 终端 UI
	$(COMPOSE) exec -it openclaw-box openclaw tui

shell: ## 进入 shell
	$(COMPOSE) exec openclaw-box bash

opencode: ## 运行 opencode
	$(COMPOSE) exec openclaw-box opencode $(ARGS)

# =============================================================================
# 7. 信息
# =============================================================================
.PHONY: info
info: ## 环境信息
	@$(COMPOSE) run --rm openclaw-box bash -c '\
		echo "=== 环境 ==="; \
		echo "用户: $$(whoami) (uid=$$(id -u))"; \
		echo "Node: $$(node --version)"; \
		echo "brew: $$(brew --version 2>&1 | head -1)"; \
		echo "opencode: $$(command -v opencode && opencode --version 2>&1 | head -1)"; \
		echo "openclaw: $$(command -v openclaw && openclaw --version 2>&1 | head -1)"'

# =============================================================================
# 8. 清理
# =============================================================================
.PHONY: clean
clean: ## 清理容器和镜像
	@$(COMPOSE) down --rmi local --volumes 2>/dev/null || true
