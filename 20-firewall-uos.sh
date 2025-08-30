#!/usr/bin/env bash
set -euo pipefail

# IPv4-only firewall offer for common managers (firewalld / ufw / iptables)

echo
echo "[?] Open UniFi firewall ports on all interfaces (IPv4 only)?"
echo "    UDP: 3478"
echo "    TCP: 5005, 5514, 6789, 8080, 8444, 8880, 8881, 8882, 9543, 10003, 11443"
read -r -p "Proceed? [y/N]: " ans
[[ "$ans" =~ ^[Yy]$ ]] || { echo "[i] Skipping firewall changes."; exit 0; }

UDP_PORTS=(3478)
TCP_PORTS=(5005 5514 6789 8080 8444 8880 8881 8882 9543 10003 11443)

if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
  echo "[+] firewalld detected: adding high-priority rich rules (IPv4 only)…"
  for p in "${UDP_PORTS[@]}"; do
    firewall-cmd --permanent --add-rich-rule="rule priority='-100' family='ipv4' port port='${p}' protocol='udp' accept" >/dev/null
  done
  for p in "${TCP_PORTS[@]}"; do
    # note: >/dev/null (typo-safe)
    firewall-cmd --permanent --add-rich-rule="rule priority='-100' family='ipv4' port port='${p}' protocol='tcp' accept" >/dev/null
  done
  firewall-cmd --reload >/dev/null
  echo "[+] firewalld rules added and reloaded."
  exit 0
fi

if command -v ufw >/dev/null 2>&1; then
  echo "[+] ufw detected: inserting IPv4 rules at top…"
  for p in "${UDP_PORTS[@]}"; do
    ufw insert 1 allow proto udp to any port "${p}" || true
  done
  for p in "${TCP_PORTS[@]}"; do
    ufw insert 1 allow proto tcp to any port "${p}" || true
  done
  echo "[i] ufw rules inserted. (Note: ufw must be enabled to take effect: 'ufw enable')"
  exit 0
fi

if command -v iptables >/dev/null 2>&1; then
  echo "[+] iptables detected: inserting IPv4 ACCEPT rules at top…"
  for p in "${UDP_PORTS[@]}"; do iptables -I INPUT 1 -p udp --dport "${p}" -j ACCEPT || true; done
  for p in "${TCP_PORTS[@]}"; do iptables -I INPUT 1 -p tcp --dport "${p}" -j ACCEPT || true; done
  echo "[i] If using iptables directly, ensure rules are persisted by your distro's mechanism."
  exit 0
fi

echo "[!] No supported firewall manager detected; skipping."
exit 0
