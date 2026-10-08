#!/usr/bin/env bash
# Ubuntu's systemd-resolved runs a DNS "stub listener" on 127.0.0.53:53, which stops
# Pi-hole from using port 53. This script turns the stub listener off and points the
# server's own DNS at the upstream servers it receives from the provider, so the server
# can still resolve names (and install updates) even if Pi-hole is down.
#
# Run as root BEFORE installing Pi-hole:  sudo bash free-port-53.sh
# Undo: delete /etc/systemd/resolved.conf.d/no-stub.conf, then
#       ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf && systemctl restart systemd-resolved

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo bash $0)" >&2
  exit 1
fi

# 1. Drop-in config: disable the stub listener (easier to undo than editing the main file)
mkdir -p /etc/systemd/resolved.conf.d
printf "[Resolve]\nDNSStubListener=no\n" > /etc/systemd/resolved.conf.d/no-stub.conf

# 2. Point /etc/resolv.conf at the real upstream servers instead of the stub
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

systemctl restart systemd-resolved

# 3. Verify
echo "--- Anything still listening on port 53? (expect nothing) ---"
ss -tulpn | grep ':53 ' || echo "Port 53 is free."

echo "--- Can the server still resolve names? ---"
ping -c 2 google.com
