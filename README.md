# Pi-hole Privacy Analyzer layer on top of DNS Sinkhole

**Status: in progress.** 

This project runs a Pi-hole DNS filter on a cloud server, reachable only through a WireGuard VPN

## Architecture

```
Mac (WireGuard client, 10.100.0.2)
   |  encrypted tunnel, UDP 47111   (only DNS goes through it; split tunnel)
   v
Cloud server (Ubuntu 24.04, ufw: deny by default)
   ├── WireGuard  wg0  10.100.0.1
   └── Pi-hole    DNS + dashboard, reachable ONLY on wg0
          |
          v
     upstream DNS
```

## What's done

- [x] Hardened cloud server: deny-by-default firewall, only SSH + WireGuard public
- [x] WireGuard VPN (hand-configured, split tunnel)
- [x] Pi-hole reachable only through the VPN, verified not to be an open resolver
- [ ] One-day measurement (blocking disabled, all lookups logged)
- [ ] Map domains to companies (DuckDuckGo Tracker Radar)
- [ ] Flag registered data brokers (California data broker registry)
- [ ] SQL analysis + dashboard

## Results

*TBD*

## Repo layout

| Path | Contents |
|---|---|
| `docs/setup.md` | Step-by-step build |
| `docs/security.md` | Threat model and firewall design |
| `docs/troubleshooting.md` | Problems hit and how they were diagnosed |
| `server/` | Firewall and setup scripts, example WireGuard configs |
| `tests/check_exposure.sh` | Verifies Pi-hole is reachable via VPN only |
| `analyzer/` | Analysis code (in progress) |

## Resources

- [Pi-hole](https://pi-hole.net/)
- [WireGuard](https://www.wireguard.com/)
