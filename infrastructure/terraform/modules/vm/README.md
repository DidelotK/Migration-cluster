# Module Terraform VM Scaleway

Ce module Terraform crée une infrastructure complète pour déployer K3s sur Scaleway.

## 🚀 Fonctionnalités

- ✅ **Création automatique d'instance** Scaleway optimisée pour K3s
- ✅ **Gestion des clés SSH** avec génération automatique
- ✅ **Configuration réseau** avec IP publique statique
- ✅ **Groupes de sécurité** pré-configurés pour K3s
- ✅ **Volumes supplémentaires** configurables
- ✅ **Cloud-init** pour l'initialisation automatique
- ✅ **Tags et labels** pour l'organisation
- ✅ **Outputs** complets pour Ansible

## 📋 Prérequis

- Terraform >= 1.0
- Provider Scaleway configuré
- Clés API Scaleway

## 🔧 Utilisation

### Utilisation basique

```hcl
module "k3s_vm" {
  source = "./modules/vm"
  
  instance_name = "k3s-production"
  instance_type = "GP1-S"
  environment   = "prod"
  
  tags = ["k3s", "production", "web"]
}
```

### Utilisation avancée

```hcl
module "k3s_vm" {
  source = "./modules/vm"
  
  # Configuration de l'instance
  instance_name    = "k3s-cluster-prod"
  instance_type    = "GP1-M"
  zone            = "fr-par-1"
  environment     = "prod"
  
  # Configuration du stockage
  root_volume_size = 50
  root_volume_type = "b_ssd"
  
  additional_volumes = {
    "data" = {
      size = 100
      type = "b_ssd"
    }
    "backup" = {
      size = 50
      type = "l_ssd"
    }
  }
  
  # Configuration SSH
  ssh_key_name         = "k3s-prod-key"
  ssh_private_key_path = "~/.ssh/k3s_prod"
  create_ssh_key       = true
  
  # Configuration réseau
  create_public_ip = true
  enable_ipv6     = true
  
  # Règles de sécurité personnalisées
  security_group_rules = {
    inbound = [
      {
        action   = "accept"
        port     = 22
        protocol = "TCP"
        ip_range = "10.0.0.0/8"  # SSH depuis réseau privé uniquement
      },
      {
        action   = "accept"
        port     = 80
        protocol = "TCP"
        ip_range = "0.0.0.0/0"
      },
      {
        action   = "accept"
        port     = 443
        protocol = "TCP"
        ip_range = "0.0.0.0/0"
      }
    ]
    outbound = [
      {
        action   = "accept"
        port     = 0
        protocol = "TCP"
        ip_range = "0.0.0.0/0"
      }
    ]
  }
  
  # Packages système
  packages = [
    "curl", "wget", "git", "htop", "tree", "jq",
    "python3", "python3-pip", "docker.io"
  ]
  
  tags = ["k3s", "production", "high-availability"]
}
```

## 📊 Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `instance_name` | string | `"k3s-cluster"` | Nom de l'instance |
| `instance_type` | string | `"GP1-XS"` | Type d'instance Scaleway |
| `image_id` | string | `"ubuntu_jammy"` | Image de base |
| `zone` | string | `"fr-par-1"` | Zone Scaleway |
| `environment` | string | `"dev"` | Environnement (dev/staging/prod) |
| `root_volume_size` | number | `20` | Taille du volume racine (GB) |
| `additional_volumes` | map | `{}` | Volumes supplémentaires |
| `create_ssh_key` | bool | `true` | Créer automatiquement une clé SSH |
| `create_public_ip` | bool | `true` | Créer une IP publique statique |
| `tags` | list | `["k3s", "migration", "terraform"]` | Tags des ressources |

## 📤 Outputs

| Output | Description |
|--------|-------------|
| `public_ip` | Adresse IP publique |
| `ssh_command` | Commande SSH complète |
| `ansible_inventory` | Configuration pour Ansible |
| `instance_id` | ID de l'instance |
| `monitoring_labels` | Labels pour monitoring |

## 🔐 Sécurité

Le module configure automatiquement :

- **Firewall UFW** avec règles optimisées pour K3s
- **Groupes de sécurité** Scaleway
- **Clés SSH** sécurisées (pas de mot de passe)
- **Désactivation swap** pour K3s
- **Modules kernel** requis

## 🚀 Cloud-init

L'initialisation automatique configure :

- Mise à jour système
- Installation des prérequis K3s
- Configuration réseau
- Optimisations kernel
- Outils de développement

## 📋 Exemple complet

Voir le fichier `examples/` pour des configurations complètes.

## 🐛 Troubleshooting

### Problème de connexion SSH

```bash
# Vérifier la clé SSH
ssh-keygen -l -f ~/.ssh/k3s_migration

# Tester la connexion
ssh -i ~/.ssh/k3s_migration root@<IP>
```

### Problème de permissions

```bash
# Corriger les permissions de la clé
chmod 600 ~/.ssh/k3s_migration
```

## 📚 Documentation

- [Scaleway Provider](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [K3s Documentation](https://docs.k3s.io/)
