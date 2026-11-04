# Week 9, Data Observability and Backup

## What this does
- `week-5/exporter.tf` runs a Postgres exporter so Prometheus can report database availability, database size, and estimated table row counts.
- `week-5/network.tf` allows only the web pods and database exporter to connect to the database.
- `week-9/backup.sh` creates a backup in `~/backups` every five minutes through cron, checks each dump, and keeps the newest 12. A dump with no tables is rejected.
- `week-9/restore.sh` restores a selected backup. Without an argument, it selects the newest backup.
- `week-9/sql.sh` runs SQL or prints exact row counts.
- `week-9/check.sh` checks database availability, exporter access, backup freshness, backup readability, and the cron entry.

## What lives where
| Where | What | Survives deleting the VM? |
| --- | --- | --- |
| GitHub repository | Scripts, OpenTofu configuration, README | Yes |
| My Windows computer | A manually copied backup in C:\Users\notro\VM-Backups | Yes, but only as fresh as the last copy |
| VM | Database volume, ~/backups, cron entries | No |
| Prometheus | Database metrics | No; history is lost when its pod restarts |

## Runbook: restore the database
- **Incident:** The database tables have been deleted.
- **Symptoms:** The app shows errors or missing tickets, and `./week-9/sql.sh` prints `(no tables)`. After a scrape, the table row metric disappears while `pg_up` remains 1.
- **Recovery:**
  1. Run `ls -1t ~/backups/db-*.dump` and select a backup from before the data loss. Do not automatically assume the newest backup contains the missing data.
  2. Run `./week-9/restore.sh ~/backups/<file>`.
  3. Run `./week-9/sql.sh` and compare the restored rows with the expected count.
  4. Run `./week-9/check.sh` and verify the application.
- **Measured in the completed drill:**
  - Rows before: tickets: 3
  - Rows after: tickets: 3
  - Age of the selected backup: 217 seconds (target: 300 seconds)
  - Recovery time, including waiting for monitoring: 162 seconds (target: 600 seconds)
  - Prometheus reported no table row results while pg_up stayed 1.
  - Cron rejected a backup while the database had no tables.

## Rebuild on a fresh VM
The database volume, local backups, and cron entries must be recreated.
1. Follow the Week 7 and Week 8 rebuild steps to restore the cluster, application, monitoring, delivery loop, and deploy cron entry.
2. Deploy the Week 9 exporter and network policy through the reviewed configuration.
3. Create a private backup folder: `mkdir -m 700 ~/backups`.
4. From Windows PowerShell, copy the saved backup to the VM: `scp -P 2222 "$HOME\VM-Backups\<file>" roony@127.0.0.1:backups/`.
5. On Ubuntu, restrict the copied file: `chmod 600 ~/backups/<file>`.
6. Restore with `./week-9/restore.sh ~/backups/<file>`.
7. From the repository root, restore the backup schedule once: `( crontab -l 2>/dev/null; echo "*/5 * * * * $PWD/week-9/backup.sh >> $HOME/backup.log 2>&1" ) | crontab -`.
8. Verify the restored rows, run a fresh backup, and run `./week-9/check.sh`.

## Known limitations
Backups are not encrypted, and the off-VM copy is manual. The exporter uses the database superuser. No alerts notify me when the database becomes unavailable or backups stop. A readable dump containing a table can still contain zero rows. Keeping only 12 backups at five-minute intervals provides roughly one hour of history while backups succeed. The drill restored into the existing cluster; recovery onto a fresh VM remains untested. The Postgres image uses a floating tag.
