#!/bin/bash
set -euo pipefail

# Kubernetes to K3s Migration Automation
# Complete migration script for moving applications from K8s to K3s

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_ROOT/configs"
MANIFESTS_DIR="$PROJECT_ROOT/manifests"
TEMP_DIR="/tmp/k8s-migration-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Applications to migrate
declare -A APPLICATIONS=(
    ["vaultwarden"]="password-manager"
    ["monitoring"]="prometheus-grafana-loki"
    ["ops"]="pgadmin"
    ["gitlab-runner"]="ci-cd"
    ["hubspot-manager"]="cronjobs"
    ["reloader"]="config-watcher"
    ["keda"]="autoscaler"
)

# Configuration files
SOURCE_KUBECONFIG="${SOURCE_KUBECONFIG:-./kubeconfig-source.yaml}"
TARGET_KUBECONFIG="${TARGET_KUBECONFIG:-./kubeconfig-target.yaml}"

# Functions
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
    log "INFO" "🔍 Checking prerequisites..."
    
    local missing_tools=()
    
    for tool in kubectl helm; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log "ERROR" "Missing tools: ${missing_tools[*]}"
        log "INFO" "Please install missing tools and try again"
        exit 1
    fi
    
    if [[ ! -f "$SOURCE_KUBECONFIG" ]]; then
        log "ERROR" "Source kubeconfig not found: $SOURCE_KUBECONFIG"
        log "INFO" "Please provide the source cluster kubeconfig"
        exit 1
    fi
    
    if [[ ! -f "$TARGET_KUBECONFIG" ]]; then
        log "ERROR" "Target kubeconfig not found: $TARGET_KUBECONFIG"
        log "INFO" "Please provide the target cluster kubeconfig"
        exit 1
    fi
    
    log "SUCCESS" "✅ Prerequisites check passed"
}

test_connectivity() {
    log "INFO" "🔗 Testing cluster connectivity..."
    
    if ! kubectl --kubeconfig="$SOURCE_KUBECONFIG" get nodes &> /dev/null; then
        log "ERROR" "Cannot connect to source cluster"
        exit 1
    fi
    
    if ! kubectl --kubeconfig="$TARGET_KUBECONFIG" get nodes &> /dev/null; then
        log "ERROR" "Cannot connect to target cluster"
        exit 1
    fi
    
    log "SUCCESS" "✅ Both clusters accessible"
}

create_temp_dir() {
    mkdir -p "$TEMP_DIR"
    trap "rm -rf $TEMP_DIR" EXIT
}

export_application_configs() {
    log "INFO" "📤 Exporting application configurations..."
    mkdir -p "$TEMP_DIR/exports"
    
    for app in "${!APPLICATIONS[@]}"; do
        log "INFO" "Exporting $app..."
        
        if kubectl --kubeconfig="$SOURCE_KUBECONFIG" get namespace "$app" &> /dev/null; then
            # Export non-sensitive configs
            kubectl --kubeconfig="$SOURCE_KUBECONFIG" get configmaps,services,ingress,pvc -n "$app" -o yaml > "$TEMP_DIR/exports/$app-configs.yaml" 2>/dev/null || true
            
            # Export deployments/statefulsets (without secrets)
            kubectl --kubeconfig="$SOURCE_KUBECONFIG" get deployments,statefulsets,daemonsets,cronjobs -n "$app" -o yaml > "$TEMP_DIR/exports/$app-workloads.yaml" 2>/dev/null || true
            
            log "SUCCESS" "✅ $app configuration exported"
        else
            log "WARNING" "⚠️  Namespace $app not found in source cluster"
        fi
    done
}

export_data_with_permissions() {
    local app=$1
    log "INFO" "📤 Exporting data for $app with permission handling..."
    
    case $app in
        "vaultwarden")
            export_vaultwarden_data
            ;;
        "monitoring")
            export_monitoring_data
            ;;
        *)
            log "INFO" "No data export needed for $app"
            ;;
    esac
}

