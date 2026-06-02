# Vespera World — Ops Homebase

> One login. One dashboard. Agents, automations, tasks, deployments, and internal tools — all in one place.

This is the Docker Compose stack for the Vespera World operations homebase. Deploy it to a VPS via Dokploy, Coolify, or raw Docker Compose.

---

## Services

| Service | Port | Purpose |
|---------|------|---------|
| [n8n](https://n8n.io) | `5678` | Visual workflow automation — the glue between services |
| [Budibase](https://budibase.com) | `10000` | Low-code internal tool builder — dashboards, admin panels, forms |
| [code-server](https://github.com/coder/code-server) | `8080` | Browser-based VS Code — shared team IDE |
| [Appwrite](https://appwrite.io) | `80` / `443` | Self-hosted backend-as-a-service (auth, DB, storage, functions) |
| Plane (optional) | `3001` | Open-source project management (separate compose file) |

## Quick Start

### 1. Clone & configure

```bash
git clone https://github.com/vespera-world/ops-homebase.git
cd ops-homebase
cp .env.example .env
# Edit .env with your secrets
git update-index --assume-unchanged .env
```

### 2. Deploy

**Dokploy:**
1. Create a new project in Dokploy
2. Point it at this GitHub repo
3. Dokploy reads `docker-compose.yml` and deploys each service
4. Assign domains in Dokploy for each service (e.g. `n8n.yourdomain.com`)

**Raw Docker Compose:**
```bash
docker compose up -d
```

### 3. Plane (optional)

```bash
docker compose -f docker-compose.plane.yml up -d
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        YOUR VPS (Dokploy)                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   n8n      │  │ Budibase   │  │   code-server      │  │
│  │ (workflows)│  │(dashboards)│  │  (browser IDE)    │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐                      │
│  │  Appwrite   │  │  Hermes     │  (deployed separately   │
│  │  (internal) │  │  (gateway)  │   or in same stack)     │
│  └─────────────┘  └─────────────┘                      │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Supabase Cloud (DB + Auth + Edge Functions)        │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Repo Structure

```
ops-homebase/
├── docker-compose.yml          # Main stack
├── docker-compose.plane.yml    # Optional Plane project mgmt
├── .env.example                # Secrets template
├── dashboard/
│   └── index.html                # Team home dashboard
├── scripts/
│   └── setup-vps.sh              # VPS hardening + prep
└── docs/
    └── hermes-n8n-integration.md # Webhook contract
```

---

## Security

- `.env` contains secrets. It is gitignored. Never commit it.
- Use Dokploy's built-in SSL/Traefik for HTTPS termination.
- Each service runs in an isolated Docker network.
- Services communicate via internal Docker DNS (e.g. `n8n:5678`).

---

## Next Steps

1. Deploy this stack to your VPS
2. Configure domains in Dokploy
3. Log into n8n, Budibase, and code-server
4. Deploy Hermes gateway (see `docs/hermes-n8n-integration.md`)
5. Open `dashboard/index.html` in a browser as your team homepage
