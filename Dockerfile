FROM debian:trixie-slim

ARG USERNAME=malte
ARG PUID=1000
ARG PGID=1000
# Pinned release binaries, bumped weekly by update-pins.py
ARG TTYD_VERSION=1.7.7
ARG TTYD_SHA256_AMD64=8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55
ARG TTYD_SHA256_ARM64=b38acadd89d1d396a0f5649aa52c539edbad07f4bc7348b27b4f4b7219dd4165
ARG STARSHIP_VERSION=1.27.0
ARG STARSHIP_SHA256_AMD64=10c8eb4cb3b761d9bf59ea828444c2dab36c900b7d69a69e08814b286969df89
ARG STARSHIP_SHA256_ARM64=341f5cbf24699fa0b27ec88965ad25f862ea09e15d35a543fd6ffdff1d2aa00d
ARG BUN_VERSION=1.4.4
ARG BUN_SHA256_AMD64=bf8ccbfb2b0b80159e0f9a6d15c55317add8077534dbc6130a3edb52fccb395c
ARG BUN_SHA256_ARM64=baa6bb36f51d6e58561e02bbea825038a9df454f673d6d776e8bbf86f8c7850e
ARG NERDFONT_VERSION=3.5.1
ARG NERDFONT_SHA256=04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf
ARG NVIM_VERSION=0.12.6
ARG NVIM_SHA256_AMD64=474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87
ARG NVIM_SHA256_ARM64=8f1f64a0bdb97247034038c3823c6cbad5bdf9ecd5751b85494b71c3ee04c815
ARG TREESITTER_VERSION=0.27.2
ARG TREESITTER_SHA256_AMD64=7ed56d152c52437397b9fcaa43cf341f49933cecc1ca291843f0d347c6e2cb3a
ARG TREESITTER_SHA256_ARM64=34fcc5c4fa7bdd2058a2a45a03b6eb9a49b03a93b6d52ec750f99b1516d98d33
ARG YAZI_VERSION=26.9.1
ARG YAZI_SHA256_AMD64=9b9c39decccf8cb0ff53a7d637d38f8a79d93bbd0099f4ea9c619ef6bb392f5d
ARG YAZI_SHA256_ARM64=dd569daecaae914185f295634109295ccd25c1b42b02eb89a74f651970024f2e
ARG RUFF_VERSION=0.17.4
ARG RUFF_SHA256_AMD64=d1d6ec9ce1ce0c01e23532a157a677077ba1f82f7cd2cde6f0bd75e65f85df93
ARG RUFF_SHA256_ARM64=71491cf93242d1bde15dcc628fd105f27c54738bef6b94050b9363ba6795f97e
ARG LUALS_VERSION=3.19.2
ARG LUALS_SHA256_AMD64=93ad326b10f6c00911dd8c450fa098332dbd8f9f45d1052f5636a2d54479b947
ARG LUALS_SHA256_ARM64=17b8e401a874440adeb649e5024c364f2bb9d15156c74a40e56d1ae9a1b2e4f2
ARG TAPLO_VERSION=0.10.0
ARG TAPLO_SHA256_AMD64=8fe196b894ccf9072f98d4e1013a180306e17d244830b03986ee5e8eabeb6156
ARG TAPLO_SHA256_ARM64=033681d01eec8376c3fd38fa3703c79316f5e14bb013d859943b60a07bccdcc3
ARG STYLUA_VERSION=2.6.0
ARG STYLUA_SHA256_AMD64=48ee7db28346f96f4bd545e190ab080a88a7b5a664e97649cf5d5c60426f402d
ARG STYLUA_SHA256_ARM64=278495597e3827417f3af7b9ad38011ad4a5ec725503553160ab69b7301059bb
ARG ACTIONLINT_VERSION=1.7.12
ARG ACTIONLINT_SHA256_AMD64=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
ARG ACTIONLINT_SHA256_ARM64=325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6
ARG TFLINT_VERSION=0.66.0
ARG TFLINT_SHA256_AMD64=22be11cadc25cd02401e94c0ccc91aa63467debb8485c2a755d98f4c0a9d1e2e
ARG TFLINT_SHA256_ARM64=1105a0a5ddee7cdac7957a3475571a946b839192ea1bc0c722c6c4686001067e
ARG TARGETARCH

