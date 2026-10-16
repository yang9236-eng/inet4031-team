# Week 6 GitHub Actions and Observability

## What this does
- A GitHub Actions workflow checks formatting and validates OpenTofu configuration when a pull request changes week-5/ or the workflow itself.
- Prometheus monitors the local k3s cluster.
- pq.sh sends PromQL queries to Prometheus.

## Requirements
- Helm
- The Week 5 stack running on k3s
- GitHub CLI authenticated with the workflow scope

## Install Prometheus
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/prometheus \
  --version 29.35.0 \
  --namespace monitoring \
  --create-namespace \
  --values week-6/prometheus-values.yaml
```

## Query Prometheus
Run the port-forward in its own terminal:
```bash
kubectl port-forward --namespace monitoring service/prometheus-server 9090:80
```

From the repository root in another terminal:
```bash
./week-6/pq.sh 'up'
```

## Remove Prometheus
```bash
helm uninstall prometheus --namespace monitoring
```

## Known limitations
Metrics use temporary storage, so history is lost when the Prometheus pod is replaced.
Prometheus has no login. Keep the port-forward bound to the VM's loopback address.
