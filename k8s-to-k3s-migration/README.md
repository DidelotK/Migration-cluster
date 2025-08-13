# 🚀 Migration K8s vers K3s - Automation Complète

Ce projet fournit une solution complète et automatisée pour migrer des applications d'un cluster Kubernetes vers un cluster K3s sur Scaleway.

## 📋 Vue d'ensemble

- **Migration automatisée** : Export, déploiement et configuration en une seule commande
- **Gestion des secrets** : Configuration automatique des credentials Scaleway et migration des secrets existants
- **Structure modulaire** : Scripts séparés pour chaque étape, utilisables indépendamment
- **Sécurité** : Gestion propre des données sensibles avec direnv
- **Documentation** : Guides détaillés et scripts de validation

## 🏗️ Structure du Projet

```
k8s-to-k3s-migration/
├── automation/
│   └── migrate.sh              # Script principal de migration
├── scripts/
│   ├── export-manifests-and-secrets.sh  # Export du cluster source
│   ├── setup-secrets.sh                 # Configuration des secrets K3s
│   └── complete-migration.sh            # Orchestration complète
├── exported-manifests/         # Manifests exportés (généré)
├── configs/                    # Configurations personnalisées
├── docs/                       # Documentation détaillée
└── README.md                   # Ce fichier
```

## 🛠️ Prérequis

### Outils Requis

```bash
# Outils essentiels
kubectl >= 1.20
helm >= 3.0
terraform >= 1.0
ansible >= 2.9
direnv >= 2.20

# Outils optionnels pour le parsing YAML
yq >= 4.0
jq >= 1.6
```

### Configuration de l'Environnement

1. **Configurer direnv** pour la gestion des variables d'environnement :

```bash
# Installer direnv
brew install direnv  # macOS
# ou apt install direnv  # Ubuntu

# Ajouter à votre shell (~/.zshrc ou ~/.bashrc)
eval "$(direnv hook zsh)"  # pour zsh
eval "$(direnv hook bash)" # pour bash
```

2. **Configurer les credentials Scaleway** dans `.envrc` :

```bash
# Copier l'exemple
cp .envrc.example .envrc

# Éditer avec vos vraies credentials
vim .envrc

# Activer l'environnement
direnv allow
```

3. **Préparer les kubeconfigs** :

```bash
# Kubeconfig du cluster source (K8s existant)
cp votre-kubeconfig.yaml kubeconfig-keltio-prod.yaml

# Le kubeconfig K3s sera généré automatiquement par l'infrastructure
```

## 🚀 Utilisation Rapide

### Migration Complète en Une Commande

```bash
# Migration automatique complète
./k8s-to-k3s-migration/scripts/complete-migration.sh

# Ou par étapes
./k8s-to-k3s-migration/scripts/complete-migration.sh check        # Vérifier l'environnement
./k8s-to-k3s-migration/scripts/complete-migration.sh infrastructure # Déployer K3s
./k8s-to-k3s-migration/scripts/complete-migration.sh export      # Exporter du source
./k8s-to-k3s-migration/scripts/complete-migration.sh secrets     # Configurer secrets
./k8s-to-k3s-migration/scripts/complete-migration.sh deploy      # Déployer apps
./k8s-to-k3s-migration/scripts/complete-migration.sh migrate     # Migrer données
./k8s-to-k3s-migration/scripts/complete-migration.sh validate    # Valider
```

### Scripts Individuels

#### 1. Export des Manifests et Secrets

```bash
# Export complet du cluster source
./k8s-to-k3s-migration/scripts/export-manifests-and-secrets.sh

# Ou export par composant
./k8s-to-k3s-migration/scripts/export-manifests-and-secrets.sh check      # Vérifier
./k8s-to-k3s-migration/scripts/export-manifests-and-secrets.sh export     # Exporter
./k8s-to-k3s-migration/scripts/export-manifests-and-secrets.sh summary    # Résumé
```

**Sortie :**
- `exported-manifests/namespaces/` - Manifests par namespace
- `exported-manifests/secrets/` - Secrets avec données décodées
- `exported-manifests/manifests/` - Manifests nettoyés pour K3s
- `exported-manifests/migration-summary.md` - Résumé détaillé

#### 2. Configuration des Secrets

```bash
# Configuration complète des secrets
./k8s-to-k3s-migration/scripts/setup-secrets.sh

# Ou configuration par type
./k8s-to-k3s-migration/scripts/setup-secrets.sh docker        # Registry Docker
./k8s-to-k3s-migration/scripts/setup-secrets.sh external-dns  # External DNS
./k8s-to-k3s-migration/scripts/setup-secrets.sh exported      # Secrets exportés
./k8s-to-k3s-migration/scripts/setup-secrets.sh custom       # Secrets personnalisés
```

#### 3. Migration des Applications

```bash
# Migration complète
./k8s-to-k3s-migration/automation/migrate.sh

# Ou migration par phase
./k8s-to-k3s-migration/automation/migrate.sh export    # Export données
./k8s-to-k3s-migration/automation/migrate.sh deploy    # Déployer apps
./k8s-to-k3s-migration/automation/migrate.sh import    # Importer données
./k8s-to-k3s-migration/automation/migrate.sh validate  # Valider
```