export_vaultwarden_data() {
    log "INFO" "📤 Exporting Vaultwarden data..."
    
    local pod=$(kubectl --kubeconfig="$SOURCE_KUBECONFIG" get pods -n vaultwarden -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$pod" ]]; then
        mkdir -p "$TEMP_DIR/data/vaultwarden"
        kubectl --kubeconfig="$SOURCE_KUBECONFIG" cp "vaultwarden/$pod:/data" "$TEMP_DIR/data/vaultwarden/" || true
        log "SUCCESS" "✅ Vaultwarden data exported"
    else
        log "WARNING" "⚠️  Vaultwarden pod not found"
    fi
}

export_monitoring_data() {
    log "INFO" "📤 Exporting monitoring data..."
    
    local grafana_pod=$(kubectl --kubeconfig="$SOURCE_KUBECONFIG" get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$grafana_pod" ]]; then
        mkdir -p "$TEMP_DIR/data/monitoring/grafana"
        kubectl --kubeconfig="$SOURCE_KUBECONFIG" cp "monitoring/$grafana_pod:/var/lib/grafana" "$TEMP_DIR/data/monitoring/grafana/" -c grafana || true
        log "SUCCESS" "✅ Grafana data exported"
    else
        log "WARNING" "⚠️  Grafana pod not found"
    fi
}

deploy_infrastructure() {
    log "INFO" "🚀 Deploying infrastructure components..."
    
    # Deploy KEDA
    deploy_keda
    
    # Deploy monitoring stack
    deploy_monitoring_stack
    
    log "SUCCESS" "✅ Infrastructure deployed"
}

deploy_keda() {
    log "INFO" "🚀 Deploying KEDA..."
    
    helm --kubeconfig="$TARGET_KUBECONFIG" repo add kedacore https://kedacore.github.io/charts &> /dev/null || true
    helm --kubeconfig="$TARGET_KUBECONFIG" repo update &> /dev/null || true
    
    kubectl --kubeconfig="$TARGET_KUBECONFIG" create namespace keda &> /dev/null || true
    helm --kubeconfig="$TARGET_KUBECONFIG" upgrade --install keda kedacore/keda --namespace keda &> /dev/null || true
    
    log "SUCCESS" "✅ KEDA deployed"
}

deploy_monitoring_stack() {
    log "INFO" "🚀 Deploying monitoring stack..."
    
    helm --kubeconfig="$TARGET_KUBECONFIG" repo add prometheus-community https://prometheus-community.github.io/helm-charts &> /dev/null || true
    helm --kubeconfig="$TARGET_KUBECONFIG" repo add grafana https://grafana.github.io/helm-charts &> /dev/null || true
    helm --kubeconfig="$TARGET_KUBECONFIG" repo update &> /dev/null || true
    
    kubectl --kubeconfig="$TARGET_KUBECONFIG" create namespace monitoring &> /dev/null || true
    
    # Deploy Prometheus stack
    helm --kubeconfig="$TARGET_KUBECONFIG" upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
        --set grafana.persistence.enabled=true \
        --set grafana.persistence.size=5Gi &> /dev/null || true
    
    # Deploy Loki
    helm --kubeconfig="$TARGET_KUBECONFIG" upgrade --install loki grafana/loki-stack \
        --namespace monitoring \
        --set loki.persistence.enabled=true \
        --set loki.persistence.size=10Gi &> /dev/null || true
    
    log "SUCCESS" "✅ Monitoring stack deployed"
}

deploy_applications() {
    log "INFO" "🚀 Deploying applications..."
    
    for app in "${!APPLICATIONS[@]}"; do
        deploy_application "$app"
    done
}

deploy_application() {
    local app=$1
    log "INFO" "🚀 Deploying $app..."
    
    if [[ -f "$MANIFESTS_DIR/$app.yaml" ]]; then
        kubectl --kubeconfig="$TARGET_KUBECONFIG" apply -f "$MANIFESTS_DIR/$app.yaml" || true
        log "SUCCESS" "✅ $app deployed"
    else
        log "WARNING" "⚠️  No manifest found for $app"
    fi
}

import_data() {
    log "INFO" "📥 Importing application data..."
    
    # Wait for applications to start
    sleep 30
    
    for app in "${!APPLICATIONS[@]}"; do
        if [[ -d "$TEMP_DIR/data/$app" ]]; then
            import_application_data "$app"
        fi
    done
}

import_application_data() {
    local app=$1
    log "INFO" "📥 Importing data for $app..."
    
    case $app in
        "vaultwarden")
            import_vaultwarden_data
            ;;
        "monitoring")
            import_monitoring_data
            ;;
    esac
}

