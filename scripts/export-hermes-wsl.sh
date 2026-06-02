#!/usr/bin/env bash
# ============================================================
# export-hermes-wsl.sh
# Run this on your WSL machine to package Hermes for VPS migration.
# Produces: /tmp/hermes-vps-migration.tar.gz
# ============================================================

set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
OUT="/tmp/hermes-vps-migration.tar.gz"

echo "=== Packaging Hermes from WSL ==="
echo "Source: $HERMES_HOME"
echo "Output: $OUT"

# Create temp staging dir
STAGE=$(mktemp -d)
trap "rm -rf $STAGE" EXIT

# Copy essential files
mkdir -p "$STAGE/hermes"

cp "$HERMES_HOME/.env" "$STAGE/hermes/env.bak" 2>/dev/null || echo "Warning: no .env found"
cp "$HERMES_HOME/config.yaml" "$STAGE/hermes/" 2>/dev/null || echo "Warning: no config.yaml found"

if [ -d "$HERMES_HOME/skills" ]; then
    cp -r "$HERMES_HOME/skills" "$STAGE/hermes/"
fi

if [ -d "$HERMES_HOME/cron" ]; then
    cp -r "$HERMES_HOME/cron" "$STAGE/hermes/"
fi

if [ -d "$HERMES_HOME/whatsapp/session" ]; then
    echo "Note: WhatsApp session will be copied, but you MUST re-pair on the VPS."
    cp -r "$HERMES_HOME/whatsapp/session" "$STAGE/hermes/whatsapp-session/"
fi

if [ -d "$HERMES_HOME/agents" ]; then
    cp -r "$HERMES_HOME/agents" "$STAGE/hermes/"
fi

# Write metadata
cat > "$STAGE/hermes/MIGRATION-meta.txt" <<EOF
Hermes Migration Package
Exported from: $(hostname)
Date: $(date -Iseconds)
User: $(whoami)

NEXT STEPS:
1. Copy this tar.gz to your VPS: scp /tmp/hermes-vps-migration.tar.gz user@vps:/tmp/
2. On VPS, run: ./setup-hermes-vps.sh
3. Re-pair WhatsApp: hermes whatsapp
4. Update Telegram webhook (if using webhooks) to point at new VPS IP/domain
5. Test Telegram and API server
EOF

# Pack it
tar czf "$OUT" -C "$STAGE" .

echo ""
echo "=== DONE ==="
echo "Migration package: $OUT"
echo ""
echo "Copy to VPS with:"
echo "  scp $OUT root@YOUR_VPS_IP:/tmp/"
echo ""