# HashiCorp apt repo for terraform, key pinned by fingerprint
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl gpg \
    && curl -fsSL --proto '=https' --tlsv1.2 -o /tmp/hashicorp.asc https://apt.releases.hashicorp.com/gpg \
    && fpr="$(gpg --show-keys --with-colons /tmp/hashicorp.asc | awk -F: '$1=="fpr"{print $10; exit}')" \
    && [ "$fpr" = D55C0D1AC78A8D8126CB631CFC9CA96ACA026560 ] || { echo "hashicorp key fingerprint mismatch: $fpr" >&2; exit 1; } \
    && gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg /tmp/hashicorp.asc \
    && rm /tmp/hashicorp.asc \
    && printf '%s\n' 'Types: deb' 'URIs: https://apt.releases.hashicorp.com' 'Suites: trixie' \
        'Components: main' 'Signed-By: /usr/share/keyrings/hashicorp-archive-keyring.gpg' \
        > /etc/apt/sources.list.d/hashicorp.sources

RUN apt-get update && apt-get install -y --no-install-recommends \
        fish wget openssh-client rsync \
        git less procps locales tini nodejs npm \
        zoxide fzf eza bat fd-find btop lazygit ripgrep file \
        w3m python3 python3-pip python3-venv golang-go rustc cargo \
        ansible terraform sudo jq xz-utils \
        gopls terraform-ls shellcheck shfmt git-delta awscli \
        7zip poppler-utils chafa \
    && sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen \
    && ln -s /usr/bin/batcat /usr/local/bin/bat \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && npm install -g @anthropic-ai/claude-code yarn \
        bash-language-server yaml-language-server vscode-langservers-extracted \
        fish-lsp dockerfile-language-server-nodejs basedpyright \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

# ttyd is not packaged for trixie, use the pinned static release binary
RUN case "$TARGETARCH" in \
        amd64) a=x86_64;  sum=$TTYD_SHA256_AMD64 ;; \
        arm64) a=aarch64; sum=$TTYD_SHA256_ARM64 ;; \
        *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL -o /usr/local/bin/ttyd "https://github.com/tsl0922/ttyd/releases/download/$TTYD_VERSION/ttyd.$a" \
    && echo "$sum  /usr/local/bin/ttyd" | sha256sum -c - \
    && chmod +x /usr/local/bin/ttyd

# Debian's starship 1.22 lacks modules the config uses (pixi), use the pinned release
RUN case "$TARGETARCH" in \
        amd64) a=x86_64;  sum=$STARSHIP_SHA256_AMD64 ;; \
        arm64) a=aarch64; sum=$STARSHIP_SHA256_ARM64 ;; \
        *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/starship.tar.gz "https://github.com/starship/starship/releases/download/v$STARSHIP_VERSION/starship-$a-unknown-linux-musl.tar.gz" \
    && echo "$sum  /tmp/starship.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/starship.tar.gz -C /usr/local/bin starship \
    && rm /tmp/starship.tar.gz

# bun from the pinned release instead of piping bun.sh/install into bash
RUN case "$TARGETARCH" in \
        amd64) a=x64;     sum=$BUN_SHA256_AMD64 ;; \
        arm64) a=aarch64; sum=$BUN_SHA256_ARM64 ;; \
        *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/bun.zip "https://github.com/oven-sh/bun/releases/download/bun-v$BUN_VERSION/bun-linux-$a.zip" \
    && echo "$sum  /tmp/bun.zip" | sha256sum -c - \
    && python3 -I -m zipfile -e /tmp/bun.zip /tmp/bun \
    && install -m 755 "/tmp/bun/bun-linux-$a/bun" /usr/local/bin/bun \
    && ln -s bun /usr/local/bin/bunx \
    && rm -r /tmp/bun.zip /tmp/bun \
    && bun --version

# Debian's nvim 0.10 is too old for the config (vim.lsp.config, winborder), use the pinned release
RUN case "$TARGETARCH" in \
        amd64) a=x86_64; sum=$NVIM_SHA256_AMD64 ;; \
        arm64) a=arm64;  sum=$NVIM_SHA256_ARM64 ;; \
        *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/nvim.tar.gz "https://github.com/neovim/neovim/releases/download/v$NVIM_VERSION/nvim-linux-$a.tar.gz" \
    && echo "$sum  /tmp/nvim.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/nvim.tar.gz -C /opt \
    && mv "/opt/nvim-linux-$a" /opt/nvim \
    && ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim \
    && rm /tmp/nvim.tar.gz \
    && nvim --version | head -n1

