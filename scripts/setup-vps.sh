#!/usr/bin/env bash
# ============================================================
# Vespera World — VPS Setup Script
# Hardens a fresh VPS for running Docker-based services.
# Run as root or with sudo on a fresh Ubuntu/Debian VPS.
# ============================================================

set -euo pipefail

# Config
SSH_PORT=${SSH_PORT:-22}
SWAP_SIZE=${SWAP_SIZE:-2G}
DOCKER_USER=${DOCKER_USER:-vespera}

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ────────────────────────────────────────────
# 1. System updates
# ────────────────────────────────────────────
log "Updating system packages..."
apt-get update && apt-get upgrade -y
apt-get install -y curl wget htop ufw fail2ban unattended-upgrades apt-listchanges

# ────────────────────────────────────────────
# 2. Create non-root user with Docker access
# ────────────────────────────────────────────
if ! id "$DOCKER_USER" &>/dev/null; then
    log "Creating user: $DOCKER_USER"
    useradd -m -s /bin/bash "$DOCKER_USER"
    usermod -aG sudo "$DOCKER_USER"
    echo "$DOCKER_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-$DOCKER_USER
fi

# ────────────────────────────────────────────
# 3. Firewall (UFW)
# ────────────────────────────────────────────
log "Configuring UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSH_PORT/tcp"
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# ────────────────────────────────────────────
# 4. fail2ban
# ────────────────────────────────────────────
log "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
EOF
systemctl restart fail2ban

# ────────────────────────────────────────────
# 5. Swap
# ────────────────────────────────────────────
if ! swapon --show | grep -q "swap"; then
    log "Creating ${SWAP_SIZE} swap file..."
    fallocate -l "$SWAP_SIZE" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi

# ────────────────────────────────────────────
# 6. Docker tweaks
# ────────────────────────────────────────────
log "Applying Docker optimizations..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true
}
EOF
systemctl restart docker || true

# ────────────────────────────────────────────
# 7. Auto-updates
# ────────────────────────────────────────────
log "Enabling unattended security updates..."
dpkg-reconfigure -plow unattended-upgrades -f noninteractive || true

# ────────────────────────────────────────────
# Done
# ────────────────────────────────────────────
log "VPS hardening complete."
log "Next steps:"
log "  1. Install Dokploy (or Coolify) on this VPS"
log "  2. Add your SSH key to user: $DOCKER_USER"
log "  3. Log in as $DOCKER_USER and deploy the ops-homebase stack"
