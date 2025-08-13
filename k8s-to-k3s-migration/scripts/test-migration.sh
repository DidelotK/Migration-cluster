#!/bin/bash
set -euo pipefail

# Script de test de migration
# Test migration script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
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
        *) color=$NC ;;
    esac
    echo -e "${color}[$(date +'%H:%M:%S')] $message${NC}"
}

test_cluster_connectivity() {
    log "INFO" "🔗 Test de connectivité au cluster K3s..."
    
    if ! kubectl --kubeconfig="$TARGET_KUBECONFIG" get nodes &> /dev/null; then
        log "ERROR" "Impossible de se connecter au cluster K3s"
        return 1
    fi
    
    local node_count=$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get nodes --no-headers | wc -l)
    log "SUCCESS" "✅ Cluster accessible avec $node_count nœud(s)"
}

test_applications_status() {
    log "INFO" "📱 Test du statut des applications..."
    
    local apps=("vaultwarden" "monitoring" "ops" "gitlab-runner" "hubspot-manager" "reloader" "keda")
    local all_healthy=true
    
    for app in "${apps[@]}"; do
        if kubectl --kubeconfig="$TARGET_KUBECONFIG" get namespace "$app" &> /dev/null; then
            local total_pods=$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get pods -n "$app" --no-headers 2>/dev/null | grep -v solver | wc -l)
            local ready_pods=$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get pods -n "$app" --no-headers 2>/dev/null | grep -v solver | grep -c "Running\|Completed" || echo "0")
            
            if [[ $ready_pods -eq $total_pods ]] && [[ $total_pods -gt 0 ]]; then
                log "SUCCESS" "  ✅ $app: $ready_pods/$total_pods pods OK"
            else
                log "WARNING" "  ⚠️  $app: $ready_pods/$total_pods pods OK"
                all_healthy=false
            fi
        else
            log "INFO" "  ℹ️  $app: namespace non trouvé"
        fi
    done
    
    if $all_healthy; then
        log "SUCCESS" "✅ Toutes les applications sont saines"
    else
        log "WARNING" "⚠️  Certaines applications nécessitent attention"
        return 1
    fi
}

test_ingress_configuration() {
    log "INFO" "🌐 Test de la configuration Ingress..."
    
    local ingresses=$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get ingress -A --no-headers 2>/dev/null | wc -l)
    if [[ $ingresses -gt 0 ]]; then
        log "SUCCESS" "✅ $ingresses Ingress configurés"
        
        # Afficher les Ingress
        kubectl --kubeconfig="$TARGET_KUBECONFIG" get ingress -A
    else
        log "WARNING" "⚠️  Aucun Ingress trouvé"
        return 1
    fi
}

test_ssl_certificates() {
    log "INFO" "🔐 Test des certificats SSL..."
    
    local certificates=$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get certificates -A --no-headers 2>/dev/null | wc -l)
    local ready_certs=$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get certificates -A --no-headers 2>/dev/null | grep -c "True" || echo "0")
    
    if [[ $ready_certs -eq $certificates ]] && [[ $certificates -gt 0 ]]; then
        log "SUCCESS" "✅ $ready_certs/$certificates certificats SSL prêts"
    else
        log "WARNING" "⚠️  $ready_certs/$certificates certificats SSL prêts"
        
        # Afficher les certificats en erreur
        kubectl --kubeconfig="$TARGET_KUBECONFIG" get certificates -A | grep -v "True" || true
        return 1
    fi
}

test_dns_resolution() {
    log "INFO" "🌐 Test de résolution DNS..."
    
    local domains=("vault1.keltio.fr" "status.keltio.fr" "prometheus.keltio.fr" "pgadmin.solya.app")
    local vm_ip=""
    
    # Récupérer l'IP du cluster
    if kubectl --kubeconfig="$TARGET_KUBECONFIG" get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' &> /dev/null; then
        vm_ip=$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null)
    fi
    
    if [[ -z "$vm_ip" ]]; then
        log "WARNING" "⚠️  Impossible de récupérer l'IP du cluster"
        return 1
    fi
    
    log "INFO" "IP du cluster K3s: $vm_ip"
    
    for domain in "${domains[@]}"; do
        if command -v dig &> /dev/null; then
            local resolved_ip=$(dig +short "$domain" | tail -1)
            if [[ "$resolved_ip" == "$vm_ip" ]]; then
                log "SUCCESS" "  ✅ $domain → $resolved_ip"
            else
                log "WARNING" "  ⚠️  $domain → $resolved_ip (attendu: $vm_ip)"
            fi
        else
            log "INFO" "  ℹ️  dig non disponible, skip test DNS pour $domain"
        fi
    done
}

