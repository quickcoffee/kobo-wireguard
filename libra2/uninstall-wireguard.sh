#!/bin/sh

set -e

echo "Uninstalling WireGuard ..."

if [ -x /usr/local/wireguard/stop.sh ]; then
  /usr/local/wireguard/stop.sh || true
fi

echo "Removing TUN kernel module from /lib/modules/wireguard ..."
rm -f /lib/modules/wireguard/kernel/drivers/net/tun.ko
echo "Removing WireGuard binaries from /mnt/onboard/wireguard/bin and /usr/bin ..."
rm -rf /mnt/onboard/wireguard/bin
rm -f /usr/bin/wireguard-go /usr/bin/wg

echo "Removing WireGuard boot scripts from /usr/local/wireguard ..."
rm -rf /usr/local/wireguard

echo "Removing WireGuard udev rule from /etc/udev/rules.d ..."
rm -f /etc/udev/rules.d/98-wireguard.rules

echo "Uninstallation complete!"
echo "Note: /mnt/onboard/wireguard/*.conf and key material were left in place."
