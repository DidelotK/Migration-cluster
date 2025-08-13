# 🏗️ Architecture de la Migration

## Vue d'ensemble

La solution de migration K8s → K3s est conçue comme un système modulaire et automatisé comprenant :

- **Infrastructure as Code** (Terraform + Ansible)
- **Scripts d'automation** modulaires et réutilisables
- **Gestion sécurisée** des secrets et credentials
- **Migration de données** avec préservation des permissions

## 📐 Architecture Technique

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLUSTER K8S SOURCE                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐              │
│  │ Vaultwarden │ │ Monitoring  │ │   PgAdmin   │ ...          │
│  │   + Data    │ │   + Data    │ │    + Data   │              │
│  └─────────────┘ └─────────────┘ └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
                                │
                                │ Export
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                   SCRIPTS MIGRATION                            │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐  │
│  │ export-manifests│ │  setup-secrets  │ │ complete-migration│ │
│  │   -and-secrets  │ │                 │ │                  │  │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                │ Deploy + Import
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                  CLUSTER K3S CIBLE                             │
│ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
│ │   Scaleway VM   │ │   K3s Cluster   │ │   Applications  │   │
│ │                 │ │                 │ │                 │   │
│ │ • Ubuntu 22.04  │ │ • Ingress Nginx │ │ • Vaultwarden   │   │
│ │ • 4 vCPU        │ │ • Cert Manager  │ │ • Monitoring    │   │
│ │ • 8GB RAM       │ │ • External DNS  │ │ • PgAdmin       │   │
│ │ • 80GB SSD      │ │ • Local Storage │ │ • GitLab Runner │   │
│ └─────────────────┘ └─────────────────┘ └─────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 Composants Principaux

### 1. Infrastructure (Terraform + Ansible)

**Terraform Module VM** (`infrastructure/terraform/modules/vm/`)
- Création VM Scaleway GP1-XS
- Configuration réseau et sécurité
- Génération et gestion des clés SSH
- Intégration automatique avec Ansible

**Ansible Roles** (`infrastructure/ansible/roles/`)
- `k3s/` - Installation et configuration K3s
- `helm/` - Installation et configuration Helm
- `ingress-nginx/` - Déploiement Ingress Controller
- `cert-manager/` - Configuration SSL automatique
- `external-dns/` - Synchronisation DNS Scaleway

### 2. Scripts de Migration

**Export Script** (`scripts/export-manifests-and-secrets.sh`)
```bash
# Fonctionnalités
- Export sécurisé des manifests K8s
- Extraction et décodage des secrets
- Génération de manifests nettoyés pour K3s
- Documentation automatique des ressources
```

**Setup Secrets** (`scripts/setup-secrets.sh`)
```bash
# Fonctionnalités
- Configuration Docker Registry Scaleway
- Secrets External DNS
- Migration des secrets existants
- Validation automatique
```

**Migration Complète** (`scripts/complete-migration.sh`)
```bash
# Orchestration
1. Validation environnement
2. Déploiement infrastructure
3. Export depuis source
4. Configuration secrets
5. Déploiement applications
6. Migration données
7. Configuration réseau
8. Validation finale
```

### 3. Gestion des Données

**Migration Vaultwarden**
- Export SQLite database + fichiers associés
- Correction permissions (UID/GID 1000)
- Import via pods temporaires
- Validation intégrité

**Migration Monitoring**
- Export dashboards Grafana
- Préservation configuration Prometheus
- Migration logs Loki (optionnelle)
- Reconfiguration sources de données

## 🔐 Sécurité

### Gestion des Secrets

```
.envrc (direnv) → Variables d'environnement → Scripts → Kubernetes Secrets
```

**Niveaux de sécurité** :
1. **Filesystem** : `.envrc` non commité
2. **Runtime** : Variables d'environnement chiffrées
3. **Kubernetes** : Secrets base64 dans etcd
4. **Application** : Montage sécurisé dans pods

### Isolation

- **Namespaces** séparés par application
- **RBAC** configuré pour chaque service
- **Network Policies** (optionnel)
- **Pod Security Standards** (optionnel)

## 📊 Flux de Données

### Export Phase
```
K8s API → kubectl → YAML files → Parsing → Clean manifests
```

### Import Phase
```
Clean manifests → kubectl apply → K3s API → Pod creation
```

### Data Migration
```
Source PVC → Temp Pod → kubectl cp → Target PVC → Application Pod
```

## 🌐 Réseau et DNS

### Architecture Réseau
```
Internet → Cloudflare DNS → Scaleway VM IP → Ingress Nginx → Services → Pods
```

### SSL/TLS
```
Let's Encrypt → Cert Manager → TLS Secrets → Ingress → HTTPS
```

### DNS Automation
```
Ingress annotations → External DNS → Scaleway DNS API → DNS Records
```

## 🔄 Haute Disponibilité

### Limitations Actuelles
- **Single VM** : Point de défaillance unique
- **Local Storage** : Pas de réplication
- **No LoadBalancer** : Ingress sur une seule instance

### Améliorations Futures
- **Multi-node K3s** cluster
- **Shared Storage** (NFS, Longhorn)
- **LoadBalancer** externe (Scaleway LB)
- **Backup** automatisé (Velero)

## 📈 Monitoring et Observabilité

### Stack Monitoring
- **Prometheus** : Métriques système et applications
- **Grafana** : Dashboards et alerting
- **Loki** : Agrégation de logs
- **AlertManager** : Notifications

### Métriques Clés
- **Resource Usage** : CPU, RAM, Disk
- **Application Health** : Pod status, restarts
- **Network** : Ingress traffic, SSL certificates
- **Business** : Application-specific metrics

## 🚀 Évolutivité

### Ajout d'Applications
1. Ajouter namespace dans scripts export
2. Créer manifests dans `configs/manifests/`
3. Configurer secrets spécifiques
4. Mettre à jour DNS si nécessaire

### Scaling Horizontal
- Augmenter replicas dans manifests
- Configurer HPA (Horizontal Pod Autoscaler)
- Utiliser KEDA pour scaling avancé

### Scaling Vertical
- Ajuster resources requests/limits
- Utiliser VPA (Vertical Pod Autoscaler)
- Monitorer avec Prometheus

## 🔧 Maintenance

### Mises à Jour
- **K3s** : Upgrade automatique ou manuel
- **Applications** : Rolling updates
- **Certificates** : Renouvellement automatique Let's Encrypt

### Sauvegarde
- **Etcd** : Backup K3s automatique
- **Persistent Data** : Scripts personnalisés
- **Configuration** : Git repository

### Monitoring Santé
- **Health Checks** : Liveness/Readiness probes
- **Alerts** : Prometheus AlertManager
- **Logs** : Centralisés dans Loki

---

Cette architecture garantit une migration robuste, sécurisée et évolutive de votre infrastructure K8s vers K3s.
