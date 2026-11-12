pipeline {
  agent {
    kubernetes {
      cloud 'local-k8s'
      yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: helm
      image: alpine/helm:3.16.4
      command: ['/bin/sh', '-c']
      args: ['sleep 3600']
    - name: python
      image: python:3.12-alpine
      command: ['/bin/sh', '-c']
      args: ['sleep 3600']
    - name: kubeconform
      image: ghcr.io/yannh/kubeconform:v0.6.7-alpine
      command: ['/bin/sh', '-c']
      args: ['sleep 3600']
    - name: gitleaks
      image: ghcr.io/gitleaks/gitleaks:v8.30.1
      command: ['/bin/sh', '-c']
      args: ['sleep 3600']
'''
    }
  }

  options {
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  stages {
    stage('Secret Scan') {
      steps {
        container('gitleaks') {
          sh 'gitleaks dir . --redact --no-banner --exit-code 1'
        }
      }
    }

    stage('Lint & Render App Helm Chart') {
      steps {
        container('helm') {
          sh '''
            set -eu
            mkdir -p rendered
            for env in staging prod; do
              echo "=== Validating helm/ for ${env} ==="
              helm lint ./helm -f ./helm/values.yaml -f "./helm/values-${env}.yaml"
              helm template "project-desk-${env}" ./helm -n "projectdesk-${env}" -f ./helm/values.yaml -f "./helm/values-${env}.yaml" > "rendered/app-${env}.yaml"
            done
          '''
        }
      }
    }

    stage('Lint & Render E2E Helm Chart') {
      steps {
        container('helm') {
          sh '''
            set -eu
            for env in staging prod; do
              echo "=== Validating e2e/chart/ for ${env} ==="
              helm lint ./e2e/chart -f ./e2e/chart/values.yaml -f "./e2e/chart/values-${env}.yaml"
              helm template "project-desk-e2e-${env}" ./e2e/chart -f ./e2e/chart/values.yaml -f "./e2e/chart/values-${env}.yaml" > "rendered/e2e-${env}.yaml"
            done
          '''
        }
      }
    }

    stage('Validate ArgoCD & Platform Infra YAML') {
      steps {
        container('python') {
          sh '''
            set -eu
            pip install --quiet pyyaml==6.0.2
            python3 - <<'EOF'
import pathlib, sys, yaml

dirs = ["argocd", "argocd-applications", "platform-infra"]
errors = 0
for d in dirs:
    for path in sorted(pathlib.Path(d).rglob("*.y*ml")):
        try:
            with path.open("r", encoding="utf-8") as f:
                list(yaml.safe_load_all(f))
            print(f"OK: {path}")
        except Exception as exc:
            print(f"ERROR: {path}: {exc}", file=sys.stderr)
            errors += 1
if errors:
    sys.exit(1)
EOF
          '''
        }
      }
    }

    stage('Kubernetes Schema Validation') {
      steps {
        container('kubeconform') {
          // argocd-cm-patch.yaml is a `kubectl patch` fragment, not a manifest.
          sh '''
            set -eu
            /kubeconform -strict -summary \
              -schema-location default \
              -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
              rendered/*.yaml \
              $(find argocd argocd-applications platform-infra -name '*.y*ml' ! -name 'argocd-cm-patch.yaml')
          '''
        }
      }
    }
  }
}
