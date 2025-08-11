# 🚀 Guide de démarrage rapide

Ce guide vous permettra de déployer votre cluster K3s en moins de 10 minutes.

## ⏱️ Temps estimé: 8-10 minutes

## 📋 Prérequis (2 min)

### Installation des outils

**Sur macOS:**
```bash
brew install terraform ansible kubectl jq
```

**Sur Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y terraform ansible kubectl jq curl
```

### Credentials Scaleway
Vous devez avoir:
- ✅ Clé d'accès Scaleway
- ✅ Clé secrète Scaleway  
- ✅ Organization ID
- ✅ Project ID

## 🏗️ Étape 1: Configuration (1 min)

```bash
# Cloner le projet
git clone <your-repo>
cd migrationcluster

# Copier la configuration
cp infrastructure/terraform/environments/dev/terraform.tfvars.example \
   infrastructure/terraform/environments/dev/terraform.tfvars
```

Éditer le fichier `terraform.tfvars`:
```bash
nano infrastructure/terraform/environments/dev/terraform.tfvars
```

Remplir avec vos credentials:
```hcl
scw_access_key      = "SCWXXXXXXXXXXXXXXXXX"
scw_secret_key      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
scw_organization_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
scw_project_id      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

instance_name = "k3s-prod"  # Changez selon votre besoin
```

## 🚀 Étape 2: Déploiement automatique (5-7 min)

### Option A: Script tout-en-un (Recommandé)

```bash
./scripts/deploy-full-stack.sh dev
```

### Option B: Étape par étape

```bash
# 1. Infrastructure (2-3 min)
cd infrastructure/terraform/environments/dev
terraform init
terraform apply -auto-approve

# 2. Installation K3s (3-4 min)
cd ../../../../ansible
ansible-playbook -i inventories/dev.ini site.yml
```

## ✅ Étape 3: Vérification (1 min)

```bash
# Configuration kubectl
export KUBECONFIG=~/.kube/k3s.yaml

# Test du cluster
kubectl get nodes
kubectl get pods --all-namespaces

# Test d'une application
IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
curl -k https://$IP
```

## 🎯 Résultat attendu

Après ces étapes, vous devriez avoir:

✅ **VM Scaleway** déployée et configurée  
✅ **K3s cluster** opérationnel  
✅ **Helm** installé et configuré  
✅ **kubectl** configuré localement  
✅ **Prêt** pour déployer des applications  

## 📊 Informations importantes

Une fois terminé, notez ces informations:

```bash
# IP de votre cluster
terraform output -raw network_details | jq -r '.public_ip'

# Commande SSH
terraform output -raw ssh_access | jq -r '.command'

# Kubeconfig local
echo $KUBECONFIG
```

## 🚀 Prochaines étapes

Maintenant que votre cluster est prêt:

1. **Installer les composants essentiels** (Ingress, Cert Manager, etc.)
2. **Déployer vos applications**
3. **Configurer les domaines DNS**

Voir le [Guide des applications](applications.md) pour la suite.

## 🐛 Problèmes courants

### Terraform: "Invalid credentials"
```bash
# Vérifiez vos credentials dans terraform.tfvars
cat infrastructure/terraform/environments/dev/terraform.tfvars
```

### SSH: "Permission denied"
```bash
# Les clés SSH sont générées automatiquement
# Vérifiez les permissions:
chmod 600 ~/.ssh/k3s_*
```

### Ansible: "Unreachable host"
```bash
# Attendez 1-2 minutes que la VM termine son initialisation
# Puis relancez:
ansible-playbook -i inventories/dev.ini site.yml
```

## 💡 Conseils

- **Première fois?** Utilisez l'environnement `dev`
- **Production?** Utilisez l'environnement `prod` avec une VM plus puissante
- **Problème?** Consultez les logs avec `kubectl logs`
- **Backup?** Les configurations sont dans Git, votre données dans les PVC

## 📞 Aide

Si vous rencontrez des problèmes:

1. Consultez les [logs](#🐛-problèmes-courants)
2. Vérifiez le [troubleshooting](../README.md#🐛-troubleshooting)
3. Ouvrez une issue sur le projet

---

**🎉 Félicitations! Votre cluster K3s est maintenant opérationnel!**
