#!/bin/sh

set -e

echo
echo "Installing WireGuard for Kobo Libra 2!"
uname -a
echo

echo "Copying TUN kernel module into /lib/modules/wireguard ..."
mkdir -p /lib/modules/wireguard/kernel/drivers/net
cp modules/tun.ko /lib/modules/wireguard/kernel/drivers/net/tun.ko
echo "Validating required WireGuard binaries ..."
if [ ! -x binaries/wireguard/wireguard-go ]; then
  echo "Missing executable: binaries/wireguard/wireguard-go"
  exit 1
fi

if [ ! -x binaries/wireguard/wg ]; then
  echo "Missing executable: binaries/wireguard/wg"
  exit 1
fi

echo "Installing WireGuard binaries into /mnt/onboard/wireguard/bin and symlinking into /usr/bin ..."
mkdir -p /mnt/onboard/wireguard/bin
cp binaries/wireguard/wireguard-go /mnt/onboard/wireguard/bin/wireguard-go
cp binaries/wireguard/wg /mnt/onboard/wireguard/bin/wg
chmod 0755 /mnt/onboard/wireguard/bin/wireguard-go /mnt/onboard/wireguard/bin/wg

ln -sf /mnt/onboard/wireguard/bin/wireguard-go /usr/bin/wireguard-go
ln -sf /mnt/onboard/wireguard/bin/wg /usr/bin/wg

echo "Installing WireGuard boot scripts into /usr/local/wireguard ..."
mkdir -p /usr/local/wireguard
cp scripts/* /usr/local/wireguard
chmod 0755 /usr/local/wireguard/*.sh

echo "Installing WireGuard udev rule into /etc/udev/rules.d ..."
cp rules/* /etc/udev/rules.d

echo
if [ ! -f /mnt/onboard/wireguard/wg0.conf ]; then
  echo "No /mnt/onboard/wireguard/wg0.conf found."
  echo "Create wg0.conf and optional wg0.addresses/wg0.routes, then run /usr/local/wireguard/start.sh"
else
  echo "Attempting to start WireGuard ..."
  /usr/local/wireguard/start.sh
fi
echo

echo "Installation complete!"
echo "WireGuard binaries are located in /mnt/onboard/wireguard/bin."
echo "Runtime scripts are located in /usr/local/wireguard."
