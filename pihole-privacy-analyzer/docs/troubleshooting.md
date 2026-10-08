# Troubleshooting log

Problems hit during the build, how each was narrowed down, and the fix.

## 1. WireGuard failed to start after adding the Mac as a peer

**Symptom.** `systemctl restart wg-quick@wg0` failed:

```
Job for wg-quick@wg0.service failed because the control process exited with error code.
```

**Diagnosis.** The service log pointed at the cause:

```bash
journalctl -xeu wg-quick@wg0.service --no-pager | tail -30
```
```
Key is not the correct length or format: `MAC_PUBLIC_KEY'
Configuration parsing error
```

Printing the config without the private key showed two `[Peer]` blocks: the command had been run once with the literal placeholder `MAC_PUBLIC_KEY`, then again with the real key.

```bash
grep -v PrivateKey /etc/wireguard/wg0.conf   # -v: show lines that do NOT match
```

**Fix.** Rewrote the whole file with `>` (replace) instead of appending with `>>`, keeping one correct peer.

**Lesson.** Most of the log was boilerplate; one line named the exact problem. `>>` appends, so re-running an append command duplicates content.

## 2. No WireGuard handshake: packets never reached the server

**Symptom.** From the Mac, `ping 10.100.0.1` timed out. On the server, `wg show` listed the peer but no `latest handshake`.

**Narrowing it down, one layer at a time:**

| Check | Result | Meaning |
|---|---|---|
| `route -n get 10.100.0.1` (Mac) | interface `utun9`, MTU 1420 | Mac routes VPN traffic into the tunnel correctly |
| Mac config vs server `wg show` | Keys, IP and port all match | Not a config typo |
| `tcpdump -ni eth0 udp port 47111` (server) while toggling the tunnel | **0 packets** | WireGuard's packets never reach the server |
| `echo test \| nc -u -w 2 <SERVER_IP> 47111` (Mac) | **1 packet captured** | Server, firewall and port are fine |

So a hand-sent UDP packet arrived but WireGuard's didn't, which pointed at something on the Mac. A commercial VPN app (Cloudflare 1.1.1.1) was running at the same time.

**Fix.** Turned the other VPN off and toggled the tunnel: packets arrived and the handshake completed.

**Not confirmed:** the exact mechanism of the conflict between the two VPN apps on macOS. The fix was verified by testing, not by reading their internals. The manual `nc` packet may also have travelled through the other VPN, so this test did not prove whether the school network blocks UDP 47111 on its own.

**Lesson.** `tcpdump` sees packets *before* the firewall, so "zero packets" means the problem is upstream of the server, not in its firewall. Splitting the path in half (manual packet vs. VPN packet) isolated the cause quickly.

## 3. DNS through the tunnel timed out

**Symptom.** The dashboard loaded through the tunnel (port 80), but `dig @10.100.0.1 example.com` from the Mac timed out.

**Diagnosis.** `ufw status verbose` showed a rule for `80/tcp on wg0` but **no rule for port 53**.

**Fix.** `ufw allow in on wg0 to any port 53`, after which `dig @10.100.0.1` answered and the public-IP test still timed out.
<!-- TODO: confirm this was the fix -->

**Lesson.** Since the dashboard worked, the tunnel was fine; the difference had to be specific to port 53.

## 4. SSH session closed by remote host (unresolved)

Shortly after starting WireGuard, the SSH session closed with `Connection ... closed by remote host`. `systemctl status wg-quick@wg0` later showed WireGuard had run continuously for ~17 minutes across that moment, so **the server did not reboot**. Cause not identified; it hasn't recurred. If it does, check `journalctl -u ssh`.
