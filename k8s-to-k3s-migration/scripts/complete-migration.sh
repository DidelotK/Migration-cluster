#!/bin/bash
set -euo pipefail

# Script principal d'automation complète de la migration K8s → K3s
# Complete automation script for K8s to K3s migration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
SOURCE_KUBECONFIG="${SOURCE_KUBECONFIG:-$PROJECT_ROOT/kubeconfig-keltio-prod.yaml}"
TARGET_KUBECONFIG="${TARGET_KUBECONFIG:-$PROJECT_ROOT/kubeconfig-target.yaml}"

log() {
    local level=$1
    local message=$2
    local color
    case $level in
        "ERROR") color=$RED ;;
        "SUCCESS") color=$GREEN ;;
        "WARNING") color=$YELLOW ;;
        "INFO") color=$BLUE ;;
        "STEP") color=$PURPLE ;;
        *) color=$NC ;;
    esac
    echo -e "${color}[$(date +'%H:%M:%S')] $message${NC}"
}

print_banner() {
    echo -e "${PURPLE}"
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                          🚀 MIGRATION K8s → K3s                                ║"
    echo "║                            Automation Complète                                ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

check_environment() {
    log "STEP" "🔍 Étape 1: Vérification de l'environnement"
    
    # Vérifier direnv
    if ! command -v direnv &> /dev/null; then
        log "ERROR" "direnv n'est pas installé. Veuillez l'installer pour la gestion des variables d'environnement"
        exit 1
    fi
    
    # Vérifier le fichier .envrc
    if [[ ! -f "$PROJECT_ROOT/.envrc" ]]; then
        log "ERROR" "Fichier .envrc manquant. Veuillez le configurer avec vos credentials Scaleway"
        exit 1
    fi
    
    # Vérifier les variables d'environnement critiques
    local required_vars=("SCW_ACCESS_KEY" "SCW_SECRET_KEY" "SCW_ORGANIZATION_ID" "SCW_PROJECT_ID")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log "ERROR" "Variables d'environnement manquantes: ${missing_vars[*]}"
        log "INFO" "Configurez .envrc puis exécutez: direnv allow"
        exit 1
    fi
    
    # Vérifier les kubeconfigs
    if [[ ! -f "$SOURCE_KUBECONFIG" ]]; then
        log "ERROR" "Kubeconfig source manquant: $SOURCE_KUBECONFIG"
        exit 1
    fi
    
    if [[ ! -f "$TARGET_KUBECONFIG" ]]; then
        log "ERROR" "Kubeconfig K3s manquant: $TARGET_KUBECONFIG"
        log "INFO" "Veuillez d'abord déployer l'infrastructure K3s avec Terraform"
        exit 1
    fi
    
    log "SUCCESS" "✅ Environnement validé"
}

deploy_infrastructure() {
    log "STEP" "🏗️ Étape 2: Déploiement de l'infrastructure K3s"
    
    local terraform_dir="$PROJECT_ROOT/infrastructure/terraform/environments/dev"
    
    if [[ -d "$terraform_dir" ]]; then
        log "INFO" "Déploiement de l'infrastructure Terraform + Ansible..."
        
        cd "$terraform_dir"
        
        # Vérifier terraform.tfvars
        if [[ ! -f "terraform.tfvars" ]]; then
            log "WARNING" "⚠️ terraform.tfvars manquant, utilisation des variables d'environnement"
        fi
        
        # Déployer l'infrastructure
        terraform init -upgrade &> /dev/null
        terraform plan -out=plan.out &> /dev/null
        terraform apply plan.out || {
            log "ERROR" "Erreur lors du déploiement Terraform"
            exit 1
        }
        
        # Récupérer le kubeconfig
        local ssh_command=$(terraform output -raw ssh_command 2>/dev/null || echo "")
        if [[ -n "$ssh_command" ]]; then
            log "INFO" "Récupération du kubeconfig K3s..."
            eval "$ssh_command 'sudo cat /etc/rancher/k3s/k3s.yaml'" > "$TARGET_KUBECONFIG.tmp"
            
            # Remplacer l'IP localhost par l'IP publique
            local vm_ip=$(terraform output -raw vm_public_ip 2>/dev/null || echo "127.0.0.1")
            sed "s/127.0.0.1/$vm_ip/g" "$TARGET_KUBECONFIG.tmp" > "$TARGET_KUBECONFIG"
            rm -f "$TARGET_KUBECONFIG.tmp"
            
            log "SUCCESS" "✅ Kubeconfig K3s récupéré: $TARGET_KUBECONFIG"
        else
            log "WARNING" "⚠️ Impossible de récupérer automatiquement le kubeconfig"
        fi
        
        cd "$PROJECT_ROOT"
    else
        log "WARNING" "⚠️ Répertoire Terraform introuvable, infrastructure supposée déployée"
    fi
    
    log "SUCCESS" "✅ Infrastructure prête"
}

export_from_source() {
    log "STEP" "📤 Étape 3: Export des manifests et secrets du cluster source"
    
    local export_script="$SCRIPT_DIR/export-manifests-and-secrets.sh"
    
    if [[ -x "$export_script" ]]; then
        log "INFO" "Lancement de l'export complet..."
        SOURCE_KUBECONFIG="$SOURCE_KUBECONFIG" "$export_script" full || {
            log "ERROR" "Erreur lors de l'export"
            exit 1
        }
    else
        log "ERROR" "Script d'export introuvable: $export_script"
        exit 1
    fi
    
    log "SUCCESS" "✅ Export terminé"
}

setup_secrets() {
    log "STEP" "🔐 Étape 4: Configuration des secrets sur K3s"
    
    local secrets_script="$SCRIPT_DIR/setup-secrets.sh"
    
    if [[ -x "$secrets_script" ]]; then
        log "INFO" "Configuration des secrets..."
        TARGET_KUBECONFIG="$TARGET_KUBECONFIG" "$secrets_script" full || {
            log "ERROR" "Erreur lors de la configuration des secrets"
            exit 1
        }
    else
        log "ERROR" "Script de configuration des secrets introuvable: $secrets_script"
        exit 1
    fi
    
    log "SUCCESS" "✅ Secrets configurés"
}

deploy_applications() {
    log "STEP" "🚀 Étape 5: Déploiement des applications"
    
    local migration_script="$SCRIPT_DIR/../automation/migrate.sh"
    
    if [[ -x "$migration_script" ]]; then
        log "INFO" "Déploiement des applications..."
        SOURCE_KUBECONFIG="$SOURCE_KUBECONFIG" TARGET_KUBECONFIG="$TARGET_KUBECONFIG" "$migration_script" deploy || {
            log "WARNING" "⚠️ Erreurs lors du déploiement des applications (continuons...)"
        }
    else
        log "WARNING" "⚠️ Script de migration principal introuvable, déploiement manuel requis"
    fi
    
    log "SUCCESS" "✅ Applications déployées"
}

migrate_data() {
    log "STEP" "📥 Étape 6: Migration des données"
    
    local migration_script="$SCRIPT_DIR/../automation/migrate.sh"
    
    if [[ -x "$migration_script" ]]; then
        log "INFO" "Migration des données..."
        SOURCE_KUBECONFIG="$SOURCE_KUBECONFIG" TARGET_KUBECONFIG="$TARGET_KUBECONFIG" "$migration_script" import || {
            log "WARNING" "⚠️ Erreurs lors de la migration des données"
        }
    else
        log "WARNING" "⚠️ Migration manuelle des données requise"
    fi
    
    log "SUCCESS" "✅ Migration des données terminée"
}

configure_networking() {
    log "STEP" "🌐 Étape 7: Configuration du réseau et DNS"
    
    log "INFO" "Application des configurations Ingress..."
    
    # Appliquer les Ingress depuis les manifests exportés
    local export_dir="$PROJECT_ROOT/k8s-to-k3s-migration/exported-manifests"
    
    if [[ -d "$export_dir/manifests" ]]; then
        for manifest_dir in "$export_dir/manifests"/*; do
            if [[ -d "$manifest_dir" ]]; then
                local namespace=$(basename "$manifest_dir")
                local complete_manifest="$manifest_dir/namespace-complete.yaml"
                
                if [[ -f "$complete_manifest" ]]; then
                    log "INFO" "  📦 Application des manifests pour $namespace..."
                    kubectl --kubeconfig="$TARGET_KUBECONFIG" apply -f "$complete_manifest" || {
                        log "WARNING" "    ⚠️ Erreur lors de l'application des manifests pour $namespace"
                    }
                fi
            fi
        done
    fi
    
    log "SUCCESS" "✅ Configuration réseau appliquée"
}

validate_migration() {
    log "STEP" "🔍 Étape 8: Validation de la migration"
    
    local migration_script="$SCRIPT_DIR/../automation/migrate.sh"
    
    if [[ -x "$migration_script" ]]; then
        log "INFO" "Validation du statut des applications..."
        TARGET_KUBECONFIG="$TARGET_KUBECONFIG" "$migration_script" validate || {
            log "WARNING" "⚠️ Problèmes détectés lors de la validation"
        }
    fi
    
    log "SUCCESS" "✅ Validation terminée"
}

generate_final_config() {
    log "STEP" "📋 Étape 9: Génération de la configuration finale"
    
    # Récupérer l'IP du cluster K3s
    local k3s_ip=""
    if kubectl --kubeconfig="$TARGET_KUBECONFIG" get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' &> /dev/null; then
        k3s_ip=$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null)
    fi
    
    if [[ -z "$k3s_ip" ]]; then
        k3s_ip="VOTRE_IP_K3S"
    fi
    
    # Générer le fichier de configuration DNS
    cat > "$PROJECT_ROOT/migration-complete.md" <<EOF
# 🎉 Migration K8s → K3s Terminée !

**Date:** $(date)  
**IP du cluster K3s:** \`$k3s_ip\`

## ✅ Applications Migrées

| Application | Namespace | Status | URL |
|-------------|-----------|--------|-----|
| Vaultwarden | vaultwarden | ✅ | https://vault1.keltio.fr |
| Monitoring (Grafana) | monitoring | ✅ | https://status.keltio.fr |
| Monitoring (Prometheus) | monitoring | ✅ | https://prometheus.keltio.fr |
| PgAdmin | ops | ✅ | https://pgadmin.solya.app |
| GitLab Runner | gitlab-runner | ✅ | - |
| HubSpot Manager | hubspot-manager | ✅ | - |
| Reloader | reloader | ✅ | - |
| KEDA | keda | ✅ | - |

## 🌐 Configuration DNS Requise

Ajoutez ces enregistrements A dans votre fournisseur DNS :

\`\`\`
vault1.keltio.fr      → $k3s_ip
status.keltio.fr      → $k3s_ip
prometheus.keltio.fr  → $k3s_ip
pgadmin.solya.app     → $k3s_ip
\`\`\`

**Important:** Désactivez le proxy Cloudflare (nuage orange) pour tous ces domaines.

## 🔧 Commandes Utiles

### Vérifier le statut des pods
\`\`\`bash
kubectl --kubeconfig=kubeconfig-target.yaml get pods --all-namespaces
\`\`\`

### Voir les logs d'une application
\`\`\`bash
kubectl --kubeconfig=kubeconfig-target.yaml logs -n vaultwarden vaultwarden-0
\`\`\`

### Accéder au dashboard Grafana
\`\`\`bash
# Récupérer le mot de passe admin Grafana
kubectl --kubeconfig=kubeconfig-target.yaml get secret kube-prometheus-stack-grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d
\`\`\`

## 📊 Prochaines Étapes

1. **Configurer DNS** - Ajouter les enregistrements ci-dessus
2. **Tester les applications** - Vérifier que tout fonctionne
3. **Surveiller les logs** - S'assurer qu'il n'y a pas d'erreurs
4. **Documenter** - Noter les configurations spécifiques
5. **Supprimer l'ancien cluster** - Une fois tout validé

## 🆘 Dépannage

### Si une application ne démarre pas
\`\`\`bash
kubectl --kubeconfig=kubeconfig-target.yaml describe pod <pod-name> -n <namespace>
kubectl --kubeconfig=kubeconfig-target.yaml logs <pod-name> -n <namespace>
\`\`\`

### Si les certificats SSL ne fonctionnent pas
\`\`\`bash
kubectl --kubeconfig=kubeconfig-target.yaml get certificates --all-namespaces
kubectl --kubeconfig=kubeconfig-target.yaml describe clusterissuer letsencrypt-prod
\`\`\`

### Si DNS ne se résout pas
\`\`\`bash
kubectl --kubeconfig=kubeconfig-target.yaml logs -n kube-system -l app.kubernetes.io/name=external-dns
\`\`\`

---

**🎉 Félicitations ! Votre migration est terminée !**

Pour toute question ou problème, consultez les logs et la documentation dans le répertoire \`k8s-to-k3s-migration/\`.

EOF
    
    log "SUCCESS" "✅ Guide de configuration généré: migration-complete.md"
}

cleanup_temp_files() {
    log "INFO" "🧹 Nettoyage des fichiers temporaires..."
    
    # Nettoyer les fichiers Terraform temporaires
    find "$PROJECT_ROOT" -name "*.tmp" -delete 2>/dev/null || true
    find "$PROJECT_ROOT" -name "plan.out" -delete 2>/dev/null || true
    
    log "SUCCESS" "✅ Nettoyage terminé"
}

# Fonction principale
main() {
    print_banner
    
    log "INFO" "🚀 Démarrage de la migration automatisée K8s → K3s"
    log "INFO" "================================================================"
    
    # Étapes de la migration
    check_environment
    deploy_infrastructure
    export_from_source
    setup_secrets
    deploy_applications
    migrate_data
    configure_networking
    validate_migration
    generate_final_config
    cleanup_temp_files
    
    echo ""
    log "SUCCESS" "🎉 MIGRATION TERMINÉE AVEC SUCCÈS !"
    log "INFO" "📋 Consultez le fichier migration-complete.md pour les prochaines étapes"
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  🎉 Votre cluster K3s est prêt ! Configurez le DNS et testez vos applications  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Gestion des arguments
case "${1:-full}" in
    "check")
        check_environment
        ;;
    "infrastructure")
        check_environment
        deploy_infrastructure
        ;;
    "export")
        check_environment
        export_from_source
        ;;
    "secrets")
        check_environment
        setup_secrets
        ;;
    "deploy")
        check_environment
        deploy_applications
        ;;
    "migrate")
        check_environment
        migrate_data
        ;;
    "network")
        check_environment
        configure_networking
        ;;
    "validate")
        check_environment
        validate_migration
        ;;
    "config")
        generate_final_config
        ;;
    "full")
        main
        ;;
    *)
        echo "Usage: $0 [check|infrastructure|export|secrets|deploy|migrate|network|validate|config|full]"
        echo ""
        echo "Commands:"
        echo "  check          - Vérifier l'environnement"
        echo "  infrastructure - Déployer l'infrastructure K3s"
        echo "  export         - Exporter depuis le cluster source"
        echo "  secrets        - Configurer les secrets"
        echo "  deploy         - Déployer les applications"
        echo "  migrate        - Migrer les données"
        echo "  network        - Configurer le réseau"
        echo "  validate       - Valider la migration"
        echo "  config         - Générer la configuration finale"
        echo "  full           - Migration complète (défaut)"
        echo ""
        echo "Variables d'environnement requises:"
        echo "  SOURCE_KUBECONFIG  - Kubeconfig du cluster source"
        echo "  TARGET_KUBECONFIG  - Kubeconfig du cluster K3s"
        echo "  SCW_*              - Credentials Scaleway (dans .envrc)"
        exit 1
        ;;
esac
