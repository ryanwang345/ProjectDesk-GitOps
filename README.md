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
|    - Updates target values (helm/values-<env>.yaml)                               |
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
├── argocd-applications/          # Applied by bootstrap.yaml (App-of-Apps pattern)
│   ├── bootstrap.yaml            # Root Application for ProjectDesk environments
│   ├── bootstrap-infra.yaml      # Root Application for platform-infra/
│   ├── projects/projects.yaml    # AppProjects: "projectdesk" and "platform"
│   ├── staging/
│   │   └── project-desk-staging.yaml # Staging application (namespace: projectdesk-staging)
│   └── prod/
│       └── project-desk-prod.yaml    # Production application (namespace: projectdesk-prod)
├── argocd/                       # Cluster base manifests, applied by hand
│   ├── argocd-ingress.yaml       # Ingress for ArgoCD dashboard
│   ├── ingress-nginx.yaml        # NGINX Ingress controller
│   ├── cloudflare-tunnel.yaml    # External secure ingress tunnel
│   └── pod-auto-healer.yaml      # Cleans up pods left on NotReady nodes
├── platform-infra/               # Applied by bootstrap-infra.yaml
│   ├── vault.yaml, external-secrets.yaml, vault-*-sync.yaml
│   ├── keycloak.yaml, oauth2-proxy.yaml, headlamp.yaml
│   └── jenkins.yaml              # Jenkins controller Helm release + JCasC JobDSL
├── helm/                         # Core ProjectDesk Helm Chart
│   ├── Chart.yaml                # Chart definition
│   ├── templates/                # web, api, postgres, backups, PDBs, NetworkPolicies, ExternalSecrets
│   ├── values.yaml               # Base / default values
│   ├── values-staging.yaml       # Staging environment overrides (replicas: 2, staging ingress)
│   └── values-prod.yaml          # Prod environment overrides (3 app replicas, prod ingress)
├── e2e/chart/                    # Cypress E2E CronJob chart
└── scripts/                      # GitOps verification and automation tooling
    ├── verify-images.sh          # Validates that all container tags exist in the registry
    └── update-image-tag.sh       # Updates image tags in helm/values-<env>.yaml
```

---

## 🚀 Jenkins CI/CD Pipelines

Configured via Jenkins Configuration as Code (`platform-infra/jenkins.yaml`):

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
To bump an image tag in an environment's values file:

```bash
# Update web and api image tags in staging
./scripts/update-image-tag.sh web+api 89 staging

# Update web only in staging
./scripts/update-image-tag.sh web 90 staging

# Update api only in prod
./scripts/update-image-tag.sh api 90 prod
```

---

## 🔄 Environment Promotion Lifecycle

1. **Staging (`staging`)**:
   - Triggered via `ProjectDesk-Deploy` with `TARGET_ENV=staging`.
   - Web and API are configured for 2 replicas; verify TLS behavior at the ingress and tunnel.
   - Accessible at `desk-staging.ryanwang.dev`.
2. **Production (`prod`)**:
   - Triggered via `ProjectDesk-Deploy` with `TARGET_ENV=prod`.
   - Web and API use 3 replicas; Postgres remains a single instance with a backup CronJob.
   - Accessible at `ryanwang.dev` / `www.ryanwang.dev`.

## Database credentials

Staging and prod read Postgres credentials from Vault through External
Secrets Operator (`postgres.externalSecret` in `helm/values-<env>.yaml`).
The ExternalSecret writes the `project-desk-postgres` Secret, the same name
the chart used before, with `POSTGRES_USER`, `POSTGRES_PASSWORD`,
`POSTGRES_DB` and `DATABASE_URL`.

Before syncing this change, store the credentials the database already uses
(otherwise the API can no longer log in):

```bash
vault kv put secret/projectdesk/staging/postgres username=projectdesk password=<current password>
vault kv put secret/projectdesk/prod/postgres    username=projectdesk password=<current password>
```

The Vault role `external-secrets` must be allowed to read
`secret/data/projectdesk/*`. To rotate the password afterwards, run
`ALTER USER ... PASSWORD` in Postgres first, then update Vault; changing the
Secret alone does not change the database user's password.

`postgres.existingSecret` still takes precedence over both, and the chart only
renders its own Secret from `postgres.password` when neither is set. That
value has no default, so a render without credentials fails instead of
falling back to a known password.

The AI provider keys can come from Vault the same way through
`api.ai.externalSecret` (properties `secret-key` and, with `syncAdminToken`,
`admin-token`).

Backups are stored on a cluster PVC; periodically test restoration and keep
an off-cluster copy.

## Security defaults

- Applications run in the `projectdesk` and `platform` AppProjects, which
  limit source repositories and destination namespaces.
- Helm chart versions and infrastructure images are pinned to exact versions.
- api, web, backup and migration pods run with `seccompProfile: RuntimeDefault`,
  no privilege escalation and dropped capabilities; api runs as UID 1000.
- NetworkPolicies allow Postgres traffic only from the api, migration and
  backup pods, and api traffic only from web.
- HTTPS is enforced at Cloudflare ("Always Use HTTPS"): TLS terminates there
  and cloudflared reaches ingress-nginx over HTTP, so an nginx redirect would loop.
- CI (`Jenkinsfile`) runs gitleaks, `helm lint`, and kubeconform against the
  rendered charts and every manifest.
