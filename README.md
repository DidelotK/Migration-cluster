# 🚀 K3s Migration Cluster

## 📖 Description

Infrastructure automatisée pour migrer vers un cluster K3s sur Scaleway, réduisant les coûts de ~250€/mois à ~50€/mois (économie de 80%).

Déploiement **entièrement automatisé** avec Terraform + Ansible :
- ☸️ **K3s** (Kubernetes léger)
- 🌐 **Ingress Nginx** (Contrôleur HTTP/HTTPS)
- 🔐 **Cert Manager** (SSL automatique Let's Encrypt)
- 🌍 **External DNS** (Gestion DNS Scaleway)
- 🛡️ **External Secrets** (Gestion sécurisée des secrets)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                 Scaleway Cloud                      │
├─────────────────────────────────────────────────────┤
│  GP1-XS VM (4 vCPU, 16GB RAM, ~50€/mois)          │
│  ├── K3s Cluster                                   │
│  ├── Ingress Nginx (ports 80/443)                  │
│  ├── Cert Manager (Let's Encrypt)                  │
│  ├── External DNS (Scaleway DNS)                   │
│  └── Applications                                  │
└─────────────────────────────────────────────────────┘
```

## 🚀 Déploiement rapide

### Prérequis

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) >= 2.9
- [direnv](https://direnv.net/) pour la gestion sécurisée des variables
- Account Scaleway avec API credentials
- Domaine configuré (ex: `keltio.fr`)

### Configuration

1. **Cloner le repository :**
   ```bash
   git clone <repository-url>
   cd migrationcluster
   ```

2. **Configurer les credentials avec direnv :**
   ```bash
   # Copier le template
   cp .envrc.example .envrc
   
   # Éditer avec tes credentials Scaleway
   nano .envrc
   
   # Activer direnv
   direnv allow
   ```

3. **Variables Scaleway requises dans .envrc :**
   ```bash
   export SCW_ACCESS_KEY="SCWXXXXXXXXXX"
   export SCW_SECRET_KEY="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   export SCW_ORGANIZATION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   export SCW_PROJECT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   ```

### Déploiement automatique

**Option 1 - Déploiement complet (recommandé) :**
```bash
./deploy-complete-automation.sh
```

**Option 2 - Déploiement rapide :**
```bash
./deploy-full-k3s.sh
```

**Option 3 - Terraform uniquement :**
```bash
cd infrastructure/terraform/environments/dev
terraform init
terraform apply
```

## 🔧 Gestion

### Connexion SSH
```bash
ssh -i ssh-keys/k3s-migration-dev root@<VM_IP>
```

### Gestion du cluster
```bash
# Se connecter à la VM
ssh -i ssh-keys/k3s-migration-dev root@<VM_IP>

# Commandes kubectl
k3s kubectl get pods -A
k3s kubectl get nodes
k3s kubectl get ingress -A
```

### Destruction
```bash
./destroy-infrastructure.sh
```

## 📁 Structure du projet

```
migrationcluster/
├── README.md                          # Documentation
├── deploy-complete-automation.sh      # 🚀 Script principal
├── deploy-full-k3s.sh                # Déploiement rapide
├── destroy-infrastructure.sh         # Destruction
├── docs/                             # Documentation
├── infrastructure/                   # Infrastructure as Code
│   └── terraform/                    
│       ├── modules/vm/              # Module VM Scaleway
│       └── environments/dev/        # Configuration environnement
│   ├── ansible/                     # Automation
│   │   ├── roles/                   # Rôles K3s, Helm, Ingress, etc.
│   │   ├── playbooks/               # Playbooks par composant
│   │   └── inventories/             # Inventaires par environnement
│   └── helm/                        # Helm chart values
├── k8s/                            # Manifests applications (vides par défaut)
└── ssh-keys/                       # Clés SSH générées
```

## 🛠️ Composants déployés

| Composant | Version | Description |
|-----------|---------|-------------|
| **K3s** | v1.28.5+k3s1 | Distribution Kubernetes légère |
| **Helm** | v3.13.3 | Gestionnaire de packages Kubernetes |
| **Ingress Nginx** | v1.13.0 | Contrôleur d'entrée HTTP/HTTPS |
| **Cert Manager** | v1.13.3 | Gestion automatique des certificats SSL |
| **External DNS** | v0.18.0 | Synchronisation DNS automatique |

## 🔒 Sécurité

- 🔐 **SSH** : Clés générées automatiquement par Terraform
- 🛡️ **Firewall** : Ports 22, 80, 443, 6443 uniquement
- 🔒 **SSL** : Certificats Let's Encrypt automatiques
- 🌐 **DNS** : Gestion sécurisée via External DNS
- 🔑 **Secrets** : Credentials Scaleway via Kubernetes secrets

## 📊 Monitoring et logs

### Vérification du cluster
```bash
# Status global
k3s kubectl get all -A

# Certificats SSL
k3s kubectl get certificate -A

# Logs des composants
k3s kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
k3s kubectl logs -n cert-manager -l app=cert-manager
k3s kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns
```

## 🚨 Dépannage

### Problèmes courants

**1. Erreur SSH "Permission denied" :**
```bash
chmod 600 ssh-keys/k3s-migration-dev
ssh-keygen -R <VM_IP>
```

**2. Certificat SSL en attente :**
```bash
k3s kubectl describe certificate <cert-name> -n <namespace>
k3s kubectl get challenges -A
```

**3. DNS non résolu :**
```bash
k3s kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns
dig <domain>
```

**4. Pods en CrashLoopBackOff :**
```bash
k3s kubectl describe pod <pod-name> -n <namespace>
k3s kubectl logs <pod-name> -n <namespace>
```

## 🏷️ Tags et versions

### Environments
- `dev` : Développement et tests
- `staging` : Pré-production  
- `prod` : Production

### Déploiement par tags Ansible
```bash
# Déployer uniquement K3s
ansible-playbook -i inventories/dev.ini site.yml --tags "k3s"

# Déployer uniquement Ingress
ansible-playbook -i inventories/dev.ini site.yml --tags "ingress-nginx"

# Déployer uniquement Cert Manager
ansible-playbook -i inventories/dev.ini site.yml --tags "cert-manager"
```

## 💰 Économies

| Avant | Après | Économie |
|-------|-------|----------|
| ~250€/mois | ~50€/mois | **200€/mois (80%)** |
| Kubernetes managé | K3s auto-géré | Contrôle total |
| Multiple services | VM unique | Simplicité |

## 🤝 Contribution

1. Fork le projet
2. Créer une branche feature (`git checkout -b feature/nouvelle-fonctionnalite`)
3. Commit les changements (`git commit -am 'Ajout nouvelle fonctionnalité'`)
4. Push la branche (`git push origin feature/nouvelle-fonctionnalite`)
5. Créer une Pull Request

## 📝 License

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 📞 Support

Pour toute question ou problème :
1. Consulter la [documentation](docs/)
2. Vérifier les [issues](https://github.com/username/migrationcluster/issues)
3. Créer une nouvelle issue si nécessaire

---

**🎯 Prêt pour la production !** Cette infrastructure est optimisée pour la stabilité, la sécurité et les performances.