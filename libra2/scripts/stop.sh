#!/bin/sh

set -e
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:$PATH

WG_IFACE="${WG_IFACE:-wg0}"
WG_DIR="/mnt/onboard/wireguard"
WG_ROUTES="${WG_DIR}/${WG_IFACE}.routes"
WG_PID_FILE="/tmp/wireguard-go-${WG_IFACE}.pid"
RESOLV_CONF="/etc/resolv.conf"
RESOLV_BACKUP="/tmp/${WG_IFACE}.resolv.conf.bak"

if [ -f "${WG_ROUTES}" ]; then
  while IFS= read -r route; do
    case "${route}" in
      ''|'#'*) continue ;;
    esac
    ip route del "${route}" dev "${WG_IFACE}" 2>/dev/null || true
  done < "${WG_ROUTES}"
fi

if ip link show "${WG_IFACE}" >/dev/null 2>&1; then
  ip link set down dev "${WG_IFACE}" 2>/dev/null || true
  ip link delete "${WG_IFACE}" 2>/dev/null || true
fi

if [ -f "${WG_PID_FILE}" ]; then
  pid=$(cat "${WG_PID_FILE}")
  if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
    kill -15 "${pid}" 2>/dev/null || true
  fi
  rm -f "${WG_PID_FILE}"
fi

if [ -f "${RESOLV_BACKUP}" ]; then
  cp "${RESOLV_BACKUP}" "${RESOLV_CONF}" 2>/dev/null || true
  rm -f "${RESOLV_BACKUP}"
fi

pkill -f "wireguard-go ${WG_IFACE}" 2>/dev/null || true
