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
mkdir local_shell && cd local_shell
curl -fsSLO https://raw.githubusercontent.com/MalteKiefer/local_shell/main/compose.yaml
docker compose pull
docker compose up -d
```

Open `http://<host>:7681`.

The browser terminal uses `JetBrainsMonoNL Nerd Font` for the prompt icons.
Install a [Nerd Font](https://www.nerdfonts.com/) on the machine running the
browser, otherwise the prompt shows placeholder boxes.

## Configuration

### compose.yaml

| Setting | Purpose |
|---------|---------|
| `ports` | Host port for the web terminal. Bind it to a single interface, for example `"100.64.0.10:7681:7681"`, to keep it off the LAN. |
| `TZ` | Container timezone. |
| `TTYD_CREDENTIAL` | `user:password` enables HTTP basic auth in front of the terminal. |
| `volumes` | `home` holds `/home/malte`. Add bind mounts for any NAS folders you want inside. |

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
- weekly on Monday at 04:00 UTC, without cache, to pick up package and Claude Code updates
- manually via *Run workflow*

Tags: `latest` and `sha-<commit>`. Only `linux/amd64` is built.

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

Everything under [`home/`](home/) is copied into the user's home in the image.
Docker seeds the `home` volume from it **only on first start**, while the
volume is empty. Later changes to `home/` do not reach an existing volume.
Either copy the files in by hand or recreate the volume:

```bash
docker compose down -v   # deletes everything in the container home
```

## Security

This container hands out a shell with root via `sudo` to anyone who reaches the
port. It has no TLS and, by default, no authentication.

- Only expose it on a private network or VPN (WireGuard, Tailscale, NetBird).
  Never forward the port to the internet.
- Bind the port to the VPN interface, not `0.0.0.0`.
- Set `TTYD_CREDENTIAL` as a second layer.
- The Docker socket and host paths are not mounted. Keep it that way unless you
  accept that the container can then control the host.

Supply chain: `ttyd` is pinned by SHA256, the HashiCorp key by fingerprint and
`claude_install.sh` by gist commit and SHA256. The install script itself pulls
unpinned plugins, skills and npm/pip packages, so builds are not reproducible.

## License

[MIT](LICENSE)
