# 🔗 Shared Manifests

## 📋 Description

This folder contains **generic** Kubernetes manifests that can be used on both clusters without modification.

## 📦 Content Types

### ConfigMaps
- Application configurations
- Non-sensitive environment variables
- Common settings

### Secrets Templates
- Base64 templates (without actual values)
- Secret structure definitions
- Environment-agnostic secret manifests

### RBAC
- ServiceAccounts
- Roles and ClusterRoles
- RoleBindings (environment-independent)

### Network Policies
- Generic security policies
- Common traffic rules
- Namespace isolation rules

## 🔄 Usage

```bash
# Apply to any cluster
kubectl apply -f k8s-manifests/shared/

# Copy to environment-specific folder
cp k8s-manifests/shared/rbac.yaml k8s-manifests/k3s-target/
```

## 📁 Organization

```
shared/
├── configmaps/             # Application configs
├── secrets-templates/      # Secret structure templates
├── rbac/                   # Roles and bindings
├── network-policies/       # Security policies
└── common/                 # Other generic resources
```

## ✅ Guidelines

**Include here:**
- Environment-agnostic manifests
- Templates and examples
- Common configurations

**Don't include:**
- Environment-specific values
- Hardcoded hostnames/IPs
- Sensitive data
