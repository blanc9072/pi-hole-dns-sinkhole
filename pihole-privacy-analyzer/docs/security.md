# Security design

## Threat: the open resolver

A DNS server that answers anyone on the internet is an **open resolver**. Attackers send it small queries with a forged sender address, and it replies with larger answers to the victim, multiplying their attack traffic (DNS amplification). Open resolvers are found by automated scanners quickly. Pi-hole's maintainers strongly discourage running Pi-hole this way and recommend reaching a cloud Pi-hole only through an authenticated VPN.

## Design

| Port | Service | Who can reach it |
|---|---|---|
| 22/tcp | SSH | Internet |
| 47111/udp | WireGuard | Internet |
| 53/tcp+udp | Pi-hole DNS | VPN (`wg0`) only |
| 80/tcp | Pi-hole dashboard | VPN (`wg0`) only |
| everything else | n/a | Nobody (default deny) |

- **Deny by default.** `ufw default deny incoming`; each open port is an explicit decision.
- **DNS and dashboard bound to the tunnel.** `ufw allow in on wg0 ...` means a packet must arrive through WireGuard, which requires a valid key, to reach Pi-hole.
- **Opening the WireGuard port to everyone is acceptable** because WireGuard is designed to ignore packets that aren't from a known peer. <!-- TODO: link the wireguard.com page that confirms this -->
- **Keys.** Private keys are created with `umask 077` (root-only). No private key is in this repository; configs are `.example` files with placeholders, enforced by `.gitignore`.
- **Dashboard over HTTP.** The dashboard uses plain HTTP, but it's only reachable inside the WireGuard tunnel, which encrypts the traffic.
- **Server's own DNS doesn't depend on Pi-hole**, so a Pi-hole failure can't stop the server from updating or repairing itself.

## Verification

[`tests/check_exposure.sh`](../tests/check_exposure.sh) checks, from the client, that DNS answers through the VPN and that both DNS and the dashboard are unreachable on the public IP.

## Known gaps / next steps

- **SSH is open to the whole internet.** Options: allow SSH only from the VPN, restrict it to known IPs, confirm password login is disabled (key-only), add `fail2ban`.
- **Single firewall layer.** No DigitalOcean Cloud Firewall is attached. Adding one with the same two public rules would give defense in depth.
- **Pi-hole listening mode.** Pi-hole's WireGuard guide recommends "Allow only local requests" as an extra layer. <!-- TODO: confirm the setting -->
- **Query logs are sensitive.** The Pi-hole database is effectively browsing history; only aggregated results are published here.
