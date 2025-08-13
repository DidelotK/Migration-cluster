#!/bin/bash
set -euo pipefail

# Script pour configurer les secrets sur K3s
# Setup secrets for K3s cluster

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
EXPORT_DIR="$PROJECT_ROOT/k8s-to-k3s-migration/exported-manifests"

# Kubeconfig pour le cluster K3s
TARGET_KUBECONFIG="${TARGET_KUBECONFIG:-$PROJECT_ROOT/kubeconfig-target.yaml}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local level=$1
    local message=$2
    local color
    case $level in
        "ERROR") color=$RED ;;
        "SUCCESS") color=$GREEN ;;
        "WARNING") color=$YELLOW ;;
        "INFO") color=$BLUE ;;
        *) color=$NC ;;
    esac
    echo -e "${color}[$(date +'%H:%M:%S')] $message${NC}"
}

check_prerequisites() {
    log "INFO" "🔍 Vérification des prérequis..."
    
    if ! command -v kubectl &> /dev/null; then
        log "ERROR" "kubectl n'est pas installé"
        exit 1
    fi
    
    if [[ ! -f "$TARGET_KUBECONFIG" ]]; then
        log "ERROR" "Kubeconfig K3s introuvable: $TARGET_KUBECONFIG"
        log "INFO" "Veuillez fournir le kubeconfig du cluster K3s"
        exit 1
    fi
    
    if [[ ! -d "$EXPORT_DIR" ]]; then
        log "ERROR" "Répertoire d'export introuvable: $EXPORT_DIR"
        log "INFO" "Veuillez d'abord exporter les manifests avec export-manifests-and-secrets.sh"
        exit 1
    fi
    
    # Test de connectivité K3s
    if ! kubectl --kubeconfig="$TARGET_KUBECONFIG" get nodes &> /dev/null; then
        log "ERROR" "Impossible de se connecter au cluster K3s"
        exit 1
    fi
    
    log "SUCCESS" "✅ Prérequis validés"
}

create_docker_registry_secret() {
    log "INFO" "🐳 Configuration du secret Docker Registry Scaleway..."
    
    # Vérifier les variables d'environnement
    if [[ -z "${SCW_SECRET_KEY:-}" ]]; then
        log "ERROR" "Variable SCW_SECRET_KEY manquante"
        log "INFO" "Configurez vos credentials Scaleway dans .envrc puis exécutez 'direnv allow'"
        return 1
    fi
    
    # Créer le dockerconfig.json
    local docker_auth=$(echo -n "nologin:${SCW_SECRET_KEY}" | base64 -w 0)
    local docker_config_json=$(cat <<EOF
{
    "auths": {
        "rg.fr-par.scw.cloud": {
            "auth": "${docker_auth}"
        }
    }
}
EOF
)
    
    # Namespaces qui ont besoin du secret Docker
    local namespaces=("vaultwarden" "hubspot-manager" "ops" "monitoring" "gitlab-runner")
    
    for namespace in "${namespaces[@]}"; do
        log "INFO" "  📦 Création du secret dans $namespace..."
        
        # Créer le namespace s'il n'existe pas
        kubectl --kubeconfig="$TARGET_KUBECONFIG" create namespace "$namespace" --dry-run=client -o yaml | \
            kubectl --kubeconfig="$TARGET_KUBECONFIG" apply -f - &> /dev/null || true
        
        # Supprimer le secret s'il existe
        kubectl --kubeconfig="$TARGET_KUBECONFIG" delete secret scaleway-registry-secret -n "$namespace" --ignore-not-found
        
        # Créer le nouveau secret
        kubectl --kubeconfig="$TARGET_KUBECONFIG" create secret docker-registry scaleway-registry-secret \
            --docker-server=rg.fr-par.scw.cloud \
            --docker-username=nologin \
            --docker-password="${SCW_SECRET_KEY}" \
            -n "$namespace" || {
            log "ERROR" "Erreur lors de la création du secret Docker dans $namespace"
            return 1
        }
        
        log "SUCCESS" "  ✅ Secret Docker créé dans $namespace"
    done
    
    log "SUCCESS" "✅ Secrets Docker Registry configurés"
}

