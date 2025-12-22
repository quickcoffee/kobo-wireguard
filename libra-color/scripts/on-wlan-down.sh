#!/bin/sh
# Bring down WireGuard interface if it's up
if ip link show wg0 &>/dev/null; then
  wg-quick down wg0
fi