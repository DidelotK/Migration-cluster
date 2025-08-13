# 🔐 Guide de Sécurité

Ce guide détaille les bonnes pratiques de sécurité pour la migration K8s → K3s.

## 🛡️ Vue d'ensemble Sécurité

La solution de migration implémente plusieurs couches de sécurité :

1. **Infrastructure** - VM, réseau, accès SSH
2. **Kubernetes** - RBAC, secrets, network policies
3. **Applications** - Images, configurations, données
4. **Données** - Chiffrement, sauvegarde, accès

## 🔑 Gestion des Secrets et Credentials

### Variables d'Environnement (direnv)

**Configuration sécurisée** :
```bash
# .envrc - JAMAIS committé en Git
export SCW_ACCESS_KEY="SCWXXXXXXXXXX"
export SCW_SECRET_KEY="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export SCW_ORGANIZATION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export SCW_PROJECT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Optionnel - Secrets applicatifs
export VAULTWARDEN_ADMIN_TOKEN="$(openssl rand -base64 32)"
export SLACK_BOT_TOKEN="xoxb-your-secure-token"
```

**Bonnes pratiques** :
- ✅ Utiliser `direnv` pour l'isolation
- ✅ Générer des tokens forts
- ✅ Rotation régulière des credentials
- ❌ Jamais de hardcoding dans le code
- ❌ Jamais de commit des secrets

### Secrets Kubernetes

**Chiffrement au repos** :
```bash
# K3s chiffre automatiquement les secrets dans etcd
# Vérification :
kubectl --kubeconfig=kubeconfig-target.yaml get secrets -A -o yaml | grep -c "data:"
```

**Accès contrôlé** :
```bash
# RBAC pour limiter l'accès aux secrets
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: vaultwarden
  name: vaultwarden-secrets
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["vaultwarden-secret"]
  verbs: ["get"]
```

## 🌐 Sécurité Réseau

### Firewall et Security Groups

**Configuration Scaleway** :
```bash
# Ports ouverts minimaux
- SSH (22) : Votre IP uniquement
- HTTP (80) : 0.0.0.0/0 (pour Let's Encrypt)
- HTTPS (443) : 0.0.0.0/0 (trafic applicatif)
- K3s API (6443) : Votre IP uniquement
```

**Règles iptables automatiques** :
```bash
# K3s configure automatiquement :
# - CNI networking
# - Service load balancing
# - Pod-to-pod communication
```

### Network Policies (Optionnel)

**Isolation par namespace** :
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vaultwarden-isolation
  namespace: vaultwarden
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: vaultwarden
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 587  # SMTP
    - protocol: TCP
      port: 53   # DNS
    - protocol: UDP
      port: 53   # DNS
```

## 🔐 SSL/TLS et Chiffrement

### Certificats Let's Encrypt

**Configuration automatique** :
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@keltio.fr
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

**Rotation automatique** :
- Let's Encrypt : Renouvellement auto tous les 60 jours
- Cert Manager vérifie quotidiennement
- Alertes en cas d'échec

### Chiffrement en Transit

**HTTPS Forced** :
```yaml
# Redirection HTTP → HTTPS automatique via Ingress
annotations:
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
  nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
```

**TLS Configuration** :
```yaml
spec:
  tls:
  - hosts:
    - vault1.keltio.fr
    secretName: vaultwarden-tls
```

## 🐳 Sécurité des Images Docker

### Registry Privé Scaleway

**Authentication** :
```bash
# Secret Docker Registry sécurisé
kubectl create secret docker-registry scaleway-registry-secret \
  --docker-server=rg.fr-par.scw.cloud \
  --docker-username=nologin \
  --docker-password="$SCW_SECRET_KEY"
```

### Scanning de Vulnérabilités

**Images officielles uniquement** :
```yaml
# Utilisation d'images officielles et versionnées
containers:
- name: vaultwarden
  image: vaultwarden/server:1.30.1  # Version fixe
- name: grafana
  image: grafana/grafana:10.2.0     # Version fixe
```

**Bonnes pratiques** :
- ✅ Images officielles uniquement
- ✅ Tags de version fixe (pas `latest`)
- ✅ Scan régulier des vulnérabilités
- ❌ Images non vérifiées
- ❌ Tags `latest` en production

## 🔒 Sécurité des Pods

### Security Context

**Configuration par défaut** :
```yaml
spec:
  containers:
  - name: vaultwarden
    securityContext:
      runAsUser: 1000
      runAsGroup: 1000
      runAsNonRoot: true
      readOnlyRootFilesystem: false
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
```

### Pod Security Standards

**Restricted Policy** (Optionnel) :
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: vaultwarden
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## 🔐 RBAC (Role-Based Access Control)

### Service Accounts

**GitLab Runner exemple** :
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab-runner
  namespace: gitlab-runner
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: gitlab-runner
  namespace: gitlab-runner
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec", "pods/log", "secrets", "configmaps"]
  verbs: ["get", "list", "watch", "create", "delete", "update", "patch"]
```

