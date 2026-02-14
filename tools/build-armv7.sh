#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-${ROOT_DIR}/dist/armv7}"
TARGET_DEVICES="${TARGET_DEVICES:-libra2 libra-color clara-bw}"
BUILD_IMAGE="${BUILD_IMAGE:-golang:1.24-bookworm}"
WIREGUARD_GO_REF="${WIREGUARD_GO_REF:-master}"
WIREGUARD_TOOLS_REF="${WIREGUARD_TOOLS_REF:-v1.0.20250521}"
WG_LDFLAGS="${WG_LDFLAGS:--static}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required"
  exit 1
fi

mkdir -p "${OUT_DIR}"

echo "Building ARMv7 binaries with ${BUILD_IMAGE} ..."
docker run --rm \
  -e WIREGUARD_GO_REF="${WIREGUARD_GO_REF}" \
  -e WIREGUARD_TOOLS_REF="${WIREGUARD_TOOLS_REF}" \
  -e WG_LDFLAGS="${WG_LDFLAGS}" \
  -v "${OUT_DIR}:/out" \
  "${BUILD_IMAGE}" \
  bash -c '
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    export PATH="/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

    apt-get update
    apt-get install -y --no-install-recommends \
      ca-certificates git make pkg-config \
      gcc-arm-linux-gnueabihf libc6-dev-armhf-cross

    workdir="$(mktemp -d)"
    trap "rm -rf \"${workdir}\"" EXIT
    cd "${workdir}"

    git clone --depth 1 --branch "${WIREGUARD_GO_REF}" https://github.com/WireGuard/wireguard-go.git
    git clone --depth 1 --branch "${WIREGUARD_TOOLS_REF}" https://git.zx2c4.com/wireguard-tools

    cd wireguard-go
    go version
    GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0 \
      go build -trimpath -ldflags "-s -w" -o /out/wireguard-go .

    cd "${workdir}/wireguard-tools/src"
    if ! grep -q "WGALLOWEDIP_A_FLAGS" /usr/arm-linux-gnueabihf/include/linux/wireguard.h 2>/dev/null; then
      echo "Applying compatibility patch: kernel headers missing WGALLOWEDIP_A_FLAGS"
      perl -0pi -e '"'"'s/if \(allowedip->flags && !mnl_attr_put_u32_check\(nlh, SOCKET_BUFFER_SIZE, WGALLOWEDIP_A_FLAGS, allowedip->flags\)\)\n\s*goto toobig;/#ifdef WGALLOWEDIP_A_FLAGS\n\t\t\t\tif (allowedip->flags && !mnl_attr_put_u32_check(nlh, SOCKET_BUFFER_SIZE, WGALLOWEDIP_A_FLAGS, allowedip->flags))\n\t\t\t\t\tgoto toobig;\n#else\n\t\t\t\tif (allowedip->flags)\n\t\t\t\t\tret = -EOPNOTSUPP;\n#endif/s'"'"' ipc-linux.h
    fi
    make clean >/dev/null 2>&1 || true
    make \
      CC=arm-linux-gnueabihf-gcc \
      STRIP=arm-linux-gnueabihf-strip \
      RUNSTATEDIR="/var/run" \
      LDFLAGS="${WG_LDFLAGS}" \
      wg

    install -m 0755 wg /out/wg
    arm-linux-gnueabihf-strip /out/wg >/dev/null 2>&1 || true
  '

chmod 0755 "${OUT_DIR}/wireguard-go" "${OUT_DIR}/wg"

echo "Staging binaries into device folders ..."
for device in ${TARGET_DEVICES}; do
  dest="${ROOT_DIR}/${device}/binaries/wireguard"
  if [ ! -d "${dest}" ]; then
    echo "Skipping unknown device directory: ${device}"
    continue
  fi
  install -m 0755 "${OUT_DIR}/wireguard-go" "${dest}/wireguard-go"
  install -m 0755 "${OUT_DIR}/wg" "${dest}/wg"
  echo "  ${device}: updated ${dest}/wireguard-go and ${dest}/wg"
done

echo
echo "Done. Output files:"
echo "  ${OUT_DIR}/wireguard-go"
echo "  ${OUT_DIR}/wg"
echo
echo "If wg fails to build statically on your machine, retry with:"
echo "  WG_LDFLAGS='' tools/build-armv7.sh"
