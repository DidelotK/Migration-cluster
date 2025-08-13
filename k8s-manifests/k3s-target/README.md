# 🎯 K3s Target Manifests

## 📋 Description

This folder contains Kubernetes manifests **adapted** for deployment on the K3s target cluster.

## 🔧 Adaptations

Manifests here are modified versions from `../keltio-prod/` with K3s-specific adaptations:

### Common Changes:
- **StorageClass**: `local-path` instead of cloud provider storage
- **Ingress**: Updated annotations for ingress-nginx
- **Services**: NodePort or ClusterIP instead of LoadBalancer
- **Resources**: Adjusted for single-node K3s constraints

## 🔄 Import from K3s VM

Get current manifests from the running K3s cluster:

```bash
./k8s-to-k3s-migration/scripts/get-k3s-manifests.sh
```

## 📁 Organization

```
k3s-target/
├── namespaces/              # K3s namespace definitions
├── vaultwarden/            # Adapted password manager
├── monitoring/             # Lightweight monitoring stack
├── ops/                    # Operations tools
├── gitlab-runner/          # CI/CD runner
├── hubspot-manager/        # Business workflows
├── reloader/               # Config watcher
├── keda/                   # Autoscaler
└── applied/                # Currently deployed manifests
```

## 📝 Workflow

1. Copy from `../keltio-prod/`
2. Adapt for K3s environment
3. Test with `kubectl --dry-run=client`
4. Apply to K3s cluster
5. Backup applied version

## 🎯 K3s Specifics

- **Single Node**: No node affinity rules
- **Local Storage**: PVCs use `local-path`
- **Networking**: Host networking for ingress
- **Resources**: Conservative CPU/memory limits
