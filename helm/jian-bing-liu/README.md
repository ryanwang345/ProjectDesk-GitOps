# Jian Bing Liu (`jianbingliu.uk`) — GitOps Deployment

Helm chart and environment overrides for the [jian-bing-liu](https://github.com/ryanwang345/jian-bing-liu) Next.js website.

## Environments

| Environment | Namespace | Hostname(s) | Values File |
| :--- | :--- | :--- | :--- |
| Staging | `jian-bing-liu-staging` | `staging.jianbingliu.uk`, `jianbingliu-staging.k8s.local` | `values-staging.yaml` |
| Production | `jian-bing-liu-prod` | `jianbingliu.uk`, `www.jianbingliu.uk` | `values-prod.yaml` |

## Updating Image Tags

```bash
./scripts/update-jian-bing-liu-tag.sh <BUILD_NUMBER> staging
./scripts/update-jian-bing-liu-tag.sh <BUILD_NUMBER> prod
```

Commit and push to `main`; ArgoCD reconciles automatically.

## Cloudflare Zero Trust Tunnel Routing

Because `argocd/cloudflare-tunnel.yaml` uses a remotely managed tunnel token (`--token $(TUNNEL_TOKEN)`), add these **Public Hostnames** in **Cloudflare Zero Trust Dashboard → Networks → Tunnels → Public Hostnames**:

| Public Hostname | Service | HTTP Host Header |
| :--- | :--- | :--- |
| `jianbingliu.uk` | `http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80` | `jianbingliu.uk` |
| `www.jianbingliu.uk` | `http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80` | `www.jianbingliu.uk` |
| `staging.jianbingliu.uk` | `http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80` | `staging.jianbingliu.uk` |

Enable **Always Use HTTPS** in Cloudflare SSL/TLS; the Helm Ingress sets `nginx.ingress.kubernetes.io/ssl-redirect: "false"` so TLS terminates cleanly at Cloudflare without redirect loops.
