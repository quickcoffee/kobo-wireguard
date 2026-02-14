#!/bin/sh

set -e
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:$PATH

WG_IFACE="${WG_IFACE:-wg0}"
WG_DIR="/mnt/onboard/wireguard"
WG_CONF="${WG_DIR}/${WG_IFACE}.conf"
WG_ADDRS="${WG_DIR}/${WG_IFACE}.addresses"
WG_ROUTES="${WG_DIR}/${WG_IFACE}.routes"
WG_DNS="${WG_DIR}/${WG_IFACE}.dns"
WG_PID_FILE="/tmp/wireguard-go-${WG_IFACE}.pid"
RESOLV_CONF="/etc/resolv.conf"
RESOLV_BACKUP="/tmp/${WG_IFACE}.resolv.conf.bak"

if [ ! -f "${WG_CONF}" ]; then
  echo "Skipping WireGuard start: ${WG_CONF} does not exist."
  exit 0
fi

if ip link show "${WG_IFACE}" >/dev/null 2>&1; then
  exit 0
fi

wireguard-go "${WG_IFACE}" >"/${WG_IFACE}-wireguard-go.log" 2>&1 &
wg_pid=$!
echo "${wg_pid}" > "${WG_PID_FILE}"

sleep 1
if ! wg setconf "${WG_IFACE}" "${WG_CONF}"; then
  kill -15 "${wg_pid}" 2>/dev/null || true
  rm -f "${WG_PID_FILE}"
  exit 1
fi

ip link set up dev "${WG_IFACE}"

if [ -f "${WG_ADDRS}" ]; then
  while IFS= read -r addr; do
    case "${addr}" in
      ''|'#'*) continue ;;
    esac
    ip address add "${addr}" dev "${WG_IFACE}" 2>/dev/null || true
  done < "${WG_ADDRS}"
fi

if [ -f "${WG_ROUTES}" ]; then
  while IFS= read -r route; do
    case "${route}" in
      ''|'#'*) continue ;;
    esac
    ip route add "${route}" dev "${WG_IFACE}" 2>/dev/null || true
  done < "${WG_ROUTES}"
fi

if [ -f "${WG_DNS}" ]; then
  RESOLV_NEW="/tmp/${WG_IFACE}.resolv.conf.new"
  dns_count=0
  : > "${RESOLV_NEW}"
  while IFS= read -r ns; do
    case "${ns}" in
      ''|'#'*) continue ;;
    esac
    echo "nameserver ${ns}" >> "${RESOLV_NEW}"
    dns_count=$((dns_count + 1))
  done < "${WG_DNS}"
  if [ "${dns_count}" -gt 0 ]; then
    cp "${RESOLV_CONF}" "${RESOLV_BACKUP}" 2>/dev/null || true
    cp "${RESOLV_NEW}" "${RESOLV_CONF}" 2>/dev/null || true
  fi
  rm -f "${RESOLV_NEW}"
fi
