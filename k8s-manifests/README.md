# 📁 Kubernetes Manifests

## 🏗️ Organization

This structure organizes Kubernetes manifests by environment to facilitate migration and management.

```
k8s-manifests/
├── keltio-prod/          # Source K8s cluster manifests (Keltio production)
├── k3s-target/           # Adapted manifests for target K3s cluster
├── shared/               # Common manifests usable on both clusters
└── README.md             # This file
```

## 📋 Usage

### 1. Export from source cluster
```bash
# Automatic export to keltio-prod/
./k8s-to-k3s-migration/scripts/export-manifests-and-secrets.sh full
```

### 2. Import from K3s VM
```bash
# Retrieve manifests from K3s VM
./k8s-to-k3s-migration/scripts/get-k3s-manifests.sh
```

### 3. Manual migration
```bash
# Copy and adapt from keltio-prod/ to k3s-target/
cp k8s-manifests/keltio-prod/app.yaml k8s-manifests/k3s-target/
# Then edit to adapt for K3s
```

## 🎯 Conventions

- **keltio-prod/** : Original manifests, unmodified
- **k3s-target/** : Adapted manifests (StorageClass, Ingress, etc.)
- **shared/** : Generic manifests usable everywhere

## 🔧 Automation

Migration scripts automatically use this structure:
- Export → `keltio-prod/`
- Import → `k3s-target/`
- Validation → Compare both