create_external_dns_secret() {
    log "INFO" "🌐 Configuration du secret External DNS..."
    
    # Vérifier les variables d'environnement Scaleway
    local required_vars=("SCW_ACCESS_KEY" "SCW_SECRET_KEY" "SCW_ORGANIZATION_ID" "SCW_PROJECT_ID")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log "ERROR" "Variable $var manquante"
            log "INFO" "Configurez vos credentials Scaleway dans .envrc"
            return 1
        fi
    done
    
    # Créer le namespace kube-system s'il n'existe pas
    kubectl --kubeconfig="$TARGET_KUBECONFIG" create namespace kube-system --dry-run=client -o yaml | \
        kubectl --kubeconfig="$TARGET_KUBECONFIG" apply -f - &> /dev/null || true
    
    # Supprimer le secret s'il existe
    kubectl --kubeconfig="$TARGET_KUBECONFIG" delete secret external-dns-scaleway -n kube-system --ignore-not-found
    
    # Créer le secret External DNS
    kubectl --kubeconfig="$TARGET_KUBECONFIG" create secret generic external-dns-scaleway \
        --from-literal=access-key="${SCW_ACCESS_KEY}" \
        --from-literal=secret-key="${SCW_SECRET_KEY}" \
        --from-literal=organization-id="${SCW_ORGANIZATION_ID}" \
        --from-literal=project-id="${SCW_PROJECT_ID}" \
        -n kube-system || {
        log "ERROR" "Erreur lors de la création du secret External DNS"
        return 1
    }
    
    log "SUCCESS" "✅ Secret External DNS configuré"
}

