#!/usr/bin/env bash
# health_monitor.sh
# Periodic server health check: cpu load, memory, disk, services.
# Produces CSV log and alerts on thresholds.

set -euo pipefail

# ---- CONFIG ----
LOG_CSV="/var/log/health_monitor.csv"
ALERT_EMAIL="admin@example.com"
WEBHOOK_URL=""
LOAD_WARN=2.0         # 1-min load threshold per CPU count idea (adjust)
DISK_WARN=90          # percent
MEM_WARN=90           # percent used (approx)
CHECK_SERVICES=("nginx" "mysql")   # systemd service names to check
AUTO_RESTART=false    # set to true to attempt automatic restarts
# --------------------

mkdir -p "$(dirname "${LOG_CSV}")"

timestamp=$(date --iso-8601=seconds)
# load averages
read -r load1 load5 load15 < <(cut -d ' ' -f1-3 /proc/loadavg)
# memory usage
mem_total_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
mem_avail_kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
mem_used_percent=$(( (mem_total_kb - mem_avail_kb) * 100 / mem_total_kb ))
# disk usage for root
disk_use_percent=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
# prepare CSV header
if [ ! -f "${LOG_CSV}" ]; then
  echo "timestamp,load1,load5,load15,mem_used_percent,disk_use_percent" > "${LOG_CSV}"
fi

echo "${timestamp},${load1},${load5},${load15},${mem_used_percent},${disk_use_percent}" >> "${LOG_CSV}"

# alerts
ALERTS=""
# compare load (as numeric)
# convert to integer hundredths for safe compare
load1_h="$(awk -v l="${load1}" 'BEGIN{printf("%d", l*100)}')"
LOAD_WARN_H="$(awk -v l="${LOAD_WARN}" 'BEGIN{printf("%d", l*100)}')"
if [ "${load1_h}" -gt "${LOAD_WARN_H}" ]; then
  ALERTS="${ALERTS}\nHigh load: ${load1} (threshold ${LOAD_WARN})"
fi

if [ "${mem_used_percent}" -ge "${MEM_WARN}" ]; then
  ALERTS="${ALERTS}\nHigh memory usage: ${mem_used_percent}% (threshold ${MEM_WARN}%)"
fi

if [ "${disk_use_percent}" -ge "${DISK_WARN}" ]; then
  ALERTS="${ALERTS}\nHigh disk usage: ${disk_use_percent}% (threshold ${DISK_WARN}%)"
fi

# service checks
for svc in "${CHECK_SERVICES[@]}"; do
  if systemctl is-active --quiet "${svc}"; then
    : # ok
  else
    ALERTS="${ALERTS}\nService ${svc} is not active!"
    if [ "${AUTO_RESTART}" = true ]; then
      echo "Attempting restart of ${svc}"
      systemctl restart "${svc}" || ALERTS="${ALERTS}\nFailed to restart ${svc}"
    fi
  fi
done

if [ -n "${ALERTS}" ]; then
  SUBJECT="Server alert on $(hostname -s): $(date +'%F %T')"
  BODY="Server health alert:\n${ALERTS}\n\nLog snapshot: ${timestamp}\nSee ${LOG_CSV}"
  # email
  if command -v mailx >/dev/null 2>&1 && [ -n "${ALERT_EMAIL}" ]; then
    printf "%b" "${BODY}" | mailx -s "${SUBJECT}" "${ALERT_EMAIL}"
  fi
  # webhook
  if [ -n "${WEBHOOK_URL}" ]; then
    printf "%b" "${BODY}" | curl -sS -X POST -H "Content-Type: text/plain" --data-binary @- "${WEBHOOK_URL}" || true
  fi
fi

exit 0
