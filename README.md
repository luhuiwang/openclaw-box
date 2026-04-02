# OpenClaw Docker

基于 Docker Compose + Homebrew (homebrew/ubuntu24.04) 的 OpenClaw 环境，包含 openclaw 和 opencode。

## 目录

- [快速开始](#快速开始)
- [命令一览](#命令一览)
- [特性](#特性)
- [架构概览](#架构概览)
- [数据目录](#数据目录)
- [权限处理](#权限处理)
- [环境变量](#环境变量)
- [常见问题](#常见问题)

---

## 快速开始

```bash
# 1. 检测用户 ID 并生成配置
make env

# 2. 构建 Docker 镜像
make build

# 3. 启动容器
make up
```

启动后访问 **http://127.0.0.1:18789/** 打开 OpenClaw Dashboard。

---

## 命令一览

### 基础命令

| 命令 | 说明 |
|------|------|
| `make env` | 检测 UID/GID 并生成 `.env` 配置文件 |
| `make build` | 构建 Docker 镜像 |
| `make up` | 启动容器 |
| `make down` | 停止容器 |
| `make restart` | 重启容器 |

### 调试命令

| 命令 | 说明 |
|------|------|
| `make status` | 查看容器运行状态 |
| `make logs` | 查看容器日志 (tail -f) |
| `make shell` | 进入容器 shell |

### OpenClaw 命令

| 命令 | 说明 |
|------|------|
| `make dashboard` | 获取 Dashboard 访问链接 |
| `make tui` | 进入 openclaw TUI |
| `make onboard` | 运行交互式配置向导 |
| `make opencode` | 运行 opencode CLI |

### 其他

| 命令 | 说明 |
|------|------|
| `make doctor` | 运行 openclaw 诊断检查 |
| `make clean` | 清理容器、镜像和构建缓存 |
| `make info` | 显示环境信息和配置 |
| `make help` | 显示帮助信息 |

---

## 特性

### 自动重启

容器配置了 `restart: unless-stopped`，会在以下情况自动重启：

- Docker 守护进程启动时
- 系统重启后
- 容器意外崩溃时

如果手动执行 `make down` 停止容器，则不会自动重启。

---

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                      Host Machine                            │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │  ./openclaw     │    │  ./workspace    │                │
│  │  (数据持久化)    │    │  (备用工作目录) │                │
│  └────────┬────────┘    └────────┬────────┘                │
│           │                      │                          │
│           └──────────┬───────────┘                          │
│                      │ volume mount                         │
│                      ▼                                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Container                       │   │
│  │  ┌─────────────────────────────────────────────┐   │   │
│  │  │  homebrew/ubuntu24.04                        │   │   │
│  │  │  ├── Python + Node.js (via Homebrew)         │   │   │
│  │  │  ├── opencode                                │   │   │
│  │  │  └── openclaw-cli                            │   │   │
│  │  └─────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
│                         │                                    │
│              ┌──────────┴──────────┐                       │
│              ▼                     ▼                        │
│         Port 18789             Port 18790                   │
│    (Gateway/Dashboard)      (WebSocket)                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 端口映射

| 端口 | 服务 | 说明 |
|------|------|------|
| `18789` | Gateway / Dashboard | HTTP 服务 |
| `18790` | WebSocket | 实时通信 |

### 技术栈

- **基础镜像**: `homebrew/ubuntu24.04`
- **包管理器**: Homebrew (用户级安装于 `/home/linuxbrew/.linuxbrew`)
- **Python**: via `brew install python`
- **Node.js**: via `brew install node`
- **Agent 软件**: opencode, openclaw

---

## 数据目录

### 目录映射

| 宿主机 | 容器内 | 说明 |
|--------|--------|------|
| `./openclaw` | `~/.openclaw` | OpenClaw 数据 (配置、日志、会话) |
| `./workspace` | `/workspace` | 备用工作目录 |

### 数据迁移

如果从其他服务器迁移 OpenClaw，将原有的 `~/.openclaw` 目录内容复制到本地的 `./openclaw` 目录：

```bash
# 从旧服务器复制数据
scp -r user@old-server:~/.openclaw/* ./openclaw/
```

容器启动后，数据会自动挂载到 `~/.openclaw`，无需额外配置。

---

## 权限处理

### 为什么需要处理权限

OpenClaw 的数据目录 (`~/.openclaw`) 需要持久化到宿主机 `./openclaw` 目录。如果容器内用户与宿主机用户 UID/GID 不一致，会导致：

- 文件所有者显示为数字 UID
- 宿主机无法直接编辑文件
- 可能出现权限被拒绝的错误

### 解决方案

**1. 自动匹配 UID/GID**

`make env` 会自动检测当前用户的 UID/GID 并写入 `.env`:

```bash
# .env 文件内容
HOST_UID=1000  # 宿主用户 UID
HOST_GID=1000  # 宿主用户 GID
```

**2. 构建时修改用户 ID**

Dockerfile 中使用 `usermod` 和 `groupmod` 将 `linuxbrew` 用户的 UID/GID 修改为宿主用户的值:

```dockerfile
ARG UID=1000
ARG GID=1000

RUN usermod -u ${UID} linuxbrew && groupmod -g ${GID} linuxbrew && \
    chown -R ${UID}:${GID} /home/linuxbrew
```

**3. 用户级 Homebrew 安装**

基础镜像 `homebrew/ubuntu24.04` 已经预装了 Homebrew 到 `/home/linuxbrew/.linuxbrew`（用户级安装），无需 root 权限。

### 如果遇到权限问题

手动修改 `.env` 中的 `HOST_UID` 和 `HOST_GID` 为宿主用户 ID，然后重新构建:

```bash
make clean
make build
make up
```

---

## 环境变量

`.env` 文件包含以下配置:

```bash
# 用户 ID (make env 自动生成)
HOST_UID=1000
HOST_GID=1000

# 卷挂载
WORKSPACE=./workspace
SSH_DIR=~/.ssh

# Docker 构建
DOCKER_BUILDKIT=0

# Homebrew 镜像
HOMEBREW_NO_INSTALL_UPGRADE=1
HOMEBREW_API_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles/api
HOMEBREW_BOTTLE_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles
```

---

## 常见问题

### Q: 如何查看容器日志?

```bash
make logs
```

### Q: 如何进入容器 shell?

```bash
make shell
```

### Q: 如何访问 Dashboard?

```bash
make dashboard
# 输出: http://127.0.0.1:18789/
```

### Q: 如何重新配置 OpenClaw?

```bash
make onboard
```

### Q: 如何清理所有内容?

```bash
make clean
```
