# 🚀 Guide de Démarrage Rapide

Ce guide vous permet de migrer votre cluster K8s vers K3s en moins de 30 minutes.

## ⏱️ Temps Estimé

- **Préparation** : 5 minutes
- **Export** : 5 minutes
- **Déploiement K3s** : 10 minutes
- **Migration** : 10 minutes

## 📋 Checklist Pré-Migration

- [ ] Cluster K8s source accessible
- [ ] Credentials Scaleway disponibles
- [ ] Compte Scaleway avec quota suffisant
- [ ] Accès DNS pour configurer les domaines
- [ ] Sauvegarde des données critiques (recommandé)

## 🛠️ Étape 1: Préparation (5 min)

### 1.1 Installer les Outils

```bash
# macOS
brew install kubectl helm terraform ansible direnv yq jq

# Ubuntu
sudo apt update && sudo apt install -y kubectl helm terraform ansible direnv

# Installer yq et jq
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
sudo chmod +x /usr/local/bin/yq
sudo apt install jq
```

### 1.2 Configurer l'Environnement

```bash
# 1. Activer direnv
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc  # ou ~/.bashrc
source ~/.zshrc

# 2. Copier et configurer .envrc
cp .envrc.example .envrc
vim .envrc  # Ajouter vos vraies credentials Scaleway

# 3. Activer l'environnement
direnv allow

# 4. Vérifier
echo $SCW_ACCESS_KEY  # Doit afficher votre clé
```

### 1.3 Préparer les Kubeconfigs

```bash
# Copier le kubeconfig de votre cluster K8s source
cp votre-kubeconfig-existant.yaml kubeconfig-keltio-prod.yaml

# Vérifier l'accès
kubectl --kubeconfig=kubeconfig-keltio-prod.yaml get nodes
```

## 🏗️ Étape 2: Déploiement Infrastructure K3s (10 min)

### 2.1 Déployer l'Infrastructure

```bash
# Aller dans le répertoire Terraform
cd infrastructure/terraform/environments/dev

# Copier et configurer les variables
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Ajuster si nécessaire

# Déployer
terraform init
terraform plan
terraform apply

# Retourner à la racine
cd ../../../../
```

### 2.2 Récupérer le Kubeconfig K3s

```bash
# Récupérer automatiquement via Terraform
cd infrastructure/terraform/environments/dev
VM_IP=$(terraform output -raw vm_public_ip)
SSH_CMD=$(terraform output -raw ssh_command)

# Récupérer le kubeconfig
eval "$SSH_CMD 'sudo cat /etc/rancher/k3s/k3s.yaml'" > ../../../../kubeconfig-target.yaml.tmp

# Remplacer l'IP localhost par l'IP publique
sed "s/127.0.0.1/$VM_IP/g" ../../../../kubeconfig-target.yaml.tmp > ../../../../kubeconfig-target.yaml
rm ../../../../kubeconfig-target.yaml.tmp

# Retourner à la racine et tester
cd ../../../../
kubectl --kubeconfig=kubeconfig-target.yaml get nodes
```

## 📤 Étape 3: Export du Cluster Source (5 min)

```bash
# Lancer l'export complet
./k8s-to-k3s-migration/scripts/export-manifests-and-secrets.sh

# Vérifier les résultats
ls -la k8s-to-k3s-migration/exported-manifests/
cat k8s-to-k3s-migration/exported-manifests/migration-summary.md
```

## 🔐 Étape 4: Configuration des Secrets (2 min)

```bash
# Configurer tous les secrets automatiquement
./k8s-to-k3s-migration/scripts/setup-secrets.sh

# Vérifier
kubectl --kubeconfig=kubeconfig-target.yaml get secrets --all-namespaces | grep -E "scaleway|external-dns"
```

## 🚀 Étape 5: Migration Complète (10 min)

```bash
# Lancer la migration automatique
./k8s-to-k3s-migration/automation/migrate.sh

# Ou étape par étape pour plus de contrôle
./k8s-to-k3s-migration/automation/migrate.sh deploy    # Déployer apps
./k8s-to-k3s-migration/automation/migrate.sh import    # Migrer données
./k8s-to-k3s-migration/automation/migrate.sh validate  # Valider
```

