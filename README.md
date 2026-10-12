# SALASROCK homelab Compose

Docker Compose projects for homelab host **SALASROCK** (Ubuntu 26.04, Docker 29, ZFS, NVIDIA RTX 3060, Coral TPU). On the host this repo is `/nas/docker`. Each directory is one stack, `/nas/docker/<stack>`, with its own `docker-compose.yml` or `docker-compose.yaml`. Start `swag` first: that project creates the `shared-net` network the others join.

```text
/nas/docker/<stack>/docker-compose.yml
/nas/docker/<stack>/.env.example   # committed template, when the stack has one
/nas/docker/<stack>/.env           # local copy, never committed
```

Plex, Immich, Nextcloud, and PhotoSorter bind-mount media from other `/nas` datasets (`/nas/home_content`, `/nas/tv_content`). Those paths are outside this git repo.

## Stacks

| Stack | Purpose | SWAG |
| --- | --- | --- |
| `baseballforward` | Baseball recruiting and members site (API, two UIs, Postgres) | Yes |
| `healthchecks` | Cron and heartbeat monitoring | Yes |
| `homeassistant` | Home Assistant, MQTT, Zigbee2MQTT, Z-Wave JS UI, ESPHome, code-server, Frigate | Yes |
| `immich` | Photo and video library (server, CUDA ML, Valkey, Postgres) | Partial |
| `mailrise` | SMTP-to-notification relay | No |
| `mealie` | Recipes and meal planning | Yes |
| `nextcloud` | Nextcloud with MariaDB and Redis | Yes |
| `obsidian` | Obsidian in the browser plus CouchDB LiveSync | Yes |
| `ollama` | Ollama and Open WebUI (WebUI is proxied) | Yes |
| `omada` | TP-Link Omada controller | Partial |
| `openclaw` | OpenClaw gateway and CLI | Yes |
| `photosorter` | Photo-sorting API over NAS media | No |
| `plex` | Plex media server with NVIDIA transcoding | Partial |
| `portainer` | Portainer CE | Yes |
| `prometheus` | Prometheus, Grafana, node-exporter, NVIDIA DCGM exporter | Partial |
| `salmeister` | Home website | Yes |
| `scanner` | scanservjs web UI for a network scanner | Yes |
| `scrapling` | Scrapling HTTP sidecar | Yes |
| `selfdiscipline` | Self-discipline app (API, UI, Postgres) | Yes |
| `signoz` | SigNoz, ClickHouse, and an OpenTelemetry collector | Yes |
| `swag` | SWAG reverse proxy, Cloudflare tunnel, and the Docker socket proxy | — |
| `transmission` | Transmission through OpenVPN | Yes |
| `vaultwarden` | Vaultwarden (Bitwarden-compatible) password vault | Yes |
| `vector` | Vector log shipper (syslog, auth, Docker socket) | No |
| `vikunju` | Vikunja task boards and Postgres | Yes |
| `watchtower` | Scheduled image updates | No |
| `wireguard` | WireGuard VPN server | No |

**Yes** means the user-facing service has `swag=enable`, a port, and a url, and the stack joins `shared-net`. The column is about that service; database containers stay off the proxy. **Partial:** Immich sets `swag_url` and has no `swag_port`; Omada has no `swag_url`; Plex sets only `swag=enable`; Grafana has full labels, and the `prometheus` stack stays off `shared-net`. `swag` is the proxy.

## Secrets

`.gitignore` is default-deny. A leading `*` ignores every path, then an allowlist re-includes compose files, `.env.example`, `Dockerfile`, `.dockerignore`, `README.md`, one-level `*.sh`, `.github/`, and `.pre-commit-config.yaml`.

Vaultwarden is the source of truth for secrets. Copy a stack's `.env.example` to `.env` and fill the placeholders from the vault. `.env` is not on the allowlist, so it stays untracked. These stacks have no `.env.example`: `mailrise`, `photosorter`, `portainer`, `transmission`, `vector`, `watchtower`. `transmission` and `watchtower` still read a local `.env`. Compose `secrets:` files (Plex claim token) and mounted configs (Vector, Mailrise, Immich `hwaccel.ml.yml`) stay on disk only.