### Principe du Moindre Privilège

- ✅ Permissions minimales par service
- ✅ RBAC au niveau namespace
- ✅ Pas de cluster-admin sauf admin
- ❌ Permissions wildcard (*)

## 💾 Sécurité des Données

### Persistent Volumes

**Local Path Provisioner** :
```bash
# Données stockées sur /var/lib/rancher/k3s/storage/
# Permissions : root:root 755
# Isolation par PVC
```

**Chiffrement disque** :
```bash
# VM Scaleway - Chiffrement au niveau bloc
# Configuration lors création VM
# Transparent pour K3s
```

### Sauvegarde Sécurisée

**etcd Snapshots** :
```bash
# Sauvegarde automatique etcd K3s
sudo k3s etcd-snapshot save backup-$(date +%Y%m%d-%H%M%S)

# Stockage sécurisé
scp backup-* secure-backup-server:/encrypted/backups/
```

**Application Data** :
```bash
# Vaultwarden SQLite
kubectl exec vaultwarden-0 -n vaultwarden -- sqlite3 /data/db.sqlite3 ".backup /data/backup.db"

# Monitoring Data
kubectl cp monitoring/kube-prometheus-stack-grafana-xxx:/var/lib/grafana ./grafana-backup/
```

## 🕵️ Monitoring et Audit

### Audit Logs K3s

**Activation** :
```bash
# Dans cloud-init ou manuellement
sudo k3s server \
  --audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log \
  --audit-log-maxage=30 \
  --audit-log-maxbackup=10 \
  --audit-log-maxsize=100 \
  --audit-policy-file=/etc/k3s/audit-policy.yaml
```

### Monitoring Sécurité

**Prometheus Rules** :
```yaml
groups:
- name: security.rules
  rules:
  - alert: HighFailedLoginRate
    expr: rate(authentication_attempts{result="failure"}[5m]) > 0.1
    for: 2m
    annotations:
      summary: "High failed login rate detected"
  
  - alert: UnauthorizedAPIAccess
    expr: rate(apiserver_audit_requests_total{verb="create",objectRef_resource="secrets"}[5m]) > 0.05
    for: 1m
    annotations:
      summary: "Suspicious secret access detected"
```

### Log Analysis

**Structured Logging** :
```bash
# Loki query examples
{namespace="vaultwarden"} |= "error"
{namespace="cert-manager"} |= "failed"
{job="apiserver"} |= "Forbidden"
```

## 🚨 Réponse aux Incidents

### Détection

**Indicateurs de compromission** :
- Pods avec comportement anormal
- Trafic réseau suspect
- Accès non autorisé aux secrets
- Certificats expirés/révoqués

### Containment

**Isolation immédiate** :
```bash
# Isoler un pod suspect
kubectl label pod <pod-name> security.compromised=true
kubectl patch networkpolicy deny-all --patch '{"spec":{"podSelector":{"matchLabels":{"security.compromised":"true"}}}}'

# Couper l'accès externe
kubectl patch service <service-name> --patch '{"spec":{"type":"ClusterIP"}}'
```

### Recovery

**Procédure de récupération** :
1. Isoler les composants compromis
2. Analyser les logs d'audit
3. Identifier la source de compromission
4. Nettoyer/recréer les ressources affectées
5. Renforcer la sécurité
6. Monitoring renforcé

## 📋 Checklist Sécurité

### Avant Migration
- [ ] Audit du cluster source
- [ ] Sauvegarde complète des données
- [ ] Validation des credentials Scaleway
- [ ] Test de la procédure de recovery

### Pendant Migration
- [ ] Chiffrement des données en transit
- [ ] Validation des signatures d'images
- [ ] Vérification des secrets créés
- [ ] Test d'accès aux applications

### Après Migration
- [ ] Audit de sécurité complet
- [ ] Configuration monitoring/alerting
- [ ] Documentation mise à jour
- [ ] Formation équipe sur nouveaux outils
- [ ] Plan de rotation des secrets

## 🔄 Maintenance Sécurité

### Tâches Quotidiennes
- Vérification alerts sécurité
- Review logs d'audit
- Monitoring certificats SSL

### Tâches Hebdomadaires
- Update images Docker
- Review RBAC permissions
- Backup verification

### Tâches Mensuelles
- Rotation credentials
- Security scanning complet
- Review et update policies
- Test procédures recovery

## 📞 Contacts Sécurité

**En cas d'incident** :
1. Isoler immédiatement
2. Documenter l'incident
3. Notifier équipe sécurité
4. Suivre procédure de recovery
5. Post-mortem et amélioration

---

**🛡️ La sécurité est un processus continu, pas un état final !**
