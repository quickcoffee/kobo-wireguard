#!/bin/sh
# Bring up WireGuard interface if configuration exists
if [ -f /mnt/onboard/wireguard/config/wg0.conf ]; then
  if ! ip link show wg0 &>/dev/null; then
    wg-quick up /mnt/onboard/wireguard/config/wg0.conf
  fi
fi