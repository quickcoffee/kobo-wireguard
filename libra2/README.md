# Kobo Libra 2

## Modules
WireGuard requires the TUN/TAP device driver. The stock Libra 2 image does not include it, so this repo ships a pre-built `tun.ko` in `modules/` and installs it under `/lib/modules/wireguard/`.

## Installation and configuration

Run `sh install-wireguard.sh` in the device directory as root. Under `/mnt/onboard/wireguard/`, add `wg0.conf` with the WireGuard peer settings, `wg0.addresses` with your tunnel address, and `wg0.routes` for any remote subnets beyond the connected tunnel subnet. Use `wg0.dns` to supply an optional DNS override.

See the [project README](../README.md) for requirements, split-tunnel routing, and troubleshooting.
