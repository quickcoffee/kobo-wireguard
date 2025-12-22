#!/bin/sh

set -e

echo
echo "Installing WireGuard for Kobo Clara BW!"
uname -a
echo

echo "Installing iptables into /sbin and /lib ..."
cp binaries/iptables/sbin/* /sbin
cp binaries/iptables/lib/* /lib

ln -sf /sbin/xtables-multi /sbin/iptables
ln -sf /lib/libxtables.so.10.0.0 /lib/libxtables.so.10
ln -sf /lib/libip4tc.so.0.1.0 /lib/libip4tc.so.0
ln -sf /lib/libip6tc.so.0.1.0 /lib/libip6tc.so.0

echo "Installing WireGuard binaries into /mnt/onboard/wireguard and symlinking them into /usr/bin ..."
mkdir -p /mnt/onboard/wireguard
cp binaries/wireguard/* /mnt/onboard/wireguard/

# Make binaries executable
chmod +x /mnt/onboard/wireguard/wg
chmod +x /mnt/onboard/wireguard/wg-quick

# Symlink WireGuard binaries to /usr/bin
ln -sf /mnt/onboard/wireguard/wg /usr/bin/wg
ln -sf /mnt/onboard/wireguard/wg-quick /usr/bin/wg-quick

echo "Installing WireGuard boot and load scripts into /usr/local/wireguard ..."
mkdir -p /usr/local/wireguard
cp scripts/* /usr/local/wireguard

echo "Creating WireGuard configuration directory ..."
mkdir -p /mnt/onboard/wireguard/config

echo "Installing WireGuard udev rule into /etc/udev/rules.d ..."
cp rules/* /etc/udev/rules.d

echo
echo "Installation complete!"
echo

echo "WireGuard has been installed successfully!"
echo "To configure WireGuard, create a configuration file at /mnt/onboard/wireguard/config/wg0.conf"
echo "You can then bring up the interface with: wg-quick up wg0"
echo "The WireGuard binaries are located in /mnt/onboard/wireguard."
echo "Note: Place your wg0.conf file in /mnt/onboard/wireguard/config/ before rebooting."
echo