# nvim-treesitter (main branch) builds parsers with the tree-sitter CLI
RUN case "$TARGETARCH" in \
        amd64) a=x64;   sum=$TREESITTER_SHA256_AMD64 ;; \
        arm64) a=arm64; sum=$TREESITTER_SHA256_ARM64 ;; \
        *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/tree-sitter.gz "https://github.com/tree-sitter/tree-sitter/releases/download/v$TREESITTER_VERSION/tree-sitter-linux-$a.gz" \
    && echo "$sum  /tmp/tree-sitter.gz" | sha256sum -c - \
    && gunzip -c /tmp/tree-sitter.gz > /usr/local/bin/tree-sitter \
    && chmod +x /usr/local/bin/tree-sitter \
    && rm /tmp/tree-sitter.gz \
    && tree-sitter --version

# yazi is not packaged for trixie
RUN case "$TARGETARCH" in \
        amd64) a=x86_64;  sum=$YAZI_SHA256_AMD64 ;; \
        arm64) a=aarch64; sum=$YAZI_SHA256_ARM64 ;; \
        *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/yazi.zip "https://github.com/sxyazi/yazi/releases/download/v$YAZI_VERSION/yazi-$a-unknown-linux-musl.zip" \
    && echo "$sum  /tmp/yazi.zip" | sha256sum -c - \
    && python3 -I -m zipfile -e /tmp/yazi.zip /tmp/yazi \
    && install -m 755 "/tmp/yazi/yazi-$a-unknown-linux-musl/yazi" "/tmp/yazi/yazi-$a-unknown-linux-musl/ya" /usr/local/bin/ \
    && rm -r /tmp/yazi.zip /tmp/yazi \
    && yazi --version

# LSP servers, formatters and linters for the nvim config that Debian does not package
RUN case "$TARGETARCH" in \
        amd64) x=x86_64;  g=amd64; l=x64 ;; \
        arm64) x=aarch64; g=arm64; l=arm64 ;; \
        *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && sum() { if [ "$TARGETARCH" = amd64 ]; then echo "$1"; else echo "$2"; fi; } \
    && get() { curl -fsSL -o "$1" "$2" && echo "$3  $1" | sha256sum -c -; } \
    && mkdir /tmp/tools && cd /tmp/tools \
    && get ruff.tar.gz "https://github.com/astral-sh/ruff/releases/download/$RUFF_VERSION/ruff-$x-unknown-linux-musl.tar.gz" "$(sum $RUFF_SHA256_AMD64 $RUFF_SHA256_ARM64)" \
    && tar -xzf ruff.tar.gz --strip-components=1 -C /usr/local/bin "ruff-$x-unknown-linux-musl/ruff" \
    && get luals.tar.gz "https://github.com/LuaLS/lua-language-server/releases/download/$LUALS_VERSION/lua-language-server-$LUALS_VERSION-linux-$l.tar.gz" "$(sum $LUALS_SHA256_AMD64 $LUALS_SHA256_ARM64)" \
    && mkdir /opt/lua-language-server && tar -xzf luals.tar.gz -C /opt/lua-language-server \
    && printf '%s\n' '#!/bin/sh' '# Default log and meta paths are inside the read-only install dir' \
        'c="${XDG_CACHE_HOME:-$HOME/.cache}/lua-language-server"' \
        'exec /opt/lua-language-server/bin/lua-language-server --logpath="$c/log" --metapath="$c/meta" "$@"' \
        > /usr/local/bin/lua-language-server \
    && chmod +x /usr/local/bin/lua-language-server \
    && get taplo.gz "https://github.com/tamasfe/taplo/releases/download/$TAPLO_VERSION/taplo-linux-$x.gz" "$(sum $TAPLO_SHA256_AMD64 $TAPLO_SHA256_ARM64)" \
    && gunzip -c taplo.gz > /usr/local/bin/taplo && chmod +x /usr/local/bin/taplo \
    && get stylua.zip "https://github.com/JohnnyMorganz/StyLua/releases/download/v$STYLUA_VERSION/stylua-linux-$x-musl.zip" "$(sum $STYLUA_SHA256_AMD64 $STYLUA_SHA256_ARM64)" \
    && python3 -I -m zipfile -e stylua.zip . && install stylua /usr/local/bin/ \
    && get actionlint.tar.gz "https://github.com/rhysd/actionlint/releases/download/v$ACTIONLINT_VERSION/actionlint_${ACTIONLINT_VERSION}_linux_$g.tar.gz" "$(sum $ACTIONLINT_SHA256_AMD64 $ACTIONLINT_SHA256_ARM64)" \
    && tar -xzf actionlint.tar.gz -C /usr/local/bin actionlint \
    && get tflint.zip "https://github.com/terraform-linters/tflint/releases/download/v$TFLINT_VERSION/tflint_linux_$g.zip" "$(sum $TFLINT_SHA256_AMD64 $TFLINT_SHA256_ARM64)" \
    && python3 -I -m zipfile -e tflint.zip . && install tflint /usr/local/bin/ \
    && cd / && rm -r /tmp/tools \
    && ruff --version && lua-language-server --version && taplo --version \
    && stylua --version && actionlint --version && tflint --version

