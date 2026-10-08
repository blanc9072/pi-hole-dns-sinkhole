# Setup: VPN-only Pi-hole on a cloud server

This documents how the server was built, in the order it was done, with the reason for each step.

## Environment

| Item | Value |
|---|---|
| Host | DigitalOcean server |
| OS | Ubuntu 24.04.5 LTS, x86_64, kernel 6.8 |
| Resources | ~3.8 GB RAM, ~29 GB disk |
| Client | MacBook Air (macOS) with the official WireGuard app |
| VPN subnet | `10.100.0.0/24` (server `.1`, Mac `.2`) |
| WireGuard port | UDP `47111` |

**Why not the first server?** The project started on a shared Oracle Cloud server, but it ran other people's services (web server, game servers) and I had no access to its cloud firewall. Pi-hole changes how a server resolves DNS, which every service depends on, so I moved to a dedicated server rather than risk breaking things I didn't own.

## Design goal

Pi-hole must **never** be reachable from the public internet. A DNS server anyone can query is an "open resolver," which attackers abuse to flood other targets with traffic. Pi-hole's maintainers recommend reaching a cloud Pi-hole only through a VPN. So:

- Public internet can reach only **SSH (22/tcp)** and **WireGuard (47111/udp)**.
- DNS (53) and the dashboard (80) are allowed **only on the WireGuard interface `wg0`**.

See [security.md](security.md) for details.

## 1. Pre-flight checks

```bash
cat /etc/os-release      # OS and version (Pi-hole supports Ubuntu)
uname -m                 # CPU architecture
uname -r                 # kernel; >= 5.6 includes WireGuard
df -h /                  # free disk
free -h                  # memory ("available" column)
sudo ss -tulpn           # what's already listening, and on which address
ip -br addr              # existing networks (check the VPN subnet won't clash)
sudo ufw status verbose  # host firewall
sudo iptables -L INPUT -n -v --line-numbers
```

Finding: the server had **no firewall at all** (`ufw` inactive, empty iptables INPUT chain with policy ACCEPT). The firewall therefore went on first.

## 2. Firewall (deny by default)

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp          # SSH, allowed BEFORE enabling so I don't lock myself out
ufw allow 47111/udp       # WireGuard
ufw enable
```

After enabling, I opened a **new** SSH session to confirm access still worked before closing the old one. The VPN-only rules for Pi-hole were added after Pi-hole was installed (step 7). [`server/firewall.sh`](../server/firewall.sh) contains the final rule set.

## 3. WireGuard server

```bash
apt update
apt install -y wireguard wireguard-tools
cd /etc/wireguard
umask 077                                            # new files readable by root only
wg genkey | tee server.key | wg pubkey > server.pub  # private key -> public key
```

Config written with a heredoc so the private key is inserted without ever being displayed:

```bash
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.100.0.1/24, fd08:4711::1/64
ListenPort = 47111
PrivateKey = $(cat /etc/wireguard/server.key)
EOF

systemctl enable --now wg-quick@wg0   # start now and at every boot
wg show                               # expect: interface wg0, listening port 47111
```

Template: [`server/wg0.conf.example`](../server/wg0.conf.example)

## 4. Mac client

1. Installed the official WireGuard app.
2. **Add Empty Tunnel**: the app generates the Mac's key pair.
3. Filled in the config from [`server/client.conf.example`](../server/client.conf.example).

Key choice: **split tunnel** (`AllowedIPs = 10.100.0.1/32`). Only traffic for the server's VPN address goes through the tunnel; normal browsing doesn't touch the server.

## 5. Register the Mac on the server

```bash
cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
PublicKey = <MAC_PUBLIC_KEY>
AllowedIPs = 10.100.0.2/32
EOF
systemctl restart wg-quick@wg0
```

Verified from the Mac with `ping 10.100.0.1`, and on the server with `wg show` showing a **latest handshake** line. (This step had two problems; see [troubleshooting.md](troubleshooting.md).)

## 6. Free port 53, then install Pi-hole

Ubuntu's `systemd-resolved` holds port 53, which blocks Pi-hole. [`server/free-port-53.sh`](../server/free-port-53.sh) disables its stub listener and points the server's own DNS at the provider's upstream servers, so the server can still update itself if Pi-hole ever fails.

Then the official installer from Pi-hole's docs:

```bash
curl -sSL https://install.pi-hole.net | bash
```

Installer choices:

<!-- TODO: fill in what you actually chose -->
- Interface: `TODO`
- Upstream DNS: `TODO`
- Blocklist: default (~72,500 domains at install)
- Query logging: on (needed for the analysis)
- Privacy level: show everything

## 7. VPN-only access to Pi-hole

```bash
ufw allow in on wg0 to any port 53             # DNS, TCP and UDP
ufw allow in on wg0 to any port 80 proto tcp   # dashboard
```

`in on wg0` restricts these rules to traffic that arrived through the tunnel.

## 8. Verify

From the Mac, tunnel on:

```bash
./tests/check_exposure.sh <SERVER_PUBLIC_IP>
```

| Test | Result |
|---|---|
| DNS via VPN (`dig @10.100.0.1`) | Answers |
| DNS via public IP | Times out (not an open resolver) |
| Dashboard via VPN (`http://10.100.0.1/admin`) | Loads |
