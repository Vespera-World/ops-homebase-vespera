#!/usr/bin/env bash
# ============================================================
# setup-hermes-vps.sh
# Run this on your VPS to install Hermes and import migrated config.
# Assumes: Docker + Docker Compose are installed (or use Dokploy raw exec).
# ============================================================

set -euo pipefail

HERMES_HOME="$HOME/.hermes"
MIGRATION="/tmp/hermes-vps-migration.tar.gz"

echo "=== Hermes VPS Setup ==="

# 1. Ensure Hermes CLI is available
echo "[1/6] Checking Hermes CLI..."
if ! command -v hermes &>/dev/null; then
    echo "Hermes CLI not found. Install with:"
    echo "  python3 -m venv ~/.hermes/hermes-agent/venv"
    echo "  ~/.hermes/hermes-agent/venv/bin/pip install hermes-agent"
    echo "  ln -s ~/.hermes/hermes-agent/venv/bin/hermes ~/.local/bin/hermes"
    echo ""
    echo "Or: pip install --user hermes-agent"
    exit 1
fi

# 2. Create HERMES_HOME
echo "[2/6] Setting up Hermes home: $HERMES_HOME"
mkdir -p "$HERMES_HOME"

# 3. Extract migration package
if [ -f "$MIGRATION" ]; then
    echo "[3/6] Importing migrated config..."
    tar xzf "$MIGRATION" -C "$HERMES_HOME" --strip-components=1
    
    if [ -f "$HERMES_HOME/env.bak" ]; then
        mv "$HERMES_HOME/env.bak" "$HERMES_HOME/.env"
        echo "Restored .env from WSL"
    fi
    
    # Update API_SERVER_HOST to 0.0.0.0 if it was localhost
    if grep -q "API_SERVER_HOST=127.0.0.1" "$HERMES_HOME/.env" 2>/dev/null; then
        sed -i 's/API_SERVER_HOST=127.0.0.1/API_SERVER_HOST=0.0.0.0/' "$HERMES_HOME/.env"
        echo "Updated API_SERVER_HOST to 0.0.0.0 for VPS"
    fi
else
    echo "[3/6] No migration package found at $MIGRATION"
    echo "      Starting fresh config. You'll need to set .env manually."
fi

# 4. Fix permissions
echo "[4/6] Setting permissions..."
chmod 600 "$HERMES_HOME/.env" 2>/dev/null || true

# 5. Install systemd service
echo "[5/6] Installing Hermes gateway service..."
hermes gateway install 2>/dev/null || true

# 6. Summary
echo ""
echo "=== Hermes VPS Setup Complete ==="
echo ""
echo "IMMEDIATE NEXT STEPS:"
echo ""
echo "1. Review .env:  nano ~/.hermes/.env"
echo "   - Update API_SERVER_HOST to your VPS public IP or 0.0.0.0"
echo "   - Update CLOUDFLARE_TUNNEL_URL if using one"
echo "   - Update Supabase secrets if the tunnel URL changed"
echo ""
echo "2. WhatsApp MUST be re-paired on this new IP:"
echo "   hermes whatsapp"
echo "   Scan the QR code with your bot phone."
echo ""
echo "3. Telegram:"
echo "   - If using polling (default), just restart: hermes gateway restart"
echo "   - If using webhooks, run: hermes pairing approve telegram <CODE>"
echo ""
echo "4. Test API server:"
echo "   curl http://YOUR_VPS_IP:8642/v1/models"
echo ""
echo "5. Restart gateway:"
echo "   hermes gateway restart"
echo ""
