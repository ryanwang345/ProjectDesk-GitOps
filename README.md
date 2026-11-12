# ProjectDesk-GitOps

Dedicated GitOps deployment configuration repository for **ProjectDesk**.

## Architecture

- **Application Repository**: [`ProjectDesk`](https://github.com/ryanwang345/ProjectDesk) holds the application source code (`apps/web`, `apps/api`), Dockerfiles, and CI pipelines.
- **GitOps Repository**: [`ProjectDesk-GitOps`](https://github.com/ryanwang345/ProjectDesk-GitOps) holds the Helm charts, environment values, and ArgoCD manifests.

## Directory Structure

```text
.
├── helm/
│   ├── Chart.yaml
│   ├── values.yaml          # Current production deployment image tags & configuration
│   └── templates/
│       ├── ai-secret.yaml
│       ├── api.yaml
│       ├── ingress.yaml
│       ├── postgres.yaml
│       ├── postgres-backup.yaml
│       └── web.yaml
└── argocd/
    ├── application.yaml     # ArgoCD root application watching this repo
    ├── argocd-ingress.yaml
    ├── jenkins.yaml
    └── ...
```

## Deployment Flow

1. Developer merges code into `ProjectDesk` `main`.
2. Jenkins CI builds Docker images (`project-desk-web:<tag>`, `project-desk-api:<tag>`) and pushes them to Docker Hub.
3. The deployment job (`ProjectDesk-Deploy`) updates `helm/values.yaml` in this repository with the target image tag.
4. ArgoCD detects the commit in this repository and rolls out the update into Kubernetes.
