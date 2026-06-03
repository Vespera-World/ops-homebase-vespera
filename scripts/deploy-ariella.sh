#!/usr/bin/env bash
# ============================================================
# deploy-ariella.sh
# One-command deploy for Ariella on the Vespera World VPS.
# Run this on the VPS as the docker user (vespera).
# ============================================================

set -euo pipefail

REPO_URL="https://github.com/Vespera-World/ops-homebase-vespera.git"
DEPLOY_DIR="$HOME/ops-homebase-vespera"
COMPOSE_FILE="$DEPLOY_DIR/docker-compose.yml"
ENV_FILE="$DEPLOY_DIR/.env"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ────────────────────────────────────────────
# 1. Ensure repo is cloned
# ────────────────────────────────────────────
if [ ! -d "$DEPLOY_DIR/.git" ]; then
    log "Cloning repo..."
    git clone "$REPO_URL" "$DEPLOY_DIR"
else
    log "Pulling latest changes..."
    cd "$DEPLOY_DIR"
    git pull origin main
fi

cd "$DEPLOY_DIR"

# ────────────────────────────────────────────
# 2. Ensure .env exists
# ────────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
    log "ERROR: .env file not found at $ENV_FILE"
    log "Copy .env.example and fill in your secrets first:"
    log "  cp .env.example .env"
    log "  nano .env"
    exit 1
fi

# ────────────────────────────────────────────
# 3. Validate required env vars for Ariella
# ────────────────────────────────────────────
log "Checking Ariella environment variables..."

required_vars=(
    "ARI_TELEGRAM_BOT_TOKEN"
    "ARI_WEBHOOK_URL"
    "SUPABASE_URL"
    "SUPABASE_ANON_KEY"
    "OPENROUTER_API_KEY"
)

missing=0
for var in "${required_vars[@]}"; do
    if ! grep -q "^${var}=" "$ENV_FILE" || grep -q "^${var}=SET_" "$ENV_FILE" || grep -q "^${var}=$" "$ENV_FILE"; then
        log "  ❌ MISSING or placeholder: $var"
        missing=1
    else
        log "  ✅ OK: $var"
    fi
done

if [ $missing -eq 1 ]; then
    log ""
    log "Please fill in the missing values in $ENV_FILE"
    log "Then re-run this script."
    exit 1
fi

# ────────────────────────────────────────────
# 4. Build and deploy Ariella
# ────────────────────────────────────────────
log "Building Ariella Docker image..."
docker compose build ariella

log "Starting Ariella service..."
docker compose up -d ariella

# ────────────────────────────────────────────
# 5. Health check
# ────────────────────────────────────────────
log "Waiting for Ariella to start..."
sleep 5

for i in {1..10}; do
    if curl -sf http://localhost:3000/health >/dev/null 2>&1; then
        log "✅ Ariella is healthy on port 3000"
        break
    fi
    if [ $i -eq 10 ]; then
        log "⚠️  Health check failed after 10 attempts"
        log "Check logs: docker compose logs ariella"
        exit 1
    fi
    sleep 2
done

# ────────────────────────────────────────────
# 6. Set Telegram webhook
# ────────────────────────────────────────────
log "Setting Telegram webhook..."
WEBHOOK_URL=$(grep "^ARI_WEBHOOK_URL=" "$ENV_FILE" | cut -d'=' -f2-)
BOT_TOKEN=$(grep "^ARI_TELEGRAM_BOT_TOKEN=" "$ENV_FILE" | cut -d'=' -f2-)

if [ -n "$WEBHOOK_URL" ] && [ -n "$BOT_TOKEN" ]; then
    curl -sf "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook?url=${WEBHOOK_URL}/webhook" >/dev/null 2>&1
    log "✅ Telegram webhook set to ${WEBHOOK_URL}/webhook"
else
    log "⚠️  Could not set webhook — check ARI_WEBHOOK_URL and ARI_TELEGRAM_BOT_TOKEN"
fi

# ────────────────────────────────────────────
# 7. Summary
# ────────────────────────────────────────────
log ""
log "=== DEPLOY COMPLETE ==="
log ""
log "Ariella is running at:"
log "  Health:  http://localhost:3000/health"
log "  Webhook: ${WEBHOOK_URL}/webhook"
log ""
log "Logs:     docker compose logs -f ariella"
log "Restart:  docker compose restart ariella"
log "Stop:     docker compose stop ariella"
log ""
