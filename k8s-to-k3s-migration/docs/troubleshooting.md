# 🔧 Guide de Dépannage

Ce guide vous aide à résoudre les problèmes courants lors de la migration K8s → K3s.

## 🚨 Problèmes d'Infrastructure

### VM Scaleway ne démarre pas

**Symptômes :**
- Terraform timeout lors de la création
- VM en état "stopped" ou "starting"

**Diagnostic :**
```bash
# Vérifier le statut via Terraform
cd infrastructure/terraform/environments/dev
terraform show

# Vérifier via console Scaleway
# Ou via CLI Scaleway
scw instance server list
```

**Solutions :**
1. **Quota insuffisant** :
   ```bash
   # Vérifier les quotas Scaleway
   scw account quota list
   ```

2. **Type d'instance non disponible** :
   ```bash
   # Changer le type dans terraform.tfvars
   vm_type = "DEV1-S"  # Au lieu de GP1-XS
   ```

3. **Zone non disponible** :
   ```bash
   # Changer la zone
   vm_zone = "fr-par-2"  # Au lieu de fr-par-1
   ```

### SSH ne fonctionne pas

**Symptômes :**
- `Permission denied (publickey)`
- `Connection timeout`

**Diagnostic :**
```bash
# Tester la connexion
ssh -i ssh-keys/vm-key ubuntu@[VM_IP] -v

# Vérifier les permissions
ls -la ssh-keys/
```

**Solutions :**
```bash
# Corriger les permissions
chmod 600 ssh-keys/vm-key
chmod 644 ssh-keys/vm-key.pub

# Recréer la clé si nécessaire
cd infrastructure/terraform/environments/dev
terraform taint module.vm.tls_private_key.vm_key
terraform apply
```

## 🐳 Problèmes K3s

### K3s ne démarre pas

**Symptômes :**
- Service k3s failed
- Pods en CrashLoopBackOff

**Diagnostic :**
```bash
# Connexion à la VM
ssh -i ssh-keys/vm-key ubuntu@[VM_IP]

# Vérifier le service K3s
sudo systemctl status k3s
sudo journalctl -u k3s -f

# Vérifier les ressources
df -h
free -h
```

**Solutions :**
1. **Espace disque insuffisant** :
   ```bash
   # Nettoyer les images Docker
   sudo k3s crictl images prune
   
   # Augmenter la taille du disque dans Terraform
   root_volume_size = 120  # Au lieu de 80
   ```

2. **Mémoire insuffisante** :
   ```bash
   # Vérifier l'utilisation mémoire
   sudo k3s kubectl top nodes
   
   # Upgrade le type de VM
   vm_type = "GP1-S"  # Plus de RAM
   ```

### Pods en ImagePullBackOff

**Symptômes :**
- `ErrImagePull`
- `ImagePullBackOff`

**Diagnostic :**
```bash
# Vérifier les événements
kubectl --kubeconfig=kubeconfig-target.yaml get events --sort-by='.lastTimestamp'

# Vérifier les secrets Docker
kubectl --kubeconfig=kubeconfig-target.yaml get secrets -A | grep registry
```

**Solutions :**
```bash
# Recréer les secrets Docker Registry
./k8s-to-k3s-migration/scripts/setup-secrets.sh docker

# Vérifier les credentials Scaleway
echo $SCW_SECRET_KEY

# Tester manuellement
docker login rg.fr-par.scw.cloud -u nologin -p $SCW_SECRET_KEY
```

### Ingress ne fonctionne pas

**Symptômes :**
- Sites inaccessibles
- `404 Not Found` ou `Connection refused`

**Diagnostic :**
```bash
# Vérifier Ingress Nginx
kubectl --kubeconfig=kubeconfig-target.yaml get pods -n ingress-nginx

# Vérifier les logs
kubectl --kubeconfig=kubeconfig-target.yaml logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Vérifier les Ingress
kubectl --kubeconfig=kubeconfig-target.yaml get ingress -A
```

**Solutions :**
1. **Ports non ouverts** :
   ```bash
   # Vérifier les ports sur la VM
   ssh -i ssh-keys/vm-key ubuntu@[VM_IP]
   sudo netstat -tlnp | grep :80
   sudo netstat -tlnp | grep :443
   ```

