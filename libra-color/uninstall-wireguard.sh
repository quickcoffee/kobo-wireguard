#!/bin/sh

echo "Uninstalling WireGuard..."

# Bring down WireGuard interface if it's up
if ip link show wg0 &>/dev/null; then
  echo "Bringing down WireGuard interface wg0 ..."
  wg-quick down wg0
fi

echo "Removing iptables binaries from /sbin and /lib ..."
rm -f /sbin/xtables-multi /sbin/iptables
rm -f /lib/libxtables.so.10 /lib/libip4tc.so.0 /lib/libip6tc.so.0

echo "Removing WireGuard binaries from /mnt/onboard/wireguard and /usr/bin ..."
rm -rf /mnt/onboard/wireguard
rm -f /usr/bin/wg /usr/bin/wg-quick

echo "Removing WireGuard boot and load scripts from /usr/local/wireguard ..."
rm -rf /usr/local/wireguard

echo "Removing WireGuard udev rule from /etc/udev/rules.d ..."
rm -f /etc/udev/rules.d/98-wireguard.rules

echo "Uninstallation complete!"
