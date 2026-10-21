# Week 7: Continuous Delivery

## What this does
- `.github/workflows/deploy-gate.yml` runs on every push to `main`.
- Its two jobs validate the OpenTofu configuration and render the Prometheus chart.
- `week-7/deploy.sh` checks for a new commit on `origin/main` and deploys only if the gate passed for that exact commit.
- Deployment runs OpenTofu for the application and Helm for Prometheus.
- Cron runs the script every two minutes. The VM connects out to GitHub.
- Guards reject the wrong branch, uncommitted tracked changes, and local commits that prevent a fast-forward.
- A lock prevents overlapping deployments. Only successful deployments are recorded.

## Requirements
- The Week 5 application and Week 6 Prometheus on k3s
- OpenTofu, Helm, kubectl, Git, and authenticated GitHub CLI
- An active cron service
- Local kubeconfig, OpenTofu state, and terraform.tfvars

## Deploy
Merge a pull request into main, wait for the gate, and allow cron to deploy.

To run manually:
```bash
./week-7/deploy.sh
```

## Roll back
Create a branch and revert the intended merge:
```bash
git revert -m 1 <merge-commit>
```
Open and merge a pull request containing the revert. The gate and cron deploy it.
A revert changes configuration; it does not restore database contents or lost Prometheus history.

## Check deployment
```bash
crontab -l
tail -n 20 ~/deploy.log
gh run list --workflow deploy-gate.yml --limit 3
```

## Rebuild on a fresh VM
1. Install k3s, OpenTofu, Helm, Git, and GitHub CLI.
2. Configure kubeconfig and run gh auth login.
3. Clone this repository and check out main.
4. Copy week-5/terraform.tfvars.example to week-5/terraform.tfvars and supply real values.
5. Build and import the week-4-web image into k3s as in the earlier labs.
6. For a new empty cluster, run ./week-7/deploy.sh to create the resources. Recovering an existing cluster requires restoring its OpenTofu state or importing its resources first.
7. Add the schedule from the repository root:
```bash
( crontab -l 2>/dev/null; echo "*/2 * * * * $PWD/week-7/deploy.sh >> $HOME/deploy.log 2>&1" ) | crontab -
```

The cron schedule, deployment log, last deployed commit record, credentials,
variable values, and OpenTofu state are local to the VM and are not restored by cloning Git.
Application data needs its own backup and recovery process.

## Known limitations
Deployment uses a working folder that is also edited manually.
State and secrets live on one VM.
OpenTofu applies automatically without a person approving the plan.
The gate catches only problems covered by its checks.
Deployment runs as my user, so code merged into main that passes the gate can run with my user's permissions.
Prometheus uses temporary storage and loses its stored metrics when its server pod is replaced.
