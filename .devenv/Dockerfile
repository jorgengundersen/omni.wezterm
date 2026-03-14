FROM devenv:latest

USER root

# Lua runtime + package manager + C compiler (gcc needed for native luarocks modules)
# Note: make is already in devenv:latest (from tools-make)
RUN apt-get update && apt-get install -y --no-install-recommends \
    lua5.4 \
    liblua5.4-dev \
    luarocks \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Linting and formatting tools
RUN luarocks install luacheck \
    && luarocks install busted

# StyLua (Lua formatter) - install pre-built binary
RUN STYLUA_VERSION=2.4.0 && \
    curl -fsSL "https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA_VERSION}/stylua-linux-x86_64.zip" \
      -o /tmp/stylua.zip && \
    unzip -o /tmp/stylua.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/stylua && \
    rm -f /tmp/stylua.zip

WORKDIR /home/devuser
USER devuser
CMD ["/bin/bash"]