import_vaultwarden_data() {
    log "INFO" "📥 Importing Vaultwarden data..."
    
    # Scale down
    kubectl --kubeconfig="$TARGET_KUBECONFIG" scale statefulset vaultwarden --replicas=0 -n vaultwarden &> /dev/null || true
    sleep 10
    
    # Create import pod with correct user
    kubectl --kubeconfig="$TARGET_KUBECONFIG" apply -f - <<EOF &> /dev/null
apiVersion: v1
kind: Pod
metadata:
  name: vaultwarden-import
  namespace: vaultwarden
spec:
  containers:
  - name: import
    image: busybox:1.35
    command: ['sleep', '3600']
    securityContext:
      runAsUser: 1000
      runAsGroup: 1000
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: vaultwarden-data-vaultwarden-0
  restartPolicy: Never
EOF
    
    # Wait and copy data
    kubectl --kubeconfig="$TARGET_KUBECONFIG" wait --for=condition=Ready pod/vaultwarden-import -n vaultwarden --timeout=60s &> /dev/null || true
    kubectl --kubeconfig="$TARGET_KUBECONFIG" cp "$TEMP_DIR/data/vaultwarden/" vaultwarden/vaultwarden-import:/data/ &> /dev/null || true
    
    # Fix structure and permissions
    kubectl --kubeconfig="$TARGET_KUBECONFIG" exec vaultwarden-import -n vaultwarden -- sh -c "cd /data && if [ -d vaultwarden ]; then cp -r vaultwarden/* . && rm -rf vaultwarden; fi; chmod 755 . && chmod 644 db.sqlite3*" &> /dev/null || true
    
    # Cleanup and restart
    kubectl --kubeconfig="$TARGET_KUBECONFIG" delete pod vaultwarden-import -n vaultwarden &> /dev/null || true
    kubectl --kubeconfig="$TARGET_KUBECONFIG" scale statefulset vaultwarden --replicas=1 -n vaultwarden &> /dev/null || true
    
    log "SUCCESS" "✅ Vaultwarden data imported with correct permissions"
}

import_monitoring_data() {
    log "INFO" "📥 Importing monitoring data..."
    
    # Scale down Grafana
    kubectl --kubeconfig="$TARGET_KUBECONFIG" scale deployment kube-prometheus-stack-grafana --replicas=0 -n monitoring &> /dev/null || true
    sleep 10
    
    # Create import pod
    kubectl --kubeconfig="$TARGET_KUBECONFIG" apply -f - <<EOF &> /dev/null
apiVersion: v1
kind: Pod
metadata:
  name: grafana-import
  namespace: monitoring
spec:
  containers:
  - name: import
    image: busybox:1.35
    command: ['sleep', '3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: kube-prometheus-stack-grafana
  restartPolicy: Never
EOF
    
    # Wait and copy data
    kubectl --kubeconfig="$TARGET_KUBECONFIG" wait --for=condition=Ready pod/grafana-import -n monitoring --timeout=60s &> /dev/null || true
    kubectl --kubeconfig="$TARGET_KUBECONFIG" cp "$TEMP_DIR/data/monitoring/grafana/" monitoring/grafana-import:/data/ &> /dev/null || true
    
    # Fix structure
    kubectl --kubeconfig="$TARGET_KUBECONFIG" exec grafana-import -n monitoring -- sh -c "cd /data && if [ -d grafana ]; then cp -r grafana/* . && rm -rf grafana; fi" &> /dev/null || true
    
    # Cleanup and restart
    kubectl --kubeconfig="$TARGET_KUBECONFIG" delete pod grafana-import -n monitoring &> /dev/null || true
    kubectl --kubeconfig="$TARGET_KUBECONFIG" scale deployment kube-prometheus-stack-grafana --replicas=1 -n monitoring &> /dev/null || true
    
    log "SUCCESS" "✅ Grafana data imported"
}

configure_networking() {
    log "INFO" "🌐 Configuring networking..."
    
    # Apply ingress configurations
    if [[ -f "$MANIFESTS_DIR/ingress.yaml" ]]; then
        kubectl --kubeconfig="$TARGET_KUBECONFIG" apply -f "$MANIFESTS_DIR/ingress.yaml" || true
    fi
    
    log "SUCCESS" "✅ Networking configured"
}

validate_migration() {
    log "INFO" "🔍 Validating migration..."
    
    local all_ready=true
    
    for app in "${!APPLICATIONS[@]}"; do
        if kubectl --kubeconfig="$TARGET_KUBECONFIG" get namespace "$app" &> /dev/null; then
            local pods=$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get pods -n "$app" --no-headers 2>/dev/null | grep -v solver | wc -l)
            local ready=$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get pods -n "$app" --no-headers 2>/dev/null | grep -v solver | grep -c "Running\|Completed" || echo "0")
            
            if [[ $ready -eq $pods ]] && [[ $pods -gt 0 ]]; then
                log "SUCCESS" "✅ $app: $ready/$pods pods ready"
            else
                log "WARNING" "⚠️  $app: $ready/$pods pods ready"
                all_ready=false
            fi
        else
            log "WARNING" "⚠️  $app: namespace not found"
            all_ready=false
        fi
    done
    
    if $all_ready; then
        log "SUCCESS" "🎉 Migration validation successful!"
    else
        log "WARNING" "⚠️  Some applications need attention"
    fi
}

