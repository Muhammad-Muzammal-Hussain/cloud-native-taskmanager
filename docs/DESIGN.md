# Cloud-Native Task Manager — Design Document

**Author:** Muhammad Muzammal Hussain
**Course:** DevOps in Azure (Spring 2026)
**Deliverable:** Design and deploy a cloud-native solution + defense

---

## 1. Overview

The Task Manager is a small but complete **three-tier, cloud-native application**:

| Tier | Technology | Role |
|------|-----------|------|
| Presentation | Static SPA served by **nginx** | Browser UI for adding/completing/deleting tasks |
| Application | **Node.js / Express REST API** | Business logic + CRUD over HTTP/JSON |
| Data | **PostgreSQL 16** | Persistent storage of tasks |

It is containerized with Docker, orchestrated by Kubernetes on **Azure Kubernetes Service (AKS)**, provisioned entirely with **OpenTofu** (Infrastructure as Code), built and deployed by a **GitHub Actions** pipeline, and observed through **Azure Monitor / Container Insights**.

The goal was not a large application but a small one that exercises *every* major topic in the course end to end.

## 2. Architecture

```
                            Internet
                                │
                                ▼
                   ┌────────────────────────┐
                   │  ingress-nginx (LB IP)  │   ← single Azure public IP
                   └───────────┬─────────────┘
                  /            │            /api
            ┌─────▼─────┐            ┌──────▼──────┐
            │ web (x2)  │            │  api (x2)   │  Deployments
            │  nginx    │            │  Express    │
            └───────────┘            └──────┬──────┘
                                            │ ClusterIP
                                     ┌──────▼──────┐
                                     │  postgres   │  StatefulSet
                                     │  (1 pod)    │
                                     └──────┬──────┘
                                            │
                                   ┌────────▼────────┐
                                   │  PVC → Azure     │  managed disk
                                   │  managed disk    │  (survives pod restarts)
                                   └──────────────────┘

   Surrounding platform:
   • Azure Container Registry (ACR)  → stores taskapi / taskweb images
   • Log Analytics + Container Insights → metrics & logs from all pods
   • Provisioned by OpenTofu; deployed by GitHub Actions
```

All workloads live in the `taskapp` namespace.

## 3. Mapping to the course syllabus

| Course topic (lab) | Where it appears in this project |
|--------------------|----------------------------------|
| Azure basics, Resource Groups, CLI (01–02) | Single RG holds all resources; `az` used throughout |
| Docker, image build & registry (04, 06) | `app/api` and `app/web` Dockerfiles; images pushed to ACR |
| Kubernetes core objects (05, 07) | Deployments, Services, ConfigMap, Secret, **Ingress**, **PVC**, StatefulSet, probes, scaling |
| AKS — managed Kubernetes (08) | Cluster created via OpenTofu; app runs on it |
| Azure Storage (09) | PostgreSQL state persisted on an **Azure managed disk** via PVC |
| Monitoring (10) | **Container Insights** ships metrics/logs to Log Analytics |
| OpenTofu / IaC (11) | `infra/` provisions RG + ACR + AKS + Log Analytics |
| GitHub Actions CI/CD (12) | `.github/workflows/cicd.yaml` builds in ACR and deploys to AKS |

## 4. Key design decisions (and why)

- **AKS over App Service.** App Service hosts a single container well but hides the orchestration layer. AKS lets the project demonstrate the Kubernetes half of the syllabus (scheduling, services, ingress, persistent volumes, scaling, rolling updates). It is the better fit for a *cloud-native* brief.
- **PostgreSQL in-cluster (StatefulSet + PVC) instead of Azure Database for PostgreSQL.** The in-cluster approach directly demonstrates Kubernetes statefulness (the PVC binds to an Azure managed disk and survives pod rescheduling). In production I would move to Azure Database for PostgreSQL Flexible Server for managed backups, HA, and patching — this is a deliberate trade-off, noted for the defense.
- **ACR over Docker Hub / GHCR.** ACR is private, lives in the same resource group, and is attached to AKS via an `AcrPull` role assignment expressed as IaC — so the cluster pulls images with its managed identity and no stored registry password.
- **ConfigMap + Secret separation.** Non-sensitive config (DB host, port, name) sits in a ConfigMap; credentials sit in a Secret and are injected as environment variables. This is the lab 07 configuration pattern.
- **Ingress over per-service LoadBalancers.** One ingress controller = one public IP for the whole app, with path-based routing (`/` → web, `/api` → API). Cheaper and closer to real deployments than giving each service its own public IP.
- **Health and readiness probes.** Liveness restarts a hung API pod; readiness keeps traffic away until PostgreSQL is reachable. The API also retries the DB connection on startup so pod start order doesn't matter.

## 5. Security considerations

- Images run as a **non-root user** (API Dockerfile creates and switches to `app`).
- Database credentials are **not** baked into images or manifests-with-values; they live in a Secret (and would move to Azure Key Vault via the Secrets Store CSI driver in production).
- ACR is **private**, `admin_enabled = false`; pulls use the cluster's managed identity, not a shared password.
- The GitHub→Azure connection uses a **scoped service principal** stored as the `AZURE_CREDENTIALS` GitHub secret.
- `https_only` / TLS would be added via cert-manager + a DNS name for a real deployment (out of scope for the timed demo).

## 6. Scaling & availability

- `api` and `web` run **2 replicas** each; `kubectl scale` or a HorizontalPodAutoscaler can raise this.
- Rolling updates: a new image tag triggers a zero-downtime rollout (`kubectl rollout`), with rollback via `kubectl rollout undo`.
- For real HA the node pool would grow past one node and PostgreSQL would move to a managed, replicated service.

## 7. Cost & lifecycle

- One `Standard_B2ms` node + a Basic ACR + a small Log Analytics workspace is comfortably inside the Azure-for-Students $100 credit for a day of work.
- **The cluster bills while it runs.** Everything is in one resource group, so teardown is a single `tofu destroy` (or delete the resource group). See the README for exact commands. Always tear down immediately after the defense.

## 8. Possible extensions

HorizontalPodAutoscaler, TLS via cert-manager, Azure Key Vault secrets, blue/green deploys, Prometheus/Grafana, and moving PostgreSQL to a managed Azure service.