[Gitleaks](https://github.com/gitleaks/gitleaks) v8.30.1 runs as a pre-commit hook (`.pre-commit-config.yaml`). CI (`.github/workflows/ci.yml`) runs gitleaks and `docker compose config` on every stack. Enable the hook with `pre-commit install`.

A new file outside the allowlist (anything nested deeper than the stack folder, or a new filename) stays ignored until it is force-added:

```bash
git add -f path/to/file
```

Force-add only files that belong in git. Leave `.env` and other secret files untracked.

## Networking

`shared-net` is a bridge network defined by the `swag` stack. Its subnet is `SUBNET` in `swag/.env` (an RFC1918 range, for example `172.16.0.0/24`). Every other stack that uses it marks the network `external: true`.

`wireguard`, `watchtower`, and `prometheus` sit off `shared-net`. Vikunja's database is only on `vikunja-internal`.

SWAG (`lscr.io/linuxserver/swag`) gets certificates with DNS-01 (Cloudflare plugin, wildcard, ZeroSSL). `DOCKER_MODS` loads `linuxserver/mods:swag-maxmind`, `swag-dashboard`, `swag-auto-proxy`, `universal-docker`, and `universal-cloudflared`. The tunnel config is `FILE__CF_TUNNEL_CONFIG=/config/tunnelconfig.yml` on the SWAG config volume (local only).

The Docker socket stays on `dockerproxy` (`lscr.io/linuxserver/socket-proxy`), mounted read-only, with the container API only (`CONTAINERS=1`, `POST=0`). SWAG talks to it with `DOCKER_HOST=tcp://dockerproxy:2375`.

SWAG labels address the upstream by container DNS on `shared-net`:

```yaml
labels:
  - swag=enable
  - swag_address=frigate   # container DNS name on shared-net
  - swag_port=8971
  - swag_proto=http        # https on Omada; also set on Frigate and Nextcloud
  - swag_url=frigate.*
```

Hard-coded container names in this repo include `frigate`, `code-server`, `obsidian-livesync`, and `openclaw-bf`. Stacks that use `swag_address=${SWAG_ADDRESS}` need `SWAG_ADDRESS` set to that container name. The `.env.example` placeholder is `swag` (the proxy itself); replace it with the upstream container name.

Bind admin and database ports to localhost:

```yaml
ports:
  - "127.0.0.1:5984:5984"
```

That pattern is used for CouchDB, Frigate's UI and internal API, code-server, the OpenClaw gateway, Baseball Forward Postgres, and the Mosquitto websocket. LAN-facing services publish on all interfaces (Plex, Omada discovery, WireGuard, MQTT `1883`, and others).

## Conventions

- `TZ` defaults to `America/Chicago`, `PUID` to `1000`, `PGID` to `1002` (`${TZ:-America/Chicago}`, `${PUID:-1000}`, `${PGID:-1002}`).
- `restart: unless-stopped`. Immich, Portainer, Transmission, Z-Wave JS UI, and ESPHome use `always`. The SigNoz schema migrator uses `on-failure`.
- Databases ship healthchecks (`pg_isready`, MariaDB `healthcheck.sh`, Redis `ping`, ClickHouse's HTTP ping, CouchDB `/_up`). Where a service waits on one, `depends_on` uses `condition: service_healthy`.
- Pin stateful image tags and bump database majors on purpose. Nextcloud is pinned at `nextcloud:35.0.1-apache` and moves one major at a time. Watchtower is disabled on the Nextcloud app, MariaDB, and Redis. MariaDB and Redis are unversioned tags with a comment to verify the current major before pulling.
- Other pinned stateful tags include Vaultwarden `1.37.4`, Vikunja `2.7.0`, Postgres `18.6`, ClickHouse `25.5.6`, Home Assistant `2026.10.1`, Frigate `0.18.0`, Portainer CE `2.45.2`, and SigNoz `v0.145.0`. Immich pins Valkey and its Postgres image by digest.
- The locally built image is Obsidian LiveSync: `obsidian/docker-compose.yml` sets `build: .` and `obsidian/Dockerfile` starts `FROM couchdb:3.3.3` and installs `curl` for the healthcheck.

## Updates

`watchtower` runs `nickfedor/watchtower` on cron `0 0 9 * * FRI` with `WATCHTOWER_NOTIFICATIONS=email`. It mounts the Docker socket and `~/.docker/config.json`. Opt a service out with `com.centurylinklabs.watchtower.enable=false` (Nextcloud's three services, ClickHouse, and the SigNoz schema migrator).

For a deliberate deploy, snapshot the ZFS dataset mounted at `/nas/docker`, then update one stack at a time:

```bash
zfs list -o name,mountpoint
sudo zfs snapshot <dataset>@pre-update-$(date +%Y%m%d)
cd /nas/docker
git pull
cd <stack>
docker compose pull && docker compose up -d
docker compose ps
```

`<dataset>` is the name from `zfs list` whose mountpoint is `/nas/docker`.

## Hardware

Frigate is the `frigate` service in `homeassistant/docker-compose.yml` (`ghcr.io/blakeblackshear/frigate:0.18.0`). It passes the Coral device through `/dev/apex_0:/dev/apex_0` (and `/dev/bus/usb`) and reserves the RTX 3060 (`deploy.resources.reservations.devices`, driver `nvidia`, `count: 1`, `capabilities: [gpu]`). The compose comment on that service says to set `privileged: true` if Coral or GPU detection fails.

The same GPU is reserved by Plex (`capabilities: [gpu, video]`), Ollama (`count: all`), and `nvidia/dcgm-exporter`. Immich machine learning uses the `-cuda` image tag and extends a local `hwaccel.ml.yml` (kept on disk only).

## Branches

Land changes on `develop-docker`. Promote `develop-docker` to `main`.