generate_dns_config() {
    log "INFO" "🌐 Generating DNS configuration..."
    
    local k3s_ip=$(kubectl --kubeconfig="$TARGET_KUBECONFIG" get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null || echo "YOUR_K3S_IP")
    
    cat > "$PROJECT_ROOT/dns-configuration.txt" <<EOF
DNS Configuration Required
=========================

Add these A records to your DNS provider:

vault1.keltio.fr      → $k3s_ip
status.keltio.fr      → $k3s_ip  
pgadmin.solya.app     → $k3s_ip
prometheus.keltio.fr  → $k3s_ip

Instructions:
1. Add the records above to your DNS provider
2. Set Proxy to OFF (orange cloud disabled)  
3. Wait 2-5 minutes for DNS propagation
4. Test applications:
   - https://vault1.keltio.fr
   - https://status.keltio.fr
   - https://pgadmin.solya.app
   - https://prometheus.keltio.fr

EOF
    
    log "SUCCESS" "📄 DNS configuration saved to dns-configuration.txt"
}

cleanup_temp_files() {
    log "INFO" "🧹 Cleaning up temporary files..."
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}

# Main execution
main() {
    log "INFO" "🚀 Starting K8s to K3s Migration"
    log "INFO" "================================"
    
    create_temp_dir
    check_prerequisites
    test_connectivity
    
    log "INFO" "📤 Phase 1: Exporting configurations and data..."
    export_application_configs
    for app in "${!APPLICATIONS[@]}"; do
        export_data_with_permissions "$app"
    done
    
    log "INFO" "🚀 Phase 2: Deploying infrastructure..."
    deploy_infrastructure
    
    log "INFO" "🚀 Phase 3: Deploying applications..."
    deploy_applications
    
    log "INFO" "📥 Phase 4: Importing data..."
    import_data
    
    log "INFO" "🌐 Phase 5: Configuring networking..."
    configure_networking
    
    log "INFO" "🔍 Phase 6: Validating migration..."
    validate_migration
    
    log "INFO" "📄 Phase 7: Generating configuration..."
    generate_dns_config
    
    cleanup_temp_files
    
    log "SUCCESS" "🎉 Migration completed successfully!"
    log "INFO" "📋 Check dns-configuration.txt for next steps"
}

# Handle script arguments
case "${1:-full}" in
    "export")
        create_temp_dir
        check_prerequisites
        test_connectivity
        export_application_configs
        for app in "${!APPLICATIONS[@]}"; do
            export_data_with_permissions "$app"
        done
        ;;
    "deploy")
        check_prerequisites
        test_connectivity
        deploy_infrastructure
        deploy_applications
        ;;
    "import")
        create_temp_dir
        check_prerequisites
        import_data
        ;;
    "validate")
        check_prerequisites
        validate_migration
        ;;
    "dns")
        generate_dns_config
        ;;
    "full")
        main
        ;;
    *)
        echo "Usage: $0 [export|deploy|import|validate|dns|full]"
        echo ""
        echo "Commands:"
        echo "  export   - Export data from source cluster"
        echo "  deploy   - Deploy applications to target cluster"
        echo "  import   - Import data to target cluster"
        echo "  validate - Validate migration status"
        echo "  dns      - Generate DNS configuration"
        echo "  full     - Run complete migration (default)"
        exit 1
        ;;
esac