## 🌐 Étape 6: Configuration DNS (3 min)

### 6.1 Récupérer l'IP K3s

```bash
# Méthode 1: Via kubectl
kubectl --kubeconfig=kubeconfig-target.yaml get nodes -o wide

# Méthode 2: Via Terraform
cd infrastructure/terraform/environments/dev
terraform output vm_public_ip
cd ../../../../
```

### 6.2 Configurer les Enregistrements DNS

Ajouter dans votre fournisseur DNS (Cloudflare, etc.) :

```
Type: A    Name: vault1.keltio.fr      Value: [IP_K3S]    Proxy: OFF
Type: A    Name: status.keltio.fr      Value: [IP_K3S]    Proxy: OFF
Type: A    Name: prometheus.keltio.fr  Value: [IP_K3S]    Proxy: OFF
Type: A    Name: pgadmin.solya.app     Value: [IP_K3S]    Proxy: OFF
```

**⚠️ Important :** Désactivez le proxy Cloudflare (nuage orange) !

## ✅ Étape 7: Validation (5 min)

### 7.1 Vérifier les Pods

```bash
# Statut général
kubectl --kubeconfig=kubeconfig-target.yaml get pods --all-namespaces

# Applications critiques
kubectl --kubeconfig=kubeconfig-target.yaml get pods -n vaultwarden
kubectl --kubeconfig=kubeconfig-target.yaml get pods -n monitoring
```

### 7.2 Tester les URLs

Attendre 2-5 minutes pour la propagation DNS, puis tester :

```bash
# Tests de connectivité
curl -I https://vault1.keltio.fr
curl -I https://status.keltio.fr
curl -I https://prometheus.keltio.fr
curl -I https://pgadmin.solya.app

# Ou dans le navigateur
open https://vault1.keltio.fr
open https://status.keltio.fr
```

### 7.3 Vérifier les Certificats SSL

```bash
# Statut des certificats
kubectl --kubeconfig=kubeconfig-target.yaml get certificates --all-namespaces

# Si problème SSL
kubectl --kubeconfig=kubeconfig-target.yaml describe clusterissuer letsencrypt-prod
kubectl --kubeconfig=kubeconfig-target.yaml logs -n cert-manager -l app=cert-manager
```

## 🎉 Félicitations !

Votre migration est terminée ! Vous devriez maintenant avoir :

- ✅ Cluster K3s fonctionnel sur Scaleway
- ✅ Toutes les applications migrées
- ✅ Données préservées (Vaultwarden, Grafana, etc.)
- ✅ SSL automatique avec Let's Encrypt
- ✅ DNS fonctionnel

## 🆘 En Cas de Problème

### Pods qui ne démarrent pas

```bash
# Diagnostic
kubectl --kubeconfig=kubeconfig-target.yaml describe pod <pod-name> -n <namespace>
kubectl --kubeconfig=kubeconfig-target.yaml logs <pod-name> -n <namespace>

# Problème d'image : vérifier les secrets Docker
kubectl --kubeconfig=kubeconfig-target.yaml get secrets -A | grep scaleway-registry

# Recréer les secrets si nécessaire
./k8s-to-k3s-migration/scripts/setup-secrets.sh docker
```

### SSL ne fonctionne pas

```bash
# Vérifier Cert Manager
kubectl --kubeconfig=kubeconfig-target.yaml get pods -n cert-manager
kubectl --kubeconfig=kubeconfig-target.yaml logs -n cert-manager -l app=cert-manager

# Vérifier les challenges
kubectl --kubeconfig=kubeconfig-target.yaml get challenges --all-namespaces
```

### DNS ne se résout pas

```bash
# Vérifier External DNS
kubectl --kubeconfig=kubeconfig-target.yaml logs -n kube-system -l app.kubernetes.io/name=external-dns

# Tester manuellement
dig vault1.keltio.fr
nslookup status.keltio.fr
```

## 📞 Support

- Consultez les logs des applications
- Vérifiez la documentation complète dans `k8s-to-k3s-migration/docs/`
- Utilisez les scripts de diagnostic fournis

---

**🎊 Bravo ! Votre cluster K3s est opérationnel !** 🚀
