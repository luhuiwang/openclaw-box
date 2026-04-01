FROM homebrew/ubuntu24.04:latest

ARG UID=1000
ARG GID=1000

USER root

# ── Ubuntu 镜像 ───────────────────────────────────────────
RUN sed -i 's|http://[^/]*\.ubuntu\.com/ubuntu/|https://mirrors.huaweicloud.com/ubuntu/|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || \
    sed -i 's|http://[^/]*\.ubuntu\.com/ubuntu/|https://mirrors.huaweicloud.com/ubuntu/|g' /etc/apt/sources.list

# ── 系统依赖（最小化）────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash curl git make ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ── 创建与宿主同 UID/GID 的用户 ─────────────────────────────
RUN usermod -u ${UID} linuxbrew && groupmod -g ${GID} linuxbrew && \
    chown -R ${UID}:${GID} /home/linuxbrew

USER linuxbrew
WORKDIR /home/linuxbrew

# ── 初始化 brew 环境 ─────────────────────────────────────
ENV PATH="/home/linuxbrew/.linuxbrew/opt/python@3.14/libexec/bin:/home/linuxbrew/.linuxbrew/bin:${PATH}"
ENV HOMEBREW_NO_INSTALL_UPGRADE=1
ENV HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
ENV HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"

# ── 用 brew 安装 python + node + opencode + openclaw ──────
RUN brew install python node opencode openclaw-cli && \
    /home/linuxbrew/.linuxbrew/bin/python3 -m venv /home/linuxbrew/.linuxbrew/venv && \
    /home/linuxbrew/.linuxbrew/venv/bin/pip install --upgrade pip && \
    brew cleanup --prune=0

# ── pip 清华镜像 ─────────────────────────────────────────
RUN /home/linuxbrew/.linuxbrew/venv/bin/pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple && \
    /home/linuxbrew/.linuxbrew/venv/bin/pip config set global.trusted-host pypi.tuna.tsinghua.edu.cn

# ── npm 淘宝镜像 + 重试 ──────────────────────────────────
RUN npm config set registry https://registry.npmmirror.com && \
    npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000

WORKDIR /home/linuxbrew
CMD ["openclaw", "gateway"]
