FROM homebrew/ubuntu24.04:latest

ARG UID=1000
ARG GID=1000

# ── 环境变量 ─────────────────────────────────────────────
ENV HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
ENV PATH="${HOMEBREW_PREFIX}/opt/python@3.14/libexec/bin:${HOMEBREW_PREFIX}/bin:${PATH}"
ENV HOMEBREW_NO_INSTALL_UPGRADE=1
ENV HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
ENV HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"

# ── 系统配置 + python/node + 镜像源 (很少变动) ─────────────
USER root
RUN sed -i 's|http://[^/]*\.ubuntu\.com/ubuntu/|https://mirrors.huaweicloud.com/ubuntu/|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || \
    sed -i 's|http://[^/]*\.ubuntu\.com/ubuntu/|https://mirrors.huaweicloud.com/ubuntu/|g' /etc/apt/sources.list && \
    apt-get update && apt-get install -y --no-install-recommends \
        bash curl git make ca-certificates nano \
    && rm -rf /var/lib/apt/lists/* && \
    usermod -u ${UID} linuxbrew && groupmod -g ${GID} linuxbrew && \
    chown -R ${UID}:${GID} /home/linuxbrew

USER linuxbrew
RUN brew install python node && \
    brew cleanup --prune=0 && \
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip config set global.trusted-host pypi.tuna.tsinghua.edu.cn && \
    npm config set registry https://registry.npmmirror.com && \
    npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000

# ── agent 工具 (频繁更新) ────────────────────────────────
RUN npm i -g openclaw opencode-ai

WORKDIR /home/linuxbrew
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:18789/ || exit 1
CMD ["openclaw", "gateway"]
