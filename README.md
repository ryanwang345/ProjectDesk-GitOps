# ProjectDesk-GitOps

Dedicated GitOps deployment configuration repository for **ProjectDesk**, modeled after enterprise Kubernetes & GitOps standards (inspired by `deployment-configuration` and `web2/.jenkins`).

---

## 🏗 System Architecture

```text
+-----------------------------------------------------------------------------------+
| 1. Developer pushes to ProjectDesk (Monorepo)                                     |
|    - apps/web (React 19 + Vite)                                                   |
|    - apps/api (Go 1.22 REST Backend)                                              |
|    - apps/e2e (Cypress Test Suite)                                                |
|    - .jenkins/monorepo-build-pipeline (Modular Declarative CI)                    |
+-----------------------------------------------------------------------------------+
                                        |
                                        v
+-----------------------------------------------------------------------------------+
| 2. Jenkins Controller (Managed by JCasC in ProjectDesk-GitOps)                    |
|    - Change Detection: Inspects git diff to identify changed components          |
|    - Parallel Workspaces: Validates & tests only affected components              |
|    - Rootless BuildKit: Builds and pushes immutable tags to Docker Hub            |
|      (rwang345/project-desk-web:<tag>, rwang345/project-desk-api:<tag>)           |
|    - Post-Build Release Trigger: Automatically invokes ProjectDesk-Deploy          |
+-----------------------------------------------------------------------------------+
                                        |
                                        v
+-----------------------------------------------------------------------------------+
| 3. ProjectDesk-GitOps Repository (This Repository)                                |
|    - Updates target values (helm/values-<env>.yaml, web/argo/values/, etc.)       |
|    - Git Commit: "release(<env>): update <component> image tag to <tag>"          |
+-----------------------------------------------------------------------------------+
                                        |
                                        v
+-----------------------------------------------------------------------------------+
| 4. ArgoCD (Continuous Delivery)                                                   |
|    - Detects commit in ProjectDesk-GitOps repository                              |
|    - App-of-Apps (bootstrap.yaml) reconciles target environment applications      |
|    - Performs zero-downtime rolling update across Kubernetes pods                 |
+-----------------------------------------------------------------------------------+
```

---

## 📁 Repository Directory Structure

```text
.
├── argocd-applications/          # ArgoCD Applications (App-of-Apps pattern)
│   ├── bootstrap.yaml            # Master App-of-Apps tracking all environments
│   ├── dev/
│   │   ├── project-desk-dev.yaml     # Dev cluster application (namespace: projectdesk-dev)
│   │   └── project-desk-e2e-dev.yaml # Dev Cypress E2E CronJob application
│   ├── staging/
│   │   └── project-desk-staging.yaml # Staging application (namespace: projectdesk-staging)
│   └── prod/
│       └── project-desk-prod.yaml    # Production application (namespace: projectdesk-prod)
├── argocd/                       # Base ArgoCD infrastructure manifests
│   ├── application.yaml          # Default application manifest
│   ├── jenkins.yaml              # Jenkins controller Helm release + JCasC JobDSL
│   ├── argocd-ingress.yaml       # Ingress for ArgoCD dashboard
│   ├── ingress-nginx.yaml        # NGINX Ingress controller
│   └── cloudflare-tunnel.yaml    # External secure ingress tunnel
├── helm/                         # Core ProjectDesk Helm Chart
│   ├── Chart.yaml                # Chart definition
│   ├── templates/                # Kubernetes resource templates (web, api, postgres, etc.)
│   ├── values.yaml               # Base / default values
│   ├── values-dev.yaml           # Dev environment overrides (replicas: 1, dev ingress)
│   ├── values-staging.yaml       # Staging environment overrides (replicas: 2, staging ingress)
│   └── values-prod.yaml          # Prod environment overrides (replicas: 3, HA, prod ingress)
├── web/argo/values/              # Component-specific values (modeled after deployment-configuration)
│   ├── dev.yaml
│   ├── staging.yaml
│   └── prod.yaml
├── api/argo/values/              # Component-specific values (modeled after deployment-configuration)
│   ├── dev.yaml
│   ├── staging.yaml
│   └── prod.yaml
└── scripts/                      # GitOps verification and automation tooling
    ├── verify-images.sh          # Validates that all container tags exist in the registry
    └── update-image-tag.sh       # Automated CLI tool to update image tags across values files
```

---

## 🚀 Jenkins CI/CD Pipelines

Configured via Jenkins Configuration as Code (`argocd/jenkins.yaml`):

| Pipeline Job Name | Jenkinsfile Location | Description |
| :--- | :--- | :--- |
| **`ProjectDesk-Monorepo`** | `.jenkins/monorepo-build-pipeline/Jenkinsfile` | Multibranch pipeline: component change detection, workspace parallel builds, Docker Hub publishing, and auto-deploy trigger. |
| **`ProjectDesk-Deploy`** | `.jenkins/deployment-pipeline/Jenkinsfile` | Release pipeline: parameterized GitOps release updating target values in `ProjectDesk-GitOps`. |
| **`ProjectDesk-E2E-Tests`** | `.jenkins/e2e-tests-pipeline/Jenkinsfile` | Standalone Cypress integration suite runner against `dev`, `staging`, or `prod`. |
| **`ProjectDesk-Package-Audit`** | `.jenkins/package-audit-pipeline/Jenkinsfile` | Scheduled monthly security audit for npm dependencies and Go modules. |

---

## 🛠 Automation & Tooling Scripts

### 1. Image Registry Verification
Before merging or syncing, run `verify-images.sh` to confirm that all container images referenced across environment values files actually exist in Docker Hub:

```bash
./scripts/verify-images.sh
```

### 2. Updating Image Tags Manually or via CLI
To bump an image tag across environment values files:

```bash
# Update web and api image tags in dev
./scripts/update-image-tag.sh web+api 89 dev

# Update web only in staging
./scripts/update-image-tag.sh web 90 staging

# Update api only in prod
./scripts/update-image-tag.sh api 90 prod
```

---

## 🔄 Environment Promotion Lifecycle

1. **Development (`dev`)**:
   - Auto-deployed on every commit to `main` in `ProjectDesk`.
   - Accessible at `desk-dev.ryanwang.dev` / `desk-dev.k8s.local`.
   - E2E tests run automatically in the dev cluster.
2. **Staging (`staging`)**:
   - Triggered via `ProjectDesk-Deploy` with `TARGET_ENV=staging`.
   - Scaled to 2 replicas, strict TLS with Let's Encrypt / Vault.
   - Accessible at `desk-staging.ryanwang.dev`.
3. **Production (`prod`)**:
   - Triggered via `ProjectDesk-Deploy` with `TARGET_ENV=prod`.
   - Scaled to 3 replicas with High Availability (HA) and automated Postgres backup cronjobs.
   - Accessible at `ryanwang.dev` / `www.ryanwang.dev`.
