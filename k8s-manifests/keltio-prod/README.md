# 🏭 Keltio Production Manifests

## 📋 Description

This folder contains the **original** Kubernetes manifests exported from the Keltio production cluster.

## 🔄 Automatic Import

Manifests are automatically imported via:

```bash
./k8s-to-k3s-migration/scripts/export-manifests-and-secrets.sh full
```

## 📁 Typical Organization

```
keltio-prod/
├── namespaces/              # Namespace definitions
├── vaultwarden/            # Password manager
├── monitoring/             # Prometheus, Grafana, Loki
├── ops/                    # PgAdmin, ops tools
├── gitlab-runner/          # CI/CD
├── hubspot-manager/        # Business CronJobs
├── reloader/               # Config watcher
├── keda/                   # Autoscaler
└── secrets/                # Secrets (base64 encoded)
```

## ⚠️ Important

- **DO NOT MODIFY** these files directly
- They are overwritten on each export
- For modifications, copy to `../k3s-target/`

## 🔐 Security

- Secrets are exported in base64
- No sensitive data in plain text
- Use `.gitignore` if necessary