2. **Ingress Controller mal configuré** :
   ```bash
   # Redéployer Ingress Nginx
   kubectl --kubeconfig=kubeconfig-target.yaml delete namespace ingress-nginx
   
   # Relancer Ansible
   cd infrastructure/terraform/environments/dev
   terraform apply -replace="null_resource.ansible_provisioner"
   ```

## 🔐 Problèmes SSL/TLS

### Certificats Let's Encrypt échouent

**Symptômes :**
- `NET::ERR_CERT_AUTHORITY_INVALID`
- Certificate requests failed

**Diagnostic :**
```bash
# Vérifier Cert Manager
kubectl --kubeconfig=kubeconfig-target.yaml get pods -n cert-manager

# Vérifier les certificats
kubectl --kubeconfig=kubeconfig-target.yaml get certificates -A

# Vérifier les challenges
kubectl --kubeconfig=kubeconfig-target.yaml get challenges -A
```

**Solutions :**
1. **Firewall bloque HTTP-01** :
   ```bash
   # Vérifier les security groups Scaleway
   scw instance security-group list
   
   # Ajouter règles HTTP/HTTPS si manquantes
   # Ports 80 et 443 doivent être ouverts
   ```

2. **DNS ne pointe pas vers le bon IP** :
   ```bash
   # Vérifier la résolution DNS
   dig vault1.keltio.fr +short
   
   # Doit retourner l'IP de votre VM K3s
   ```

3. **Rate limiting Let's Encrypt** :
   ```bash
   # Utiliser staging temporairement
   kubectl --kubeconfig=kubeconfig-target.yaml patch clusterissuer letsencrypt-prod -p '{"spec":{"acme":{"server":"https://acme-staging-v02.api.letsencrypt.org/directory"}}}'
   ```

## 🌐 Problèmes DNS

### External DNS ne crée pas les enregistrements

**Symptômes :**
- DNS records not created
- External DNS logs errors

**Diagnostic :**
```bash
# Vérifier External DNS
kubectl --kubeconfig=kubeconfig-target.yaml logs -n kube-system -l app.kubernetes.io/name=external-dns

# Vérifier les secrets Scaleway
kubectl --kubeconfig=kubeconfig-target.yaml get secret external-dns-scaleway -n kube-system -o yaml
```

**Solutions :**
1. **Credentials Scaleway incorrects** :
   ```bash
   # Vérifier les variables
   echo $SCW_ACCESS_KEY
   echo $SCW_SECRET_KEY
   
   # Recréer le secret
   ./k8s-to-k3s-migration/scripts/setup-secrets.sh external-dns
   ```

2. **Permissions insuffisantes** :
   ```bash
   # Vérifier les permissions du token Scaleway
   # Le token doit avoir accès DNS
   ```

### Cloudflare Proxy activé

**Symptômes :**
- SSL errors avec Cloudflare
- Redirections infinies

**Solutions :**
```bash
# Désactiver le proxy Cloudflare (nuage orange → gris)
# Via interface web ou API :

curl -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
  -H "X-Auth-Email: $EMAIL" \
  -H "X-Auth-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  --data '{"proxied":false}'
```

## 💾 Problèmes de Migration de Données

### Vaultwarden - Base de données corrompue

**Symptômes :**
- `database is locked`
- `readonly database`

**Diagnostic :**
```bash
# Vérifier les logs Vaultwarden
kubectl --kubeconfig=kubeconfig-target.yaml logs -n vaultwarden vaultwarden-0

# Vérifier les permissions fichiers
kubectl --kubeconfig=kubeconfig-target.yaml exec vaultwarden-0 -n vaultwarden -- ls -la /data/
```