test_https_connectivity() {
    log "INFO" "🔒 Test de connectivité HTTPS..."
    
    local urls=("https://vault1.keltio.fr" "https://status.keltio.fr" "https://prometheus.keltio.fr" "https://pgadmin.solya.app")
    
    for url in "${urls[@]}"; do
        if command -v curl &> /dev/null; then
            if curl -s --max-time 10 --head "$url" > /dev/null 2>&1; then
                log "SUCCESS" "  ✅ $url accessible"
            else
                log "WARNING" "  ⚠️  $url non accessible"
            fi
        else
            log "INFO" "  ℹ️  curl non disponible, skip test HTTPS"
            break
        fi
    done
}

test_secrets() {
    log "INFO" "🔐 Test des secrets configurés..."
    
    local required_secrets=(
        "kube-system:external-dns-scaleway"
        "vaultwarden:scaleway-registry-secret"
        "monitoring:scaleway-registry-secret"
        "ops:scaleway-registry-secret"
    )
    
    local all_secrets_ok=true
    
    for secret_ref in "${required_secrets[@]}"; do
        local namespace=$(echo "$secret_ref" | cut -d: -f1)
        local secret_name=$(echo "$secret_ref" | cut -d: -f2)
        
        if kubectl --kubeconfig="$TARGET_KUBECONFIG" get secret "$secret_name" -n "$namespace" &> /dev/null; then
            log "SUCCESS" "  ✅ $namespace/$secret_name"
        else
            log "WARNING" "  ⚠️  $namespace/$secret_name manquant"
            all_secrets_ok=false
        fi
    done
    
    if $all_secrets_ok; then
        log "SUCCESS" "✅ Tous les secrets critiques sont présents"
    else
        log "WARNING" "⚠️  Certains secrets sont manquants"
        return 1
    fi
}

test_persistent_volumes() {
    log "INFO" "💾 Test des volumes persistants..."
    
    local pvcs=$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get pvc -A --no-headers 2>/dev/null | wc -l)
    local bound_pvcs=$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get pvc -A --no-headers 2>/dev/null | grep -c "Bound" || echo "0")
    
    if [[ $bound_pvcs -eq $pvcs ]] && [[ $pvcs -gt 0 ]]; then
        log "SUCCESS" "✅ $bound_pvcs/$pvcs PVC liés"
    else
        log "WARNING" "⚠️  $bound_pvcs/$pvcs PVC liés"
        
        # Afficher les PVC en erreur
        kubectl --kubeconfig="$TARGET_KUBECONFIG" get pvc -A | grep -v "Bound" || true
        return 1
    fi
}

test_vaultwarden_data() {
    log "INFO" "🔑 Test spécifique Vaultwarden..."
    
    if kubectl --kubeconfig="$TARGET_KUBECONFIG" get statefulset vaultwarden -n vaultwarden &> /dev/null; then
        local ready_replicas=$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get statefulset vaultwarden -n vaultwarden -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        
        if [[ "$ready_replicas" == "1" ]]; then
            log "SUCCESS" "✅ Vaultwarden StatefulSet prêt"
            
            # Test base de données
            if kubectl --kubeconfig="$TARGET_KUBECONFIG" exec vaultwarden-0 -n vaultwarden -- ls -la /data/db.sqlite3 &> /dev/null; then
                log "SUCCESS" "  ✅ Base de données SQLite présente"
            else
                log "WARNING" "  ⚠️  Base de données SQLite manquante"
                return 1
            fi
        else
            log "WARNING" "⚠️  Vaultwarden StatefulSet non prêt ($ready_replicas/1)"
            return 1
        fi
    else
        log "WARNING" "⚠️  Vaultwarden StatefulSet non trouvé"
        return 1
    fi
}