# ttyd page with the Nerd Font embedded, so browsers need no locally installed font.
# ttyd serves its built-in page uncompressed to clients without gzip support (curl).
COPY ttyd-index.py /tmp/ttyd-index.py
RUN curl -fsSL -o /tmp/nf.tar.xz "https://github.com/ryanoasis/nerd-fonts/releases/download/v$NERDFONT_VERSION/JetBrainsMono.tar.xz" \
    && echo "$NERDFONT_SHA256  /tmp/nf.tar.xz" | sha256sum -c - \
    && tar -xJf /tmp/nf.tar.xz -C /tmp JetBrainsMonoNLNerdFontMono-Regular.ttf \
    && { ttyd -p 7999 true >/dev/null 2>&1 & pid=$!; } \
    && for i in $(seq 20); do curl -fsS -o /tmp/ttyd.html http://127.0.0.1:7999/ && break; sleep 0.5; done \
    && kill "$pid" \
    && mkdir -p /usr/local/share/ttyd \
    && python3 -I /tmp/ttyd-index.py /tmp/ttyd.html /tmp/JetBrainsMonoNLNerdFontMono-Regular.ttf /usr/local/share/ttyd/index.html \
    && rm /tmp/nf.tar.xz /tmp/JetBrainsMonoNLNerdFontMono-Regular.ttf /tmp/ttyd.html /tmp/ttyd-index.py

# Match the NAS user so files in mounted folders keep the right owner
RUN groupadd -g "$PGID" "$USERNAME" \
    && useradd -m -u "$PUID" -g "$PGID" -s /usr/bin/fish "$USERNAME" \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME" \
    && chmod 0440 "/etc/sudoers.d/$USERNAME" \
    && visudo -cf "/etc/sudoers.d/$USERNAME"

# Seeds the home volume on its first start; later changes need a fresh volume or a manual copy
COPY --chown=$PUID:$PGID home/ /home/$USERNAME/
# Pre-create so Docker does not create it as root when mounting the key files into it
RUN install -d -m 700 -o "$PUID" -g "$PGID" /home/$USERNAME/.ssh

ENV LANG=en_US.UTF-8 TERM=xterm-256color

USER $USERNAME
WORKDIR /home/$USERNAME
RUN bat cache --build >/dev/null

# Claude plugins, skills and MCP setup. Pinned to a gist commit and checked by hash;
# the script itself pulls unpinned third party code, so rebuilds are not reproducible.
ENV PATH=/home/$USERNAME/.local/bin:$PATH
RUN curl -fsSL -o /tmp/claude_install.sh https://gist.githubusercontent.com/MalteKiefer/6445e7d1d69f1d0781cacd383a9bc1a5/raw/ac8ee6f251a6b4dff80b934d50466b0ac251fe06/claude_install.sh \
    && echo "da488d5cf1b7ea26d8bf0fecb403f6a5bf0458a6224079c977c60539fba322ad  /tmp/claude_install.sh" | sha256sum -c - \
    && bash /tmp/claude_install.sh \
    && rm /tmp/claude_install.sh
EXPOSE 7681

# -W: writable (ttyd is read only by default). TTYD_CREDENTIAL=user:pass enables basic auth.
# -I serves the page with the embedded Nerd Font built above.
ENTRYPOINT ["tini", "--"]
CMD ["sh", "-c", "exec ttyd -W -p 7681 -I /usr/local/share/ttyd/index.html -t 'fontFamily=JetBrainsMono NF Web, monospace' -t 'theme={\"background\":\"#1e1e2e\",\"foreground\":\"#cdd6f4\",\"cursor\":\"#f5e0dc\"}' ${TTYD_CREDENTIAL:+-c \"$TTYD_CREDENTIAL\"} fish -l"]
