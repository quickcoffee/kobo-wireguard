#!/bin/sh

set -e
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:$PATH

echo
echo "Installing WireGuard for Kobo Libra 2!"
uname -a
echo

for utility in ip setsid timeout; do
  if ! command -v "$utility" >/dev/null 2>&1; then
    echo "Missing required command: $utility" >&2
    exit 1
  fi
done
if ! command -v flock >/dev/null 2>&1 && ! busybox --list 2>/dev/null | grep -qx flock; then
  echo "Missing flock (standalone command or BusyBox applet required)." >&2
  exit 1
fi

echo "Validating required WireGuard binaries ..."
if [ ! -x binaries/wireguard/wireguard-go ]; then
  echo "Missing executable: binaries/wireguard/wireguard-go"
  exit 1
fi

if [ ! -x binaries/wireguard/wg ]; then
  echo "Missing executable: binaries/wireguard/wg"
  exit 1
fi

if [ -x /usr/local/wireguard/service.sh ]; then
  /usr/local/wireguard/service.sh shutdown
elif [ -x /usr/local/wireguard/stop.sh ] && ip link show dev wg0 >/dev/null 2>&1; then
  echo "Stop the running WireGuard interface with /usr/local/wireguard/stop.sh before upgrading." >&2
  exit 1
fi

echo "Copying TUN kernel module into /lib/modules/wireguard ..."
mkdir -p /lib/modules/wireguard/kernel/drivers/net
cp modules/tun.ko /lib/modules/wireguard/kernel/drivers/net/tun.ko

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

rm -f /usr/local/wireguard/on-wlan-up.sh /usr/local/wireguard/on-wlan-down.sh
/usr/local/wireguard/service.sh enable
/usr/local/wireguard/boot.sh

echo
if [ ! -f /mnt/onboard/wireguard/wg0.conf ]; then
  echo "Create /mnt/onboard/wireguard/wg0.conf and its address and route files."
fi
echo "Installation complete. WireGuard will start when the network is ready."
echo "Automatic setup log is at /tmp/kobo-wireguard/wg0.setup.log."