**Solutions :**
```bash
# Corriger les permissions
kubectl --kubeconfig=kubeconfig-target.yaml scale statefulset vaultwarden --replicas=0 -n vaultwarden

# Pod temporaire pour corriger
kubectl --kubeconfig=kubeconfig-target.yaml apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: fix-vaultwarden
  namespace: vaultwarden
spec:
  containers:
  - name: fix
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: vaultwarden-data-vaultwarden-0
EOF

# Corriger permissions et ownership
kubectl --kubeconfig=kubeconfig-target.yaml exec fix-vaultwarden -n vaultwarden -- chown -R 1000:1000 /data
kubectl --kubeconfig=kubeconfig-target.yaml exec fix-vaultwarden -n vaultwarden -- chmod 755 /data
kubectl --kubeconfig=kubeconfig-target.yaml exec fix-vaultwarden -n vaultwarden -- chmod 644 /data/db.sqlite3*

# Nettoyer et redémarrer
kubectl --kubeconfig=kubeconfig-target.yaml delete pod fix-vaultwarden -n vaultwarden
kubectl --kubeconfig=kubeconfig-target.yaml scale statefulset vaultwarden --replicas=1 -n vaultwarden
```

### Monitoring - Dashboards perdus

**Diagnostic :**
```bash
# Vérifier si les données Grafana sont présentes
kubectl --kubeconfig=kubeconfig-target.yaml exec -n monitoring deployment/kube-prometheus-stack-grafana -- ls -la /var/lib/grafana/
```

**Solutions :**
```bash
# Réimporter les dashboards depuis l'export
kubectl --kubeconfig=kubeconfig-target.yaml scale deployment kube-prometheus-stack-grafana --replicas=0 -n monitoring

# Réimporter les données
# (Utilisez le script de migration de données)

kubectl --kubeconfig=kubeconfig-target.yaml scale deployment kube-prometheus-stack-grafana --replicas=1 -n monitoring
```

## 🔍 Outils de Diagnostic

### Scripts d'aide

```bash
# Script de diagnostic global
cat > diagnostic.sh << 'EOF'
#!/bin/bash
echo "=== Diagnostic K3s Migration ==="
echo "Cluster status:"
kubectl --kubeconfig=kubeconfig-target.yaml get nodes -o wide

echo -e "\nPods status:"
kubectl --kubeconfig=kubeconfig-target.yaml get pods -A | grep -v Running

echo -e "\nIngress status:"
kubectl --kubeconfig=kubeconfig-target.yaml get ingress -A

echo -e "\nCertificates status:"
kubectl --kubeconfig=kubeconfig-target.yaml get certificates -A

echo -e "\nSecrets status:"
kubectl --kubeconfig=kubeconfig-target.yaml get secrets -A | grep -E "scaleway|external-dns"

echo -e "\nDisk usage:"
kubectl --kubeconfig=kubeconfig-target.yaml exec -n kube-system daemonset/local-path-provisioner -- df -h

echo -e "\nRecent events:"
kubectl --kubeconfig=kubeconfig-target.yaml get events --sort-by='.lastTimestamp' | tail -10
EOF

chmod +x diagnostic.sh
./diagnostic.sh
```

### Validation réseau

```bash
# Test connectivité depuis les pods
kubectl --kubeconfig=kubeconfig-target.yaml run test-pod --rm -it --image=busybox -- sh

# Dans le pod :
nslookup kubernetes.default.svc.cluster.local
wget -qO- http://google.com
```

## 📞 Escalade

Si les solutions ci-dessus ne résolvent pas votre problème :

1. **Collecter les logs** complets
2. **Documenter** les étapes de reproduction
3. **Vérifier** les issues GitHub existantes
4. **Créer** une nouvelle issue avec :
   - Description du problème
   - Logs pertinents
   - Configuration système
   - Étapes pour reproduire

## 🆘 Recovery

### Sauvegarde d'urgence

```bash
# Sauvegarder etcd K3s
ssh -i ssh-keys/vm-key ubuntu@[VM_IP]
sudo k3s etcd-snapshot save emergency-backup

# Exporter tous les manifests
kubectl --kubeconfig=kubeconfig-target.yaml get all -A -o yaml > emergency-export.yaml
```

### Restauration

```bash
# Restaurer etcd
sudo k3s server --cluster-reset --cluster-reset-restore-path=emergency-backup

# Réappliquer les manifests
kubectl --kubeconfig=kubeconfig-target.yaml apply -f emergency-export.yaml
```

---

**💡 Tip :** Gardez toujours une sauvegarde de votre cluster source jusqu'à validation complète de la migration !
