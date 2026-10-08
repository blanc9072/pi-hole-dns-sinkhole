# Pi-hole Privacy Analyzer

> **Status: in progress.** Infrastructure complete; data collection and analysis next.

How many companies does my laptop contact in one day of normal internet use, and how many of them are trackers or registered data brokers?

This project runs a **Pi-hole DNS filter on a cloud server, reachable only through a WireGuard VPN**, logs one day of my Mac's DNS lookups, and maps each domain to the company behind it.

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

_TBD after the measurement day._

## What DNS data can and can't show

- It shows **which domains my Mac looked up**, not what data was sent; traffic itself is encrypted.
- Counts are **DNS lookups**, not individual requests (devices cache answers).
- Data brokers mostly obtain data indirectly, so this measures direct contact with trackers and flags companies that are registered brokers.
- Covers one Mac only.

## Repo layout

| Path | Contents |
|---|---|
| `docs/setup.md` | Step-by-step build |
| `docs/security.md` | Threat model and firewall design |
| `docs/troubleshooting.md` | Problems hit and how they were diagnosed |
| `server/` | Firewall and setup scripts, example WireGuard configs |
| `tests/check_exposure.sh` | Verifies Pi-hole is reachable via VPN only |
| `analyzer/` | Analysis code (in progress) |

## Privacy

The raw Pi-hole database is effectively browsing history and is **not** in this repo. Only aggregated results are published.

## Credits

- [Pi-hole](https://pi-hole.net/) and its documentation
- [WireGuard](https://www.wireguard.com/)
