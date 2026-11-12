# Week 10: End-to-End Performance Investigation

## What this does
- The smoke and ramped k6 tests measure latency, throughput, and failures.
- run-k6.sh runs a test against the web Service and saves its results.
- k6-stat.sh reads saved measurements; throttle.sh measures CPU throttling.
- sql.sh runs SQL inside the database pod.
- week-5/db.tf loads pg_stat_statements when Postgres starts.
- The GitHub Actions workflow starts the Compose app, adds 10,000 tickets, and runs the smoke test.
- check.sh verifies the final setup.

## What lives where
| Location | Contents | Survives deleting the VM? |
| --- | --- | --- |
| GitHub repository | App, infrastructure files, scripts, workflow, and runbook | Yes |
| GitHub Actions | Performance check and its run history, subject to retention | Yes |
| VM | Installed k6, local images, saved test results, and database index | No |
| Prometheus | Resource and throttling measurements | No |

## Runbook 1: The home page returns every ticket

### Symptoms and diagnosis
With 10,000 synthetic tickets added, responses grew to approximately
7,109 KB and the smoke test exceeded its 500 ms p95 threshold.

pg_stat_statements showed 192 calls returning 1,920,576 rows:
10,003 rows per call. Mean database execution time was 12.8 ms.
An EXPLAIN run completed in 1.286 ms.

The web container was throttled during 65% of CPU periods.
Memory was approximately 162.6 MiB, below its 256 MiB limit.
The web restart count remained at four, and VM CPU usage was about 9.3%.

### Root cause
SELECT * FROM tickets ORDER BY id DESC returned the entire table.
The web app had to render and send a large HTML page for every request.

### Fix
1. Add LIMIT 50 to the home page query in week-4/app/app.py.
2. Change the heading to Latest tickets.
3. Build and import a new image tag into k3s.
4. Update week-5/web.tf to use week-4-web:v2.
5. Ship the changes through a pull request and the deployment pipeline.
6. Run the smoke test again and compare response size and latency.

### Measurements
- Seeded p95: 2921 ms
- Fixed p95: 19 ms
- Unbounded CPU periods throttled: 65%
- Response size after the fix: approximately 37 KB
- Target: p95 below 500 ms and fewer than 1% failed requests

## Database index investigation
The query for the ten newest open tickets benefits from:
CREATE INDEX idx_tickets_status_created ON tickets (status, created_at DESC).

The indexed plan used idx_tickets_status_created, accessed three shared
buffers, and completed in 0.038 ms in the measured run.

This index exists only in the current database. A versioned database
migration would recreate it when setting up a new database.

## Runbook 2: The web CPU limit is too low

### Symptoms and diagnosis
The ramped test became slow and returned failed requests after the live
CPU limit was reduced to 50m. OpenTofu showed that the live Deployment
no longer matched the 500m limit declared in Git.

### Root cause
A manual kubectl resource change bypassed the pull request pipeline
and restricted the web container to 0.05 CPU cores.

### Fix
1. Inspect the live web Deployment CPU limit.
2. Run tofu plan from week-5 and review the drift.
3. Confirm the only planned change restores the limit from 50m to 500m.
4. Run tofu apply and wait for the web Deployment rollout.
5. Run the ramped test with the label restored.
6. Check throttling and verify the latency and failure thresholds pass.

### Measurements
- Throttled p95: 4304 ms
- Restored p95: 37 ms
- CPU periods throttled with 50m: 78%
- CPU periods throttled after recovery: 8%
- Throughput: 4.6 requests/s throttled; 17.9 requests/s restored
- Failed requests: approximately 15% throttled; 0% restored

## Performance regression check
The performance smoke test runs on relevant pull requests.
It seeds 10,000 tickets and checks p95 below 500 ms and failures below 1%.

Test PR #19 removed LIMIT 50. The performance check failed with
p95 of 878.48 ms while the three deployment checks passed.
The test PR was closed without merging.

## Known limitations
- The home page shows only the newest 50 tickets without pagination.
- Request frequency is not limited.
- There are no throttling alerts.
- The index is not yet managed by a database migration.
- VM load tests share CPU with the app and other local jobs.
- The CI test runs Compose on GitHub and cannot detect live cluster drift.
- The performance check is not required to merge.
- GitHub runner performance can vary between runs.
