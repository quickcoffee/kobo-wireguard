#!/bin/sh

# Make sure to load the TUN kernel module and create the /dev/net/tun device
if ! lsmod | grep -q "^tun"; then
  insmod /lib/modules/wireguard/kernel/drivers/net/tun.ko
  if [ ! -c /dev/net/tun ]; then
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200
  fi
fi

# Make absolutely sure that iptables is in the PATH
export PATH=/usr/sbin:/usr/bin:$PATH

# Make sure /mnt/onboard is mounted
timeout 5 sh -c "while ! grep -q /mnt/onboard /proc/mounts; do sleep 0.1; done"
if [[ $? -eq 143 ]]; then
    exit 1
fi

# Check if WireGuard configuration exists and bring up the interface
if [ -f /mnt/onboard/wireguard/config/wg0.conf ]; then
  if ! ip link show wg0 &>/dev/null; then
    WG_QUICK_USERSPACE_IMPLEMENTATION=boringtun wg-quick up /mnt/onboard/wireguard/config/wg0.conf &> /wg-quick.log
  fi
fi

exit 0