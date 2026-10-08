#!/usr/bin/env bash
# Configures ufw so that only SSH and WireGuard are reachable from the internet,
# and Pi-hole's DNS (53) and dashboard (80) are reachable ONLY through the VPN (wg0).
#
# Run as root on the server:  sudo bash firewall.sh
# SSH is allowed BEFORE the firewall is enabled, so the current session is not locked out.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo bash $0)" >&2
  exit 1
fi

# Deny everything incoming by default; allow the server to reach out (updates, upstream DNS)
ufw default deny incoming
ufw default allow outgoing

# Public: SSH and WireGuard only
ufw allow 22/tcp
ufw allow 47111/udp

# VPN-only: Pi-hole DNS (TCP+UDP) and web dashboard
ufw allow in on wg0 to any port 53
ufw allow in on wg0 to any port 80 proto tcp

# --force skips the "may disrupt existing ssh connections" prompt
ufw --force enable
ufw status verbose
