# Week 5: Infrastructure as Code with OpenTofu

## What this does
Defines the Week 4 Flask app, PostgreSQL database, persistent storage,
configuration, and secrets as OpenTofu resources on a local k3s cluster.

## Requirements
- OpenTofu
- A running k3s cluster and ~/.kube/config
- The week-4-web:latest image imported into k3s
- terraform.tfvars filled in using terraform.tfvars.example

## Deploy
Run these commands from week-5/:
- tofu init
- tofu plan
- tofu apply

## Verify
Run kubectl get pods.
Run tofu output -raw port_forward_command, then execute the printed command.

From a second Windows PowerShell window, connect with:
ssh -L 8080:127.0.0.1:8080 roony@127.0.0.1 -p 2222

Visit http://localhost:8080.

## Observations
- Changing the configuration changed the web replica count.
- A repeated plan reported no changes.
- Scaling manually with kubectl caused drift that OpenTofu detected.
- The test ticket survived a database restart because storage persisted.

## Tear down
Run tofu destroy.
This deletes the database volume and its saved tickets.
Leave the stack running for the next lab.

## Known limitation
terraform.tfstate contains secrets in plain text.
The variable and state files are gitignored, not encrypted.
