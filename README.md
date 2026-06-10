# Cloud-Native Task Manager

A three-tier (web + REST API + PostgreSQL) cloud-native app, deployed to **Azure Kubernetes Service** with **OpenTofu** IaC, **GitHub Actions** CI/CD, and **Container Insights** monitoring.

```
app/
  api/   Node.js + Express REST API (Dockerfile)
  web/   Static UI served by nginx (Dockerfile)
k8s/     Kubernetes manifests (namespace, secret, config, postgres, api, web, ingress)
infra/   OpenTofu: Resource Group + ACR + AKS + Log Analytics
.github/workflows/cicd.yaml   Build-in-ACR + deploy-to-AKS pipeline
docs/    DESIGN.md (submit this) + DEFENSE-QA.md (study this)
```

---

## Prerequisites (install once)

- Azure for Students account with credit
- `az` (Azure CLI), `kubectl`, `tofu` (OpenTofu — see lab 11), `git`
- `envsubst` (used in Phase 4). Preinstalled on GitHub runners; on Ubuntu install with `sudo apt-get install -y gettext-base`
- A GitHub account (for the CI/CD part)

```bash
az login                       # or use Cloud Shell
az account show -o table       # note your subscription id
```

---

## PHASE 0 — Authenticate OpenTofu (lab 11)

Create a service principal and export the ARM_* variables OpenTofu reads:

```bash
export SUBSCRIPTION_ID=$(az account show --query id -o tsv)
az ad sp create-for-rbac --name "taskapp-sp" --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID
```

From the JSON output, export:

```bash
export ARM_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
export ARM_TENANT_ID="<tenant>"
export ARM_CLIENT_ID="<appId>"
export ARM_CLIENT_SECRET="<password>"
```

> Keep this JSON — you reuse it for GitHub later (Phase 5).

---

## PHASE 1 — Provision infrastructure with OpenTofu

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # edit region if needed
tofu init
tofu plan          # review: RG + ACR + Log Analytics + AKS + role assignment
tofu apply          # type 'yes'  (~5–8 min)
```

Save the outputs:

```bash
tofu output
# note: acr_login_server, acr_name, resource_group_name, aks_cluster_name
```

---

## PHASE 2 — Connect kubectl to the cluster

```bash
az aks get-credentials \
  --resource-group $(tofu output -raw resource_group_name) \
  --name $(tofu output -raw aks_cluster_name)

kubectl get nodes          # should show 1 Ready node
```

---

## PHASE 3 — Install the ingress controller (lab 07)

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/cloud/deploy.yaml

# wait until it has an EXTERNAL-IP (takes ~1–2 min):
kubectl get svc -n ingress-nginx -w
```

---

## PHASE 4 — Deploy the app (manual first run)

> The CI/CD pipeline does this automatically later. Do it once by hand so you
> understand each step and have something live to demo even before CI/CD.

```bash
cd ..                                    # back to repo root
export ACR_LOGIN_SERVER=$(cd infra && tofu output -raw acr_login_server)
export ACR_NAME=$(cd infra && tofu output -raw acr_name)
export IMAGE_TAG=v1

# 1) Build both images directly inside ACR (no local Docker needed)
az acr build --registry $ACR_NAME --image taskapi:$IMAGE_TAG ./app/api
az acr build --registry $ACR_NAME --image taskweb:$IMAGE_TAG ./app/web

# 2) Apply static manifests
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-postgres-secret.yaml       # CHANGE the password first!
kubectl apply -f k8s/02-app-config.yaml
kubectl apply -f k8s/03-postgres-statefulset.yaml
kubectl apply -f k8s/06-ingress.yaml

# 3) Substitute image vars into the app deployments, then apply
envsubst < k8s/04-api.yaml | kubectl apply -f -
envsubst < k8s/05-web.yaml | kubectl apply -f -

# 4) Watch it come up
kubectl get pods -n taskapp -w
```

Get the public URL and open it:

```bash
kubectl get ingress -n taskapp
# or directly the controller IP:
kubectl get svc -n ingress-nginx
# open  http://<EXTERNAL-IP>/  in a browser
```

Quick API check:

```bash
IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$IP/api/healthz
curl -X POST http://$IP/api/tasks -H 'Content-Type: application/json' -d '{"title":"hello AKS"}'
curl http://$IP/api/tasks
```

---

## PHASE 5 — Wire up GitHub Actions CI/CD (lab 12)

1. Push this repo to GitHub (`git init && git add . && git commit && git push`).
2. In **Settings → Secrets and variables → Actions**:
   - **Secret** `AZURE_CREDENTIALS` — re-run the SP command with `--sdk-auth` and paste the JSON:
     ```bash
     az ad sp create-for-rbac --name "taskapp-gh" --role Contributor \
       --scopes /subscriptions/$SUBSCRIPTION_ID --sdk-auth
     ```
   - **Variables**: `ACR_NAME`, `ACR_LOGIN_SERVER`, `RESOURCE_GROUP`, `AKS_CLUSTER` (from `tofu output`).
3. Push any commit to `main` → the **Actions** tab shows build → deploy → rollout.

---

## PHASE 6 — Show monitoring (lab 10)

Azure Portal → your AKS cluster → **Monitoring → Insights**. Show per-pod CPU/memory,
container logs, and run a KQL query in **Logs**, e.g.:

```kusto
ContainerLogV2
| where PodNamespace == "taskapp"
| order by TimeGenerated desc
| take 50
```

---

## Useful demo commands (Kubernetes)

```bash
kubectl get all -n taskapp
kubectl scale deployment/api --replicas=3 -n taskapp     # live scaling
kubectl rollout history deployment/api -n taskapp
kubectl rollout undo deployment/api -n taskapp           # rollback
kubectl logs -n taskapp deploy/api
kubectl describe pod -n taskapp <pod>
```

---

## ⚠️ TEARDOWN — do this right after your defense

```bash
# remove the app + ingress (optional, destroy below covers the cluster anyway)
kubectl delete namespace taskapp
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/cloud/deploy.yaml

# destroy ALL Azure resources (stops billing)
cd infra && tofu destroy        # type 'yes'
```

If `tofu destroy` ever fails, delete the resource group in the portal — it removes everything inside it.
# demo Thu Jun 11 01:44:32 CEST 2026
# demo Thu Jun 11 01:48:10 CEST 2026
