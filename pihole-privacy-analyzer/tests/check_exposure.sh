#!/usr/bin/env bash
# Verifies the security design from the client (Mac), with the WireGuard tunnel ON:
#   1. Pi-hole answers DNS through the VPN           -> expected: reachable
#   2. Pi-hole does NOT answer DNS on the public IP  -> expected: blocked (not an open resolver)
#   3. The dashboard is NOT reachable on the public IP -> expected: blocked
#
# Because the tunnel is a split tunnel (AllowedIPs = 10.100.0.1/32), queries to the
# public IP go over the normal internet, so tests 2 and 3 see what a stranger would see.
#
# Usage: ./check_exposure.sh <SERVER_PUBLIC_IP> [VPN_DNS_IP]

set -uo pipefail

PUBLIC_IP="${1:?Usage: $0 <SERVER_PUBLIC_IP> [VPN_DNS_IP]}"
VPN_IP="${2:-10.100.0.1}"
FAILURES=0

pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; FAILURES=$((FAILURES + 1)); }

# dig exits 0 when it gets any reply, and non-zero when no server answers
if dig @"$VPN_IP" example.com +time=3 +tries=1 >/dev/null 2>&1; then
  pass "Pi-hole answers DNS through the VPN ($VPN_IP)"
else
  fail "Pi-hole did NOT answer through the VPN ($VPN_IP). Is the tunnel on?"
fi

if dig @"$PUBLIC_IP" example.com +time=3 +tries=1 >/dev/null 2>&1; then
  fail "DNS answered on the PUBLIC IP ($PUBLIC_IP). This is an open resolver!"
else
  pass "DNS is not reachable on the public IP ($PUBLIC_IP)"
fi

if curl -s --max-time 3 -o /dev/null "http://$PUBLIC_IP/admin/"; then
  fail "Dashboard is reachable on the PUBLIC IP ($PUBLIC_IP)"
else
  pass "Dashboard is not reachable on the public IP ($PUBLIC_IP)"
fi

echo
if [[ $FAILURES -eq 0 ]]; then
  echo "All checks passed."
else
  echo "$FAILURES check(s) failed."
fi
exit "$FAILURES"
