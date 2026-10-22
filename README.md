# local_shell

A full Linux terminal in your browser, running in Docker. Built for a home NAS:
start the container, open the port, get a fish shell with your tools and
Claude Code ready to go.

The terminal is served by [ttyd](https://github.com/tsl0922/ttyd). The user's
home directory lives in a Docker volume, so history, SSH keys and Claude
settings survive restarts and image updates.

## What's inside

Base image: `debian:trixie-slim`

| Area | Tools |
|------|-------|
| Shell | fish (with fisher, fzf.fish, autopair, puffer-fish, done), starship, zoxide |
| CLI | curl, wget, openssh-client, rsync, git, jq, vim, less, w3m, sudo |
| Modern replacements | eza, bat, fd, fzf, btop, lazygit |
| Languages | python3 (pip, venv), Go, Rust (rustc, cargo), Node.js (npm, yarn) |
| Ops | ansible, terraform (HashiCorp apt repo) |
| AI | Claude Code, plus plugins and skills from [`claude_install.sh`](https://gist.github.com/MalteKiefer/6445e7d1d69f1d0781cacd383a9bc1a5) |

Theme is Catppuccin Mocha throughout: fish, starship, bat, fzf and the browser terminal.

## Quick start

```bash
git clone https://github.com/MalteKiefer/local_shell.git && cd local_shell
cp .env.example .env    # then set a strong password in .env
docker compose pull
docker compose up -d
```

Open `http://<host>:7681` and log in with the credentials from `.env`.

The browser terminal uses `JetBrainsMono Nerd Font` (NL or regular) for the prompt icons.
Install a [Nerd Font](https://www.nerdfonts.com/) on the machine running the
browser, otherwise the prompt shows placeholder boxes.

## Configuration

### compose.yaml

| Setting | Purpose |
|---------|---------|
| `ports` | Host port for the web terminal. Bind it to a single interface, for example `"100.64.0.10:7681:7681"`, to keep it off the LAN. |
| `TZ` | Container timezone. |
| `TTYD_CREDENTIAL` | `user:password` for HTTP basic auth, read from `.env`. Required: compose refuses to start without it. |
| `volumes` | `home` holds `/home/malte`. `./home/.config` provides the live dotfiles. Add bind mounts for any NAS folders you want inside. |

### SSH keys

`~/.ssh/id_ed25519` and `id_ed25519.pub` of the host user running compose are
mounted read-only. Only the key pair, never the whole directory: a writable
`~/.ssh` would let anyone with the web shell add a key to the host's
`authorized_keys`. `known_hosts` lives in the home volume.

- The files must exist on the host. Otherwise Docker creates empty directories
  in their place. Adjust the paths for other key types.
- `PUID` must own the key and its mode must be `600`, or ssh rejects it.
- Uncomment the `config` line in `compose.yaml` to use your SSH config as well.
- Better: create a separate key just for this container, so revoking it does
  not touch your main key.

### User and permissions

The container user is created at build time. Set these as
[repository variables](https://docs.github.com/en/actions/learn-github-actions/variables)
(Settings → Secrets and variables → Actions → Variables) in your fork:

| Variable | Default | Notes |
|----------|---------|-------|
| `USERNAME` | `malte` | Also change the volume path in `compose.yaml`. |
| `PUID` | `1000` | Match `id -u` on the host so bind mounts keep the right owner. |
| `PGID` | `1000` | Match `id -g` on the host. |

The user has passwordless `sudo` inside the container.

## Image builds

[`.github/workflows/build.yml`](.github/workflows/build.yml) builds the image and
pushes it to `ghcr.io/maltekiefer/local_shell`:

- on every push to `main`
- weekly on Monday at 04:00 UTC, to pick up package and Claude Code updates
- manually via *Run workflow*

Tags: `latest` and `sha-<commit>`. Only `linux/amd64` is built. Builds run
without a layer cache: uploading it took longer than the time it saved.

Update a running container:

```bash
docker compose pull && docker compose up -d
```

### Building locally

```bash
docker build -t local_shell \
  --build-arg USERNAME=malte --build-arg PUID=1000 --build-arg PGID=1000 .
```

## Dotfiles

`compose.yaml` bind-mounts `./home/.config` from the checkout to `~/.config`
in the container. Edit the files on the host, in the container or via
`git pull`: a new shell (or `exec fish`) picks them up. No rebuild needed.

- Clone the repo as the host user matching `PUID`/`PGID`, so the container can write to it.
- Every tool in the container writes its config to `~/.config`, so it lands in
  `home/.config` on the host. [`home/.config/.gitignore`](home/.config/.gitignore)
  tracks only `fish/`, `bat/` and `starship.toml`. The rest, including tokens
  such as `gh/hosts.yml`, stays local and untracked. Never `git add -f` there.
- A new bat theme needs `bat cache --build` once.

The image also contains a copy of `home/` as a fallback when the folder is not mounted.

## Security

This container hands out a shell with root via `sudo` to anyone who reaches the
port and passes basic auth. It has no TLS, so the password travels in clear
text unless the network is encrypted.

- Only expose it on a private network or VPN (WireGuard, Tailscale, NetBird).
  Never forward the port to the internet.
- Bind the port to the VPN interface, not `0.0.0.0`.
- Use a strong `TTYD_CREDENTIAL`.
- Anyone with the shell can read the mounted SSH private key.
- The Docker socket is not mounted, and host paths only as listed above. Keep it
  that way unless you accept that the container can then control the host.

Supply chain: `ttyd` and `starship` are pinned by SHA256, the HashiCorp key by fingerprint and
`claude_install.sh` by gist commit and SHA256. The install script itself pulls
unpinned plugins, skills and npm/pip packages, so builds are not reproducible.

## License

[MIT](LICENSE)