## 📦 Applications Supportées

| Application | Namespace | Type | Migration Données |
|-------------|-----------|------|-------------------|
| **Vaultwarden** | vaultwarden | StatefulSet | ✅ SQLite DB |
| **Monitoring** | monitoring | Prometheus/Grafana/Loki | ✅ Dashboards, métriques |
| **PgAdmin** | ops | Deployment | ❌ Configuration seulement |
| **GitLab Runner** | gitlab-runner | Deployment | ✅ Configuration |
| **HubSpot Manager** | hubspot-manager | CronJobs | ❌ Pas de données |
| **Reloader** | reloader | Deployment | ❌ Pas de données |
| **KEDA** | keda | Deployment | ❌ Pas de données |

## 🔐 Gestion des Secrets

### Secrets Automatiques

- **Docker Registry Scaleway** : Créé automatiquement dans tous les namespaces
- **External DNS** : Credentials Scaleway pour la gestion DNS
- **Secrets exportés** : Migration automatique depuis le cluster source

### Secrets Optionnels

Configurez ces variables dans `.envrc` si nécessaire :

```bash
# Optionnel: Token admin Vaultwarden personnalisé
export VAULTWARDEN_ADMIN_TOKEN="votre-token-admin"

# Optionnel: Credentials Slack pour HubSpot Manager
export SLACK_BOT_TOKEN="xoxb-votre-token"
export SLACK_CHANNEL="canal-notifications"

# Optionnel: Token GitLab Runner personnalisé
export GITLAB_RUNNER_TOKEN="votre-token-runner"
```

## 🌐 Configuration DNS

Après la migration, configurez ces enregistrements DNS :

```
vault1.keltio.fr      → [IP_K3S]
status.keltio.fr      → [IP_K3S]
prometheus.keltio.fr  → [IP_K3S]
pgadmin.solya.app     → [IP_K3S]
```

**Important :** Désactivez le proxy Cloudflare (nuage orange) pour tous ces domaines.

## 🔍 Validation et Dépannage

### Vérifier le Statut

```bash
# Statut général
kubectl --kubeconfig=kubeconfig-target.yaml get pods --all-namespaces

# Statut par application
kubectl --kubeconfig=kubeconfig-target.yaml get pods -n vaultwarden
kubectl --kubeconfig=kubeconfig-target.yaml get pods -n monitoring

# Logs d'une application
kubectl --kubeconfig=kubeconfig-target.yaml logs -n vaultwarden vaultwarden-0
```

### Problèmes Courants

#### 1. Image Pull Errors

```bash
# Vérifier les secrets Docker
kubectl --kubeconfig=kubeconfig-target.yaml get secrets -A | grep scaleway-registry

# Recréer si nécessaire
./k8s-to-k3s-migration/scripts/setup-secrets.sh docker
```

#### 2. Certificats SSL

```bash
# Vérifier Cert Manager
kubectl --kubeconfig=kubeconfig-target.yaml get certificates --all-namespaces
kubectl --kubeconfig=kubeconfig-target.yaml describe clusterissuer letsencrypt-prod

# Logs Cert Manager
kubectl --kubeconfig=kubeconfig-target.yaml logs -n cert-manager -l app=cert-manager
```

#### 3. DNS ne se résout pas

```bash
# Logs External DNS
kubectl --kubeconfig=kubeconfig-target.yaml logs -n kube-system -l app.kubernetes.io/name=external-dns

# Vérifier les secrets Scaleway
kubectl --kubeconfig=kubeconfig-target.yaml get secret external-dns-scaleway -n kube-system -o yaml
```

#### 4. Données Vaultwarden

```bash
# Vérifier les permissions
kubectl --kubeconfig=kubeconfig-target.yaml exec vaultwarden-0 -n vaultwarden -- ls -la /data/

# Logs Vaultwarden
kubectl --kubeconfig=kubeconfig-target.yaml logs -n vaultwarden vaultwarden-0
```

## 🔄 Migration Incrémentale

Pour migrer des applications supplémentaires :

1. **Ajouter le namespace** dans les scripts d'export
2. **Exporter** les nouvelles applications
3. **Configurer** les secrets spécifiques
4. **Déployer** les nouvelles applications
5. **Migrer** les données si nécessaire

## 📚 Documentation Avancée

- [Guide d'Installation](docs/installation.md) - Installation détaillée
- [Architecture](docs/architecture.md) - Vue d'ensemble technique
- [Sécurité](docs/security.md) - Bonnes pratiques de sécurité
- [Dépannage](docs/troubleshooting.md) - Guide de résolution des problèmes

## 🤝 Contribution

1. Fork le projet
2. Créer une branche feature (`git checkout -b feature/amelioration`)
3. Commit les changements (`git commit -am 'Ajout: nouvelle fonctionnalité'`)
4. Push la branche (`git push origin feature/amelioration`)
5. Créer une Pull Request

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 💡 Support

- **Issues** : Utilisez les GitHub Issues pour les bugs et questions
- **Discussions** : GitHub Discussions pour les idées et améliorations
- **Wiki** : Documentation communautaire dans le Wiki

---

**🎉 Bonne migration !** 🚀
