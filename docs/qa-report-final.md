| Test | What counts as passing | Status |
|---|---|---|
| Autoscaling | At **55 requests/sec or higher**, the HPA automatically scales `web` from one replica to at least two. Save the k6 summary and HPA history. | Pending |
| Pod deletion and rollout | During one k6 run lasting at least three minutes, delete one web pod and roll out a new web image through the Deploy gate. Record the deletion and rollout times. Fewer than **1%** of requests fail. | Pending |
| PodDisruptionBudget | Save `kubectl get pdb` and `kubectl describe pdb` at the starting and scaled replica counts. Explain what the budget protects against on your single-node VM. | Pending |
| NetworkPolicy | Run one allowed connection test and one denied connection test before and after the policy change. Save the results. | Pending |
| Memory budget | Confirm that extra configured memory limits stay **under 768 MiB**, `web` is capped at **four replicas or fewer**, and `db` stays at one replica. | Pending |
