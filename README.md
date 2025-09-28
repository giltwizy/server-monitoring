# Server Health & Resource Monitor

This project provides a simple **Linux shell script** (`health_monitor.sh`) that monitors server health, including CPU load, memory usage, disk usage, and service availability. It generates logs in CSV format and sends alerts (via email or webhook) if thresholds are exceeded.

---

## Features

- Monitors:
  - CPU load averages (1/5/15 minutes)
  - Memory usage (percentage)
  - Disk usage (root partition, `/`)
  - Status of critical services (`systemd` units)
- Saves snapshots to a CSV log (`/var/log/health_monitor.csv`).
- Sends alerts via:
  - Email (using `mailx`)
  - Webhook (using `curl`)
- Supports automatic service restart (optional).
- Fully configurable via variables in the script.

---

## Requirements

- Linux system with `bash`
- Utilities:
  - `df`, `awk`, `systemctl`, `mailx`, `curl`
- Root or `sudo` permissions (to check/restart services).

---

## Installation

1. Save the script to `/usr/local/bin/`:

   ```bash
   sudo cp health_monitor.sh /usr/local/bin/health_monitor.sh
   sudo chmod +x /usr/local/bin/health_monitor.sh
   ```

2. Configure thresholds and services inside the script (edit the **CONFIG** section):

   ```bash
   vi /usr/local/bin/health_monitor.sh
   ```

   Example configuration:

   ```bash
   ALERT_EMAIL="admin@example.com"
   WEBHOOK_URL="https://hooks.example.com/alert"
   LOAD_WARN=2.0
   DISK_WARN=90
   MEM_WARN=90
   CHECK_SERVICES=("nginx" "mysql")
   AUTO_RESTART=false
   ```

3. Ensure logging directory exists:

   ```bash
   sudo mkdir -p /var/log
   sudo touch /var/log/health_monitor.csv
   sudo chown $(whoami):$(whoami) /var/log/health_monitor.csv
   ```

---

## Usage

### Run manually

```bash
/usr/local/bin/health_monitor.sh
```

This appends a new snapshot to `/var/log/health_monitor.csv` and sends alerts if thresholds are exceeded.

### Automate with cron

To check every 5 minutes, add this to root’s crontab:

```bash
sudo crontab -e
```

Add the line:

```cron
*/5 * * * * /usr/local/bin/health_monitor.sh
```

---

## Output

- Log file: `/var/log/health_monitor.csv`  
  Example line:

  ```csv
  timestamp,load1,load5,load15,mem_used_percent,disk_use_percent
  2025-09-28T12:30:00+03:00,0.20,0.10,0.05,35,40
  ```

- Alerts (if configured):
  - Email: sent to `ALERT_EMAIL`
  - Webhook: POST request to `WEBHOOK_URL`

---

## Testing

1. Lower thresholds temporarily inside the script (e.g., set `DISK_WARN=1`) to trigger alerts.
2. Stop one of the monitored services (e.g., `nginx`) and run the script:

   ```bash
   sudo systemctl stop nginx
   /usr/local/bin/health_monitor.sh
   ```

   You should receive an alert.

---

## Security Notes

- Run as root for accurate system/service checks.
- Ensure email and webhook credentials (if any) are secure.
- Use `AUTO_RESTART=true` carefully (only if safe to auto-restart services).

---

## License

MIT License – free to use and modify.

