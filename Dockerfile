FROM debian:trixie-slim

ARG USERNAME=malte
ARG PUID=1000
ARG PGID=1000
ARG TTYD_VERSION=1.7.7
ARG STARSHIP_VERSION=1.26.0
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
        ansible terraform sudo jq \
    && sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen \
    && ln -s /usr/bin/batcat /usr/local/bin/bat \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && npm install -g @anthropic-ai/claude-code yarn \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

# ttyd is not packaged for trixie, use the pinned static release binary
RUN case "$TARGETARCH" in \
        amd64) a=x86_64;  sum=8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55 ;; \
        arm64) a=aarch64; sum=b38acadd89d1d396a0f5649aa52c539edbad07f4bc7348b27b4f4b7219dd4165 ;; \
        *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL -o /usr/local/bin/ttyd "https://github.com/tsl0922/ttyd/releases/download/$TTYD_VERSION/ttyd.$a" \
    && echo "$sum  /usr/local/bin/ttyd" | sha256sum -c - \
    && chmod +x /usr/local/bin/ttyd

# Debian's starship 1.22 lacks modules the config uses (pixi), use the pinned release
RUN case "$TARGETARCH" in \
        amd64) a=x86_64;  sum=b7c232b0e8249d8e55a40beb79c5c43a7d370f3f9408bd215deb0170daeaadf3 ;; \
        arm64) a=aarch64; sum=dc30189378d2f2e287384e8a692d3f95ad1df64cf0e8c36aa9201516028aed6b ;; \
        *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/starship.tar.gz "https://github.com/starship/starship/releases/download/v$STARSHIP_VERSION/starship-$a-unknown-linux-musl.tar.gz" \
    && echo "$sum  /tmp/starship.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/starship.tar.gz -C /usr/local/bin starship \
    && rm /tmp/starship.tar.gz

# Match the NAS user so files in mounted folders keep the right owner
RUN groupadd -g "$PGID" "$USERNAME" \
    && useradd -m -u "$PUID" -g "$PGID" -s /usr/bin/fish "$USERNAME" \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME" \
    && chmod 0440 "/etc/sudoers.d/$USERNAME" \
    && visudo -cf "/etc/sudoers.d/$USERNAME"

# Seeds the home volume on its first start; later changes need a fresh volume or a manual copy
COPY --chown=$PUID:$PGID home/ /home/$USERNAME/

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
# The font is resolved in the browser, so the Nerd Font must be installed on the client.
# Nerd Fonts v3 registers short "NF" family names on some systems, hence the list.
ENTRYPOINT ["tini", "--"]
CMD ["sh", "-c", "exec ttyd -W -p 7681 -t 'fontFamily=JetBrainsMonoNL Nerd Font, JetBrainsMonoNL NF, JetBrainsMono Nerd Font, JetBrainsMono NF, monospace' -t 'theme={\"background\":\"#1e1e2e\",\"foreground\":\"#cdd6f4\",\"cursor\":\"#f5e0dc\"}' ${TTYD_CREDENTIAL:+-c \"$TTYD_CREDENTIAL\"} fish -l"]
