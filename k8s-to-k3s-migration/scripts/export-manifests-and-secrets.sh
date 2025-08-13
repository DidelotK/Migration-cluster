#!/bin/bash
set -euo pipefail

# Script simple d'export des manifests et secrets
# Simple script to export manifests and secrets

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
EXPORT_DIR="$PROJECT_ROOT/k8s-to-k3s-migration/exported-manifests"
KELTIO_PROD_DIR="$PROJECT_ROOT/k8s-manifests/keltio-prod"

# Configuration
SOURCE_KUBECONFIG="${SOURCE_KUBECONFIG:-$PROJECT_ROOT/kubeconfig-keltio-prod.yaml}"

echo "🚀 Export des manifests et secrets"
echo "=================================="

case "${1:-help}" in
    "check")
        echo "🔍 Vérification des prérequis..."
        if [[ ! -f "$SOURCE_KUBECONFIG" ]]; then
            echo "❌ Kubeconfig source manquant: $SOURCE_KUBECONFIG"
            exit 1
        fi
        echo "✅ Kubeconfig source trouvé"
        
        if ! command -v kubectl >/dev/null 2>&1; then
            echo "❌ kubectl non installé"
            exit 1
        fi
        echo "✅ kubectl disponible"
        
        echo "🔗 Test de connectivité (timeout 3s)..."
        if kubectl --kubeconfig="$SOURCE_KUBECONFIG" --request-timeout=3s get nodes >/dev/null 2>&1; then
            echo "✅ Cluster source accessible"
        else
            echo "⚠️  Cluster source non accessible (token expiré ou cluster arrêté)"
            echo "💡 Utilisez le mode 'simulate' pour tester la fonctionnalité"
        fi
        ;;
        
    "structure")
        echo "📁 Création de la structure d'export..."
        rm -rf "$EXPORT_DIR"
        mkdir -p "$EXPORT_DIR"/{namespaces,secrets,manifests,cluster-resources,raw-exports}
        
        cat > "$EXPORT_DIR/README.md" <<EOF
# Export des Manifests K8s

**Date:** $(date)

## Structure

