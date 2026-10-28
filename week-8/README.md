# Week 8, Security Hardening and Shifting Left

## What this does
- Hardens the workload with OpenTofu: web runs as user 10001 with no privilege escalation and no capabilities. Both Deployments have CPU and memory limits. A NetworkPolicy lets only pods labeled app=web reach db.
- Moves checks left. The deploy gate runs a security scan on every pull request, and the protect-main GitHub ruleset requires all three gate jobs to pass.
- Makes the deploy ask first. week-7/deploy.sh saves the plan and stops if it would delete or replace anything. A person reviews the plan before approving an intended deletion manually.
- Keeps state files and deploy logs private to my user.

## What lives where
| Where | What | Survives deleting the VM? |
| --- | --- | --- |
| GitHub | Active ruleset and workflow execution | Yes |
| Repository on GitHub | OpenTofu files, deploy script, workflow, and ruleset.json | Yes |
| VM | File permissions, cron, and local state | No |

## Rebuild the VM side
After cloning the repository on a new VM and finishing the Week 7 rebuild steps:

```bash
chmod 600 week-5/terraform.tfstate* ~/deploy.log ~/.deployed-commit
chmod g-w,o-rwx ~
```

If the ruleset is missing on GitHub, recreate it from the repository root:

```bash
gh api --method POST repos/{owner}/{repo}/rulesets --input week-8/ruleset.json
```

## Check on it
```bash
kubectl exec deploy/web -- id
kubectl get networkpolicy
gh api repos/{owner}/{repo}/rulesets --jq '.[] | "\(.name) \(.enforcement)"'
grep BLOCKED ~/deploy.log | tail -n 3
```

## Known limitations
SSH still accepts passwords, there is no host firewall, and the state file holds secrets in plain text. The cron job runs as my own user. The web container can write to its filesystem, and db runs as root inside its container. The scan covers six rules in week-5 only, and anyone with repository admin access can delete the ruleset. Database backups are not configured.
