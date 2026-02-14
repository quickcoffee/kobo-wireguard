# Kobo Libra 2

## Modules
WireGuard requires the TUN/TAP device driver. The stock Libra 2 image does not include it, so this repo ships a pre-built `tun.ko` in `modules/` and installs it under `/lib/modules/wireguard/`.

## WireGuard binaries
Before running `install-wireguard.sh`, place ARMv7 binaries in `binaries/wireguard/`:

- `wireguard-go`
- `wg`

## Runtime files
Create these files on device storage:

- `/mnt/onboard/wireguard/wg0.conf` (required)
- `/mnt/onboard/wireguard/wg0.addresses` (optional)
- `/mnt/onboard/wireguard/wg0.routes` (optional)
- `/mnt/onboard/wireguard/wg0.dns` (optional, one DNS server IP per line)