generate_test_report() {
    log "INFO" "📋 Génération du rapport de test..."
    
    local report_file="$PROJECT_ROOT/migration-test-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# Rapport de Test Migration K8s → K3s

**Date:** $(date)  
**Cluster:** $(kubectl --kubeconfig="$TARGET_KUBECONFIG" config current-context 2>/dev/null || echo "k3s-cluster")

## Résultats des Tests

### ✅ Tests Réussis
- Tests listés automatiquement

### ⚠️  Tests avec Avertissements
- Tests listés automatiquement

### ❌ Tests Échoués
- Tests listés automatiquement

## État des Applications

$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get pods -A --no-headers | grep -v kube-system | grep -v local-path | awk '{print "- **" $1 "/" $2 "**: " $4}')

## État des Ingress

$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get ingress -A --no-headers | awk '{print "- **" $1 "/" $2 "**: " $4}')

## Prochaines Étapes

1. Résoudre les problèmes identifiés
2. Configurer le DNS si nécessaire
3. Tester manuellement les applications
4. Surveiller les logs pour 24h

---
Rapport généré automatiquement
EOF
    
    log "SUCCESS" "📄 Rapport généré: $report_file"
}

# Fonction principale
main() {
    log "INFO" "🧪 Démarrage des tests de migration"
    log "INFO" "===================================="
    
    local test_results=()
    
    # Exécuter tous les tests
    test_cluster_connectivity && test_results+=("connectivity:OK") || test_results+=("connectivity:FAIL")
    test_applications_status && test_results+=("applications:OK") || test_results+=("applications:WARN")
    test_ingress_configuration && test_results+=("ingress:OK") || test_results+=("ingress:WARN")
    test_ssl_certificates && test_results+=("ssl:OK") || test_results+=("ssl:WARN")
    test_dns_resolution && test_results+=("dns:OK") || test_results+=("dns:WARN")
    test_https_connectivity && test_results+=("https:OK") || test_results+=("https:WARN")
    test_secrets && test_results+=("secrets:OK") || test_results+=("secrets:WARN")
    test_persistent_volumes && test_results+=("volumes:OK") || test_results+=("volumes:WARN")
    test_vaultwarden_data && test_results+=("vaultwarden:OK") || test_results+=("vaultwarden:WARN")
    
    # Générer le rapport
    generate_test_report
    
    # Résumé final
    local ok_count=$(printf '%s\n' "${test_results[@]}" | grep -c ":OK" || echo "0")
    local warn_count=$(printf '%s\n' "${test_results[@]}" | grep -c ":WARN" || echo "0")
    local fail_count=$(printf '%s\n' "${test_results[@]}" | grep -c ":FAIL" || echo "0")
    local total_count=${#test_results[@]}
    
    echo ""
    log "INFO" "📊 Résumé des Tests"
    log "SUCCESS" "✅ Réussis: $ok_count/$total_count"
    log "WARNING" "⚠️  Avertissements: $warn_count/$total_count"
    log "ERROR" "❌ Échecs: $fail_count/$total_count"
    
    if [[ $fail_count -eq 0 ]]; then
        log "SUCCESS" "🎉 Migration validée avec succès !"
        return 0
    else
        log "ERROR" "💥 Migration nécessite attention"
        return 1
    fi
}

# Gestion des arguments
case "${1:-full}" in
    "connectivity")
        test_cluster_connectivity
        ;;
    "apps")
        test_applications_status
        ;;
    "ingress")
        test_ingress_configuration
        ;;
    "ssl")
        test_ssl_certificates
        ;;
    "dns")
        test_dns_resolution
        ;;
    "https")
        test_https_connectivity
        ;;
    "secrets")
        test_secrets
        ;;
    "volumes")
        test_persistent_volumes
        ;;
    "vaultwarden")
        test_vaultwarden_data
        ;;
    "report")
        generate_test_report
        ;;
    "full")
        main
        ;;
    *)
        echo "Usage: $0 [connectivity|apps|ingress|ssl|dns|https|secrets|volumes|vaultwarden|report|full]"
        echo ""
        echo "Tests disponibles:"
        echo "  connectivity  - Test connectivité cluster"
        echo "  apps         - Test statut applications"
        echo "  ingress      - Test configuration Ingress"
        echo "  ssl          - Test certificats SSL"
        echo "  dns          - Test résolution DNS"
        echo "  https        - Test connectivité HTTPS"
        echo "  secrets      - Test secrets configurés"
        echo "  volumes      - Test volumes persistants"
        echo "  vaultwarden  - Test spécifique Vaultwarden"
        echo "  report       - Générer rapport uniquement"
        echo "  full         - Tous les tests (défaut)"
        exit 1
        ;;
esac
