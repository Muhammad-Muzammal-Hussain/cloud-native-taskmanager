# Defense — Likely Questions & Strong Answers

Practise saying these out loud. The examiner will probe *why*, not *what*.

### Architecture & cloud-native

**Q: What makes this "cloud-native" rather than just "an app on a server"?**
It's containerized, stateless at the app tier, horizontally scalable, declaratively deployed, and self-healing. Kubernetes restarts failed pods, reschedules them across nodes, and rolls out new versions without downtime. Infrastructure and deployment are both code, so the whole system is reproducible from an empty subscription.

**Q: Walk me through what happens when a user clicks "Add task".**
The browser sends `POST /api/tasks` to the ingress public IP. ingress-nginx matches the `/api` path and forwards to the `api` Service, which load-balances to one of the two API pods. The pod validates the title, runs a parameterized `INSERT` against PostgreSQL via the connection pool, and returns the new row as JSON. The UI re-fetches the list.

**Q: Why two replicas of the API?**
Availability and load spreading. If one pod dies or a node drains, the Service keeps routing to the healthy one, and rolling updates never drop to zero capacity.

### Kubernetes

**Q: Difference between a Deployment and a StatefulSet, and why did you use each?**
A Deployment manages interchangeable, stateless replicas — perfect for the API and web tiers. A StatefulSet gives pods stable identity and stable storage via `volumeClaimTemplates`; I used it for PostgreSQL so its data volume follows it and survives rescheduling.

**Q: How does the data survive a pod restart?**
The StatefulSet's PVC binds to an Azure managed disk through the default `managed-csi` storage class. The disk is independent of the pod lifecycle, so deleting the pod and letting Kubernetes recreate it re-mounts the same disk with the same data.

**Q: ConfigMap vs Secret?**
Both inject configuration as env vars, but Secrets are meant for sensitive values (base64-encoded at rest, can be RBAC-restricted and encrypted). Non-sensitive settings (DB host/port/name) go in the ConfigMap; the DB password goes in the Secret.

**Q: What do the liveness and readiness probes do here?**
Liveness (`/api/healthz`) tells Kubernetes the process is alive; if it hangs, the pod is restarted. Readiness (`/api/readyz`) checks the DB is reachable; until it passes, the pod is kept out of the Service's endpoints so users never hit a pod that can't serve.

**Q: How does Ingress differ from a LoadBalancer Service?**
A LoadBalancer Service provisions one Azure public IP per service. Ingress is a single entry point with an HTTP router in front of many services — one IP, path/host routing, and a place to terminate TLS. Cheaper and more realistic.

### Azure & IaC

**Q: Why OpenTofu instead of clicking in the portal?**
Reproducibility, version control, and review. `tofu plan` shows the diff before anything changes, `tofu apply` is idempotent, and `tofu destroy` cleans up exactly what was created. The portal is manual and error-prone.

**Q: How does the cluster pull from a private registry without a password?**
The OpenTofu `azurerm_role_assignment` grants the AKS kubelet's managed identity the `AcrPull` role on the ACR. AKS authenticates to ACR with that identity — no registry secret stored in the cluster.

**Q: How is monitoring set up?**
The AKS `oms_agent` add-on streams container metrics and logs to a Log Analytics workspace (Container Insights). In the portal I can see per-pod CPU/memory, container logs, and run KQL queries — this is the lab 10 material applied to the running app.

### CI/CD

**Q: Describe the pipeline.**
On every push to `main`, GitHub Actions logs into Azure with a service principal, runs `az acr build` to build both images server-side in ACR (tagged with the commit SHA), sets the AKS context, substitutes the image tag into the manifests, applies them, and waits for the rollout to complete. So a commit becomes a live deployment automatically.

**Q: How would you roll back a bad deploy?**
`kubectl rollout undo deployment/api -n taskapp` reverts to the previous ReplicaSet. Because each build is tagged by commit SHA, I can also redeploy any specific known-good image.

### Security & cost

**Q: What are the weak points security-wise, and how would you harden them?**
The DB Secret is a plain Kubernetes Secret and there's no TLS on the public endpoint. In production I'd move secrets to Azure Key Vault (Secrets Store CSI driver), add cert-manager + a DNS name for HTTPS, enable network policies, and use a managed PostgreSQL with private networking.

**Q: What does this cost and how do you avoid waste?**
One small B-series node, Basic ACR, and a tiny Log Analytics workspace — a few dollars a day, inside the student credit. Everything is in one resource group, so `tofu destroy` removes all billing in one step. I tear it down right after the demo.

### Trap questions

**Q: Why not just use Azure Database for PostgreSQL?**
For production I would — managed backups, HA, patching. I ran it in-cluster deliberately to demonstrate Kubernetes statefulness (StatefulSet + PVC). It's a conscious trade-off, not an oversight.

**Q: If the node dies, what happens to the data?**
With a single node and a single managed disk, the disk persists but the workload is unavailable until a node is back. True HA needs multiple nodes and replicated/managed storage — I'd note that as the next step.