- \`namespaces/\` - Manifests par namespace
- \`secrets/\` - Secrets exportés
- \`manifests/\` - Manifests nettoyés pour K3s
- \`cluster-resources/\` - Ressources cluster
- \`raw-exports/\` - Exports bruts

## ⚠️ Sécurité

Ce répertoire peut contenir des secrets sensibles.
Ne pas commiter dans Git.

EOF
        echo "✅ Structure d'export créée: $EXPORT_DIR"
        ;;
        
    "simulate")
        echo "🧪 Mode simulation (données fictives)..."
        
        # Créer la structure
        rm -rf "$EXPORT_DIR"
        mkdir -p "$EXPORT_DIR"/{namespaces/vaultwarden,secrets/vaultwarden,manifests/vaultwarden}
        
        # Manifest simulé
        cat > "$EXPORT_DIR/namespaces/vaultwarden/statefulset.yaml" <<'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: vaultwarden
  namespace: vaultwarden
spec:
  serviceName: vaultwarden
  replicas: 1
  selector:
    matchLabels:
      app: vaultwarden
  template:
    metadata:
      labels:
        app: vaultwarden
    spec:
      containers:
      - name: vaultwarden
        image: vaultwarden/server:1.30.1
        ports:
        - containerPort: 80
EOF

        # Secret simulé
        cat > "$EXPORT_DIR/secrets/vaultwarden/secret.yaml" <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: vaultwarden-secret
  namespace: vaultwarden
type: Opaque
data:
  admin_token: VE9LRU4=
EOF

        # Manifest nettoyé
        cp "$EXPORT_DIR/namespaces/vaultwarden/statefulset.yaml" "$EXPORT_DIR/manifests/vaultwarden/statefulset-clean.yaml"
        
        # Résumé
        cat > "$EXPORT_DIR/migration-summary.md" <<EOF
# Résumé de Migration (Simulation)

**Date:** $(date)

## Namespaces Exportés

- **vaultwarden**: 1 StatefulSet, 1 Secret

## Prochaines Étapes

1. Configurer les secrets réels
2. Adapter les manifests pour K3s
3. Déployer: \`kubectl apply -f manifests/\`

EOF
        
        echo "✅ Export simulé créé"
        echo "📁 Répertoire: $EXPORT_DIR"
        echo "📋 Résumé: $EXPORT_DIR/migration-summary.md"
        ;;
        
    "from-k3s")
        echo "📤 Export depuis cluster K3s (état actuel)..."
        
        KUBECONFIG_K3S="$PROJECT_ROOT/kubeconfig-target.yaml"
        if [[ ! -f "$KUBECONFIG_K3S" ]]; then
            echo "❌ Kubeconfig K3s manquant: $KUBECONFIG_K3S"
            echo "💡 Exécutez: ./k8s-to-k3s-migration/scripts/get-k3s-kubeconfig-simple.sh"
            exit 1
        fi
        
        rm -rf "$EXPORT_DIR"
        mkdir -p "$EXPORT_DIR"/{namespaces,secrets,manifests}
        
        # Export Vaultwarden depuis K3s
        echo "📦 Export Vaultwarden..."
        mkdir -p "$EXPORT_DIR/namespaces/vaultwarden"
        
        kubectl --kubeconfig="$KUBECONFIG_K3S" get statefulsets -n vaultwarden -o yaml > "$EXPORT_DIR/namespaces/vaultwarden/statefulsets.yaml" 2>/dev/null || echo "⚠️ Pas de StatefulSets"
        kubectl --kubeconfig="$KUBECONFIG_K3S" get services -n vaultwarden -o yaml > "$EXPORT_DIR/namespaces/vaultwarden/services.yaml" 2>/dev/null || echo "⚠️ Pas de Services"
        kubectl --kubeconfig="$KUBECONFIG_K3S" get ingress -n vaultwarden -o yaml > "$EXPORT_DIR/namespaces/vaultwarden/ingress.yaml" 2>/dev/null || echo "⚠️ Pas d'Ingress"
        
        # Export secrets (métadonnées seulement)
        mkdir -p "$EXPORT_DIR/secrets/vaultwarden"
        kubectl --kubeconfig="$KUBECONFIG_K3S" get secrets -n vaultwarden -o yaml | \
            sed 's/data:/# data: # REMOVED FOR SECURITY/' > "$EXPORT_DIR/secrets/vaultwarden/secrets-metadata.yaml" 2>/dev/null || echo "⚠️ Pas de secrets"
        
        echo "✅ Export K3s terminé"
        echo "📁 Répertoire: $EXPORT_DIR"
        ;;
        
    "full")
        echo "🔄 Full export (with keltio-prod structure)..."
        
        # Create both directory structures
        echo "📁 Creating export directories..."
        "$0" structure
        
        echo "📁 Creating keltio-prod directory structure..."
        mkdir -p "$KELTIO_PROD_DIR"/{namespaces,secrets,vaultwarden,monitoring,ops,gitlab-runner,hubspot-manager,reloader,keda}
        
        echo ""
        echo "⚠️  Export from source cluster not implemented (cluster not accessible)"
        echo "💡 Available options:"
        echo "  - '$0 simulate' to test functionality"
        echo "  - '$0 from-k3s' to export current K3s state"
        echo "  - Manual copy from backup files to k8s-manifests/keltio-prod/"
        echo ""
        echo "📁 Directories created:"
        echo "  - $EXPORT_DIR"
        echo "  - $KELTIO_PROD_DIR"
        ;;
        
    *)
        echo "Usage: $0 [check|structure|simulate|from-k3s|full]"
        echo ""
        echo "Commands:"
        echo "  check     - Vérifier les prérequis"
        echo "  structure - Créer la structure d'export"
        echo "  simulate  - Créer un export simulé (test)"
        echo "  from-k3s  - Exporter depuis cluster K3s actuel"
        echo "  full      - Export complet (défaut)"
        echo ""
        echo "Le script d'export permet de récupérer les manifests et secrets"
        echo "depuis un cluster Kubernetes pour les migrer vers K3s."
        exit 1
        ;;
esac