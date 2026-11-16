# Kobo Clara BW

## Modules
WireGuard requires the TUN/TAP device driver. This device family already exposes TUN, so no extra kernel module is installed.

## Installation and configuration

Run `sh install-wireguard.sh` in the device directory as root. Under `/mnt/onboard/wireguard/`, add `wg0.conf` with the WireGuard peer settings, `wg0.addresses` with your tunnel address, and `wg0.routes` for any remote subnets beyond the connected tunnel subnet. Use `wg0.dns` to supply an optional DNS override.

See the [project README](../README.md) for requirements, split-tunnel routing, and troubleshooting.
