# 📊 Observability Stack

> Self-hosted observability (Grafana + Loki + Prometheus) with plug-and-play tunnel support. Run standalone on any machine or drop in as a git submodule. Connect multiple apps via Cloudflare Tunnel, Tailscale, or WireGuard.

---

## What is this?

A zero-config observability stack you can spin up anywhere and connect any application to in minutes — without paying for Grafana Cloud.

It's designed to work in two ways:

- **Standalone** — run it on your PC or a server, connect multiple apps remotely via tunnel
- **Submodule** — drop it into an app repo, spin everything up together with `make up`

Your app brings its own [Grafana Alloy](https://grafana.com/docs/alloy/) agent. This stack just receives, stores, and visualizes the data.

---

## Stack

| Service                               | Version | Role                       |
| ------------------------------------- | ------- | -------------------------- |
| [Grafana](https://grafana.com/)       | 10.2.4  | Dashboards & visualization |
| [Prometheus](https://prometheus.io/)  | v2.48.0 | Metrics storage & querying |
| [Loki](https://grafana.com/oss/loki/) | 2.9.10  | Log aggregation            |

**Tunnel options:** Cloudflare Tunnel · Tailscale · WireGuard · None (local)

---

## Quick Start

```bash
git clone https://github.com/Giygas/observability-stack.git
cd observability-stack
make setup
make up
```

Open Grafana at [http://localhost:3000](http://localhost:3000).

---

## Operation Modes

### Mode 1 — Standalone (Remote)

Run the stack on a dedicated machine. Multiple apps connect to it remotely via tunnel.

```
Linux Server A                      Your PC / VPS
──────────────────                  ──────────────────────────
my-app                              observability-stack/
grafana-alloy ──→ tunnel ──────────→   loki
                                       prometheus
Linux Server B                         grafana
──────────────────                     cloudflared (or tailscale)
another-app
grafana-alloy ──→ tunnel ──────────→  (same stack)
```

Each app pushes metrics and logs tagged with its own `job` label — Grafana shows them all, cleanly separated.

### Mode 2 — Submodule (Local Dev / Staging)

Add this repo as a submodule inside your app repo. One `make up` starts everything on a shared Docker network.

```
Your laptop
───────────────────────────────────────
my-app/
├── docker-compose.yml   (app + alloy)
└── observability/       (this repo, as submodule)
    └── docker-compose.yml  (loki + prometheus + grafana)

All containers share obs-network — Alloy reaches Loki and
Prometheus directly by container name, no tunnel needed.
```

---

## Connecting Your App

Your app needs a [Grafana Alloy](https://grafana.com/docs/alloy/) agent that pushes metrics and logs to this stack. Alloy lives in **your app repo**, not here.

### Local mode (submodule)

Alloy talks to Loki and Prometheus by container name over the shared Docker network:

```alloy
prometheus.remote_write "obs" {
  endpoint {
    url = "http://prometheus:9090/api/v1/write"
  }
}

loki.write "obs" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}
```

### Remote mode (tunnel)

Alloy pushes to your tunnel endpoints, with optional Cloudflare Access auth and WAL buffering for outage protection:

```alloy
prometheus.remote_write "obs" {
  endpoint {
    url = env("PROMETHEUS_URL")

    headers = {
      "CF-Access-Client-Id"     = env("CF_ACCESS_CLIENT_ID"),
      "CF-Access-Client-Secret" = env("CF_ACCESS_CLIENT_SECRET"),
    }

    queue_config {
      capacity             = 10000
      max_samples_per_send = 2000
      max_backoff          = "5s"
    }
  }
}

loki.write "obs" {
  endpoint {
    url = env("LOKI_URL")

    headers = {
      "CF-Access-Client-Id"     = env("CF_ACCESS_CLIENT_ID"),
      "CF-Access-Client-Secret" = env("CF_ACCESS_CLIENT_SECRET"),
    }
  }
}
```

> **WAL buffering:** with `--storage.path` enabled in Alloy, metrics and logs are buffered to disk during outages and replayed automatically when the stack comes back online, protection duration depends on data volume and WAL size (2.5GB default).

### Using as a submodule in your app repo

```bash
# Add this repo as a submodule
git submodule add https://github.com/Giygas/observability-stack.git observability

# Or if already defined in .gitmodules
git submodule update --init --recursive
```

Then in your app's `docker-compose.yml`, join the shared network:

```yaml
networks:
  obs-network:
    external: true
    name: obs-network
```

And in your app's Makefile, delegate to this repo:

```makefile
obs-up:
	$(MAKE) -C observability up

up: obs-up
	docker compose up -d
```

---

## System Metrics

System metrics scraping belongs at the app level, not the observability stack level. Monitoring the obs stack's own host has little value — what matters is the machine running your application.

The setup depends on the OS where your app runs:

### Linux (native binary deployment)

Install `node-exporter` on the machine running your app:

```bash
# Install node-exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvf node_exporter-1.7.0.linux-amd64.tar.gz
sudo mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
sudo systemctl enable --now node_exporter
```

Then in your app's Alloy config, scrape `localhost:9100` and forward to the obs stack.

In your app's Alloy config (`config.remote.alloy`), add a `prometheus.scrape` block targeting `localhost:9100` and pointing `forward_to` at your existing `prometheus.remote_write.obs.receiver` — same pattern as the app metrics scrape, just a different address:

```alloy
prometheus.scrape "node_exporter" {
  targets = [{
    __address__ = "localhost:9100",
    job         = "node-exporter",
  }]
  forward_to = [prometheus.remote_write.obs.receiver]
}
```

### Windows

Download and install [windows-exporter](https://github.com/prometheus-community/windows_exporter/releases) as a Windows service. It exposes metrics on `localhost:9182`.

Then scrape it in your app's Alloy config and forward to the obs stack:

```alloy
prometheus.scrape "windows_exporter" {
  targets = [{
    __address__ = "localhost:9182"
    job         = "node-exporter",
  }]
  forward_to = [prometheus.remote_write.obs.receiver]
}
```

### Grafana Dashboards

Import these dashboards in Grafana to visualize your system metrics:

- **Linux:** [Node Exporter Full](https://grafana.com/grafana/dashboards/1860) (ID: 1860)
- **Windows:** [Windows Exporter](https://grafana.com/grafana/dashboards/10467) (ID: 10467)

---

## Tunnels

No tunnel is required for local use. For remote access, pick one:

### Cloudflare Tunnel (recommended if you use Cloudflare)

Best if you already have a Cloudflare account and domain. No open ports, HTTPS out of the box, optional Access policies for auth.

```bash
make up-cloudflare
```

Set up in [Cloudflare Zero Trust](https://one.dash.cloudflare.com) → Tunnels → Create tunnel. Add these public hostnames pointing to the container names:

| Hostname                        | Service                  |
| ------------------------------- | ------------------------ |
| `prometheus-obs.yourdomain.com` | `http://prometheus:9090` |
| `loki-obs.yourdomain.com`       | `http://loki:3100`       |
| `grafana-obs.yourdomain.com`    | `http://grafana:3000`    |

Then in your app's `.env`:

```env
PROMETHEUS_URL=https://prometheus-obs.yourdomain.com/api/v1/write
LOKI_URL=https://loki-obs.yourdomain.com/loki/api/v1/push
```

See [Tunnel Setup Guide](docs/tunnels.md#cloudflare-tunnel) for Cloudflare Access configuration.

### Tailscale

Best if you don't have a domain or want a pure peer-to-peer VPN.

```bash
make up-tailscale
```

After setup, use your machine's Tailscale IP in your app's `.env`:

```env
PROMETHEUS_URL=http://100.x.x.x:9090/api/v1/write
LOKI_URL=http://100.x.x.x:3100/loki/api/v1/push
```

See [Tunnel Setup Guide](docs/tunnels.md#tailscale).

### WireGuard

Best for self-hosters who want full control with no third-party services.

```bash
make up-wireguard
```

See [Tunnel Setup Guide](docs/tunnels.md#wireguard).

---

## Configuration

```bash
cp .env.example .env
```

| Variable                  | Default     | Description                          |
| ------------------------- | ----------- | ------------------------------------ |
| `GRAFANA_ADMIN_USER`      | `admin`     | Grafana admin username               |
| `GRAFANA_PORT`            | `3000`      | Grafana host port                    |
| `PROMETHEUS_PORT`         | `9090`      | Prometheus host port                 |
| `PROMETHEUS_RETENTION`    | `720h`      | Metrics retention (30 days)          |
| `LOKI_PORT`               | `3100`      | Loki host port                       |
| `CLOUDFLARE_TUNNEL_TOKEN` | —           | Cloudflare tunnel token              |
| `CF_ACCESS_CLIENT_ID`     | —           | Cloudflare Access client ID          |
| `CF_ACCESS_CLIENT_SECRET` | —           | Cloudflare Access client secret      |
| `TAILSCALE_AUTHKEY`       | —           | Tailscale auth key                   |
| `TS_HOSTNAME`             | `obs-stack` | Tailscale machine hostname           |
| `WG_SERVER_URL`           | —           | WireGuard server public IP or domain |
| `WG_PORT`                 | `51820`     | WireGuard UDP port                   |

Grafana password is stored in `secrets/grafana_password.txt` (created by `make setup`).

---

## Make Commands

```
make setup           Initialize secrets and .env file
make up              Start stack (no tunnel)
make up-cloudflare   Start stack with Cloudflare Tunnel
make up-tailscale    Start stack with Tailscale
make up-wireguard    Start stack with WireGuard
make down            Stop stack
make restart         Restart stack
make logs            Tail logs (SERVICE=name to filter)
make status          Show container status
make clean           Remove all containers, volumes, and images
```

---

## Data & Storage

All data is persisted in named Docker volumes and survives container restarts:

| Volume            | Contents              | Default Retention      |
| ----------------- | --------------------- | ---------------------- |
| `prometheus-data` | Metrics time-series   | 30 days (configurable) |
| `loki-data`       | Log chunks            | 30 days (configurable) |
| `grafana-data`    | Dashboards & settings | Permanent              |

---

## Security Notes

- Grafana password is file-based (`secrets/`) and never stored in `.env`
- Services are not exposed publicly by default — tunnel provides controlled access
- Cloudflare Access adds token-based authentication on top of the tunnel
- All inter-service communication stays inside the Docker `obs-network` bridge

---

## Documentation

- [Tunnel Setup Guide](docs/tunnels.md)
- [Remote Mode Setup](docs/remote-setup.md)
- [Local Submodule Setup](docs/local-setup.md)

---

## Contributing

Contributions welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

---

## License

MIT