apply_exported_secrets() {
    log "INFO" "🔐 Application des secrets exportés..."
    
    # Parcourir tous les namespaces exportés
    for secrets_dir in "$EXPORT_DIR/secrets"/*; do
        if [[ -d "$secrets_dir" ]]; then
            local namespace=$(basename "$secrets_dir")
            
            log "INFO" "  📦 Configuration des secrets pour $namespace..."
            
            # Créer le namespace s'il n'existe pas
            kubectl --kubeconfig="$TARGET_KUBECONFIG" create namespace "$namespace" --dry-run=client -o yaml | \
                kubectl --kubeconfig="$TARGET_KUBECONFIG" apply -f - &> /dev/null || true
            
            # Appliquer tous les secrets du namespace (sauf les tokens par défaut)
            for secret_file in "$secrets_dir"/*.yaml; do
                if [[ -f "$secret_file" ]] && [[ ! "$(basename "$secret_file")" =~ ^default-token-|^sh\.helm\.|all-secrets\.yaml ]]; then
                    local secret_name=$(basename "$secret_file" .yaml)
                    
                    log "INFO" "    🔑 Application du secret: $secret_name"
                    
                    # Nettoyer le secret (supprimer les champs auto-générés)
                    yq eval 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.managedFields)' "$secret_file" | \
                        kubectl --kubeconfig="$TARGET_KUBECONFIG" apply -f - || {
                        log "WARNING" "    ⚠️ Erreur lors de l'application du secret $secret_name"
                    }
                fi
            done
            
            log "SUCCESS" "  ✅ Secrets configurés pour $namespace"
        fi
    done
    
    log "SUCCESS" "✅ Secrets exportés appliqués"
}

create_custom_secrets() {
    log "INFO" "🔧 Création des secrets personnalisés..."
    
    # Secret pour Vaultwarden Admin (si nécessaire)
    create_vaultwarden_admin_secret
    
    # Secret pour HubSpot Manager Slack (si nécessaire)
    create_slack_secret
    
    # Secret pour GitLab Runner (si nécessaire)
    create_gitlab_runner_secret
    
    log "SUCCESS" "✅ Secrets personnalisés créés"
}

create_vaultwarden_admin_secret() {
    log "INFO" "  🔐 Création du secret Vaultwarden Admin..."
    
    # Vérifier si Vaultwarden a besoin d'un token admin personnalisé
    if [[ -z "${VAULTWARDEN_ADMIN_TOKEN:-}" ]]; then
        log "INFO" "    ℹ️ VAULTWARDEN_ADMIN_TOKEN non défini, utilisation du secret exporté"
        return 0
    fi
    
    kubectl --kubeconfig="$TARGET_KUBECONFIG" create namespace vaultwarden --dry-run=client -o yaml | \
        kubectl --kubeconfig="$TARGET_KUBECONFIG" apply -f - &> /dev/null || true
    
    # Supprimer le secret s'il existe
    kubectl --kubeconfig="$TARGET_KUBECONFIG" delete secret vaultwarden-admin-token -n vaultwarden --ignore-not-found
    
    # Créer le nouveau secret admin
    kubectl --kubeconfig="$TARGET_KUBECONFIG" create secret generic vaultwarden-admin-token \
        --from-literal=admin-token="${VAULTWARDEN_ADMIN_TOKEN}" \
        -n vaultwarden || {
        log "WARNING" "    ⚠️ Erreur lors de la création du secret admin Vaultwarden"
        return 1
    }
    
    log "SUCCESS" "    ✅ Secret admin Vaultwarden créé"
}

create_slack_secret() {
    log "INFO" "  💬 Création du secret Slack Bot..."
    
    # Vérifier les variables Slack
    if [[ -z "${SLACK_BOT_TOKEN:-}" ]] || [[ -z "${SLACK_CHANNEL:-}" ]]; then
        log "INFO" "    ℹ️ Variables Slack non définies, utilisation du secret exporté"
        return 0
    fi
    
    kubectl --kubeconfig="$TARGET_KUBECONFIG" create namespace hubspot-manager --dry-run=client -o yaml | \
        kubectl --kubeconfig="$TARGET_KUBECONFIG" apply -f - &> /dev/null || true
    
    # Supprimer le secret s'il existe
    kubectl --kubeconfig="$TARGET_KUBECONFIG" delete secret slack-bot-credentials -n hubspot-manager --ignore-not-found
    
    # Créer le nouveau secret Slack
    kubectl --kubeconfig="$TARGET_KUBECONFIG" create secret generic slack-bot-credentials \
        --from-literal=SLACK_BOT_TOKEN="${SLACK_BOT_TOKEN}" \
        --from-literal=SLACK_CHANNEL="${SLACK_CHANNEL}" \
        --from-literal=SLACK_CHANNEL_ID="${SLACK_CHANNEL_ID:-}" \
        --from-literal=SLACK_CHANNEL_ID_OPS="${SLACK_CHANNEL_ID_OPS:-}" \
        -n hubspot-manager || {
        log "WARNING" "    ⚠️ Erreur lors de la création du secret Slack"
        return 1
    }
    
    log "SUCCESS" "    ✅ Secret Slack Bot créé"
}

create_gitlab_runner_secret() {
    log "INFO" "  🦊 Création du secret GitLab Runner..."
    
    if [[ -z "${GITLAB_RUNNER_TOKEN:-}" ]]; then
        log "INFO" "    ℹ️ GITLAB_RUNNER_TOKEN non défini, utilisation du secret exporté"
        return 0
    fi
    
    kubectl --kubeconfig="$TARGET_KUBECONFIG" create namespace gitlab-runner --dry-run=client -o yaml | \
        kubectl --kubeconfig="$TARGET_KUBECONFIG" apply -f - &> /dev/null || true
    
    # Supprimer le secret s'il existe
    kubectl --kubeconfig="$TARGET_KUBECONFIG" delete secret gitlab-runner-token -n gitlab-runner --ignore-not-found
    
    # Créer le nouveau secret GitLab Runner
    kubectl --kubeconfig="$TARGET_KUBECONFIG" create secret generic gitlab-runner-token \
        --from-literal=runner-token="${GITLAB_RUNNER_TOKEN}" \
        -n gitlab-runner || {
        log "WARNING" "    ⚠️ Erreur lors de la création du secret GitLab Runner"
        return 1
    }
    
    log "SUCCESS" "    ✅ Secret GitLab Runner créé"
}

validate_secrets() {
    log "INFO" "🔍 Validation des secrets..."
    
    local namespaces=("vaultwarden" "hubspot-manager" "ops" "monitoring" "gitlab-runner" "kube-system")
    
    for namespace in "${namespaces[@]}"; do
        if kubectl --kubeconfig="$TARGET_KUBECONFIG" get namespace "$namespace" &> /dev/null; then
            local secret_count=$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get secrets -n "$namespace" --no-headers 2>/dev/null | grep -v default-token | wc -l)
            log "INFO" "  📦 $namespace: $secret_count secrets configurés"
        fi
    done
    
    log "SUCCESS" "✅ Validation des secrets terminée"
}

display_summary() {
    log "INFO" "📋 Résumé de la configuration des secrets"
    echo ""
    echo "Secrets configurés:"
    echo "  🐳 Docker Registry (Scaleway) - Tous les namespaces d'applications"
    echo "  🌐 External DNS (Scaleway) - kube-system"
    echo "  🔐 Secrets exportés - Tous les namespaces"
    echo ""
    echo "Variables d'environnement utilisées:"
    echo "  SCW_ACCESS_KEY: ${SCW_ACCESS_KEY:+✅ Défini}${SCW_ACCESS_KEY:-❌ Manquant}"
    echo "  SCW_SECRET_KEY: ${SCW_SECRET_KEY:+✅ Défini}${SCW_SECRET_KEY:-❌ Manquant}"
    echo "  SCW_ORGANIZATION_ID: ${SCW_ORGANIZATION_ID:+✅ Défini}${SCW_ORGANIZATION_ID:-❌ Manquant}"
    echo "  SCW_PROJECT_ID: ${SCW_PROJECT_ID:+✅ Défini}${SCW_PROJECT_ID:-❌ Manquant}"
    echo ""
    echo "Secrets optionnels:"
    echo "  VAULTWARDEN_ADMIN_TOKEN: ${VAULTWARDEN_ADMIN_TOKEN:+✅ Défini}${VAULTWARDEN_ADMIN_TOKEN:-ℹ️ Utilisation du secret exporté}"
    echo "  SLACK_BOT_TOKEN: ${SLACK_BOT_TOKEN:+✅ Défini}${SLACK_BOT_TOKEN:-ℹ️ Utilisation du secret exporté}"
    echo "  GITLAB_RUNNER_TOKEN: ${GITLAB_RUNNER_TOKEN:+✅ Défini}${GITLAB_RUNNER_TOKEN:-ℹ️ Utilisation du secret exporté}"
    echo ""
}

# Fonction principale
main() {
    log "INFO" "🚀 Configuration des secrets pour K3s"
    log "INFO" "===================================="
    
    check_prerequisites
    
    # Configuration des secrets de base
    create_docker_registry_secret
    create_external_dns_secret
    
    # Application des secrets exportés
    if [[ -d "$EXPORT_DIR/secrets" ]]; then
        apply_exported_secrets
    else
        log "WARNING" "⚠️ Aucun secret exporté trouvé, création des secrets personnalisés uniquement"
    fi
    
    # Secrets personnalisés si nécessaire
    create_custom_secrets
    
    # Validation
    validate_secrets
    
    # Résumé
    display_summary
    
    log "SUCCESS" "🎉 Configuration des secrets terminée !"
    log "INFO" "💡 Les applications peuvent maintenant accéder aux ressources Scaleway"
}

# Gestion des arguments
case "${1:-full}" in
    "check")
        check_prerequisites
        ;;
    "docker")
        check_prerequisites
        create_docker_registry_secret
        ;;
    "external-dns")
        check_prerequisites
        create_external_dns_secret
        ;;
    "exported")
        check_prerequisites
        apply_exported_secrets
        ;;
    "custom")
        check_prerequisites
        create_custom_secrets
        ;;
    "validate")
        check_prerequisites
        validate_secrets
        ;;
    "full")
        main
        ;;
    *)
        echo "Usage: $0 [check|docker|external-dns|exported|custom|validate|full]"
        echo ""
        echo "Commands:"
        echo "  check        - Vérifier les prérequis"
        echo "  docker       - Configurer le secret Docker Registry"
        echo "  external-dns - Configurer le secret External DNS"
        echo "  exported     - Appliquer les secrets exportés"
        echo "  custom       - Créer les secrets personnalisés"
        echo "  validate     - Valider les secrets"
        echo "  full         - Configuration complète (défaut)"
        exit 1
        ;;
esac
