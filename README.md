# kobo-wireguard
Install scripts for getting WireGuard running on Kobo e-readers and persisting through reboots.

## Supported devices
- Kobo Libra 2
- Kobo Libra Colour (Color)
- Kobo Clara BW

If you have another device and would like to contribute, please open a PR.

## Important requirements
This repo now uses the userspace stack (`wireguard-go` + `wg`) and expects ARMv7 binaries to be present in each device folder:

- `binaries/wireguard/wireguard-go`
- `binaries/wireguard/wg`

Build them automatically with:

```bash
tools/build-armv7.sh
```

## Installation
1. Download this repo onto your Kobo onboard storage and open your device directory.
2. Add `wireguard-go` and `wg` binaries to `binaries/wireguard/` (or run `tools/build-armv7.sh` first).
3. Run `install-wireguard.sh`.
4. Create `/mnt/onboard/wireguard/wg0.conf`.
5. (Optional) Add:
- `/mnt/onboard/wireguard/wg0.addresses` (one CIDR per line)
- `/mnt/onboard/wireguard/wg0.routes` (one route/CIDR per line)
6. Start with `/usr/local/wireguard/start.sh` or reconnect Wi-Fi.

## Config notes
`wg0.conf` is passed directly to `wg setconf`, so it must contain only WireGuard-native config sections and keys (no `Address=` or `DNS=` directives).

Use `wg0.addresses` and `wg0.routes` for addresses/routes that would normally be handled by `wg-quick`.

## Building ARMv7 binaries
`tools/build-armv7.sh` uses Docker to cross-compile:
- `wireguard-go` from `https://github.com/WireGuard/wireguard-go`
- `wg` from `https://git.zx2c4.com/wireguard-tools`

The script writes outputs to `dist/armv7/` and stages them into:
- `libra2/binaries/wireguard/`
- `libra-color/binaries/wireguard/`
- `clara-bw/binaries/wireguard/`

Useful overrides:
- `WIREGUARD_GO_REF=<tag-or-branch>`
- `WIREGUARD_TOOLS_REF=<tag-or-branch>`
- `WG_LDFLAGS=''` (if static linking fails)
- `TARGET_DEVICES='libra2'` (build/stage only one device)

Default tool refs:
- `WIREGUARD_GO_REF=master`
- `WIREGUARD_TOOLS_REF=v1.0.20250521`

## Uninstallation
Run `uninstall-wireguard.sh` from your device directory.

## Improvements from upstream issue reports
- Removed Tailscale/iptables runtime dependency in startup scripts.
- Fixed rule cleanup mismatch by consistently using `98-wireguard.rules`.
- Added `/dev/pts` mount guard in boot path for more stable shell/SSH behavior.
- Added explicit route/address files to reduce accidental full-tunnel breakage of Kobo connectivity.

## Acknowledgements
- [Dylan Staley for early Kobo networking scripts](https://dstaley.com/posts/tailscale-on-kobo-sage)
- [jmacindoe for Kobo kernel module documentation](https://github.com/jmacindoe/kobo-kernel-modules)
