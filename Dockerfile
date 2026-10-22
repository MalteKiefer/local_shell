FROM debian:trixie-slim

ARG USERNAME=malte
ARG PUID=1000
ARG PGID=1000
# Pinned release binaries, bumped weekly by update-pins.py
ARG TTYD_VERSION=1.7.7
ARG TTYD_SHA256_AMD64=8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55
ARG TTYD_SHA256_ARM64=b38acadd89d1d396a0f5649aa52c539edbad07f4bc7348b27b4f4b7219dd4165
ARG STARSHIP_VERSION=1.26.0
ARG STARSHIP_SHA256_AMD64=b7c232b0e8249d8e55a40beb79c5c43a7d370f3f9408bd215deb0170daeaadf3
ARG STARSHIP_SHA256_ARM64=dc30189378d2f2e287384e8a692d3f95ad1df64cf0e8c36aa9201516028aed6b
ARG BUN_VERSION=1.4.2
ARG BUN_SHA256_AMD64=36368faef7527875d5ffa52e53cd48021741f2a83eb6208a8dd64068d422a913
ARG BUN_SHA256_ARM64=54328bbc2d9c8e0c9f892c544d66c57a83b84139e34909e5ee81758f1ac8fda7
ARG NERDFONT_VERSION=3.5.1
ARG NERDFONT_SHA256=04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf
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
        git less vim procps locales tini nodejs npm \
        zoxide fzf eza bat fd-find btop lazygit \
        w3m python3 python3-pip python3-venv golang-go rustc cargo \
        ansible terraform sudo jq xz-utils \
    && sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen \
    && ln -s /usr/bin/batcat /usr/local/bin/bat \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && npm install -g @anthropic-ai/claude-code yarn \
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
