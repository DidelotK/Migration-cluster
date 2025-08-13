#!/bin/bash
set -euo pipefail

# Script to retrieve manifests from K3s VM
# Get current deployed manifests from the K3s cluster

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
TARGET_DIR="$PROJECT_ROOT/k8s-manifests/k3s-target"
KUBECONFIG_FILE="$PROJECT_ROOT/kubeconfig-target.yaml"

echo "🎯 K3s Manifests Retrieval"
echo "=========================="

# Check if kubeconfig exists
if [[ ! -f "$KUBECONFIG_FILE" ]]; then
    echo "❌ K3s kubeconfig not found: $KUBECONFIG_FILE"
    echo "💡 Run: ./k8s-to-k3s-migration/scripts/get-k3s-kubeconfig.sh"
    exit 1
fi

echo "✅ Using kubeconfig: $KUBECONFIG_FILE"

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p "$TARGET_DIR"/{namespaces,applied,exported}

# Test connectivity
echo "🔗 Testing K3s connectivity..."
if ! kubectl --kubeconfig="$KUBECONFIG_FILE" --request-timeout=5s cluster-info >/dev/null 2>&1; then
    echo "❌ Cannot connect to K3s cluster"
    echo "💡 Check that the K3s VM is running and accessible"
    exit 1
fi
echo "✅ K3s cluster accessible"

case "${1:-export}" in
    "export")
        echo "📤 Exporting current K3s manifests..."
        
        # Get all namespaces (except system ones)
        echo "🏷️ Exporting namespaces..."
        kubectl --kubeconfig="$KUBECONFIG_FILE" get namespaces \
            -o yaml --export > "$TARGET_DIR/namespaces/all-namespaces.yaml" 2>/dev/null || \
        kubectl --kubeconfig="$KUBECONFIG_FILE" get namespaces \
            -o yaml > "$TARGET_DIR/namespaces/all-namespaces.yaml"
        
        # Export by namespace
        NAMESPACES=$(kubectl --kubeconfig="$KUBECONFIG_FILE" get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E '^(kube-|default$)')
        
        for ns in $NAMESPACES; do
            echo "📦 Exporting namespace: $ns"
            mkdir -p "$TARGET_DIR/applied/$ns"
            
            # Export all resources in namespace
            kubectl --kubeconfig="$KUBECONFIG_FILE" get all,configmap,secret,pvc,ingress \
                --namespace="$ns" -o yaml > "$TARGET_DIR/applied/$ns/all-resources.yaml" 2>/dev/null || true
            
            # Export specific resource types separately
            for resource in deployment service configmap secret pvc ingress cronjob; do
                if kubectl --kubeconfig="$KUBECONFIG_FILE" get "$resource" --namespace="$ns" >/dev/null 2>&1; then
                    kubectl --kubeconfig="$KUBECONFIG_FILE" get "$resource" \
                        --namespace="$ns" -o yaml > "$TARGET_DIR/applied/$ns/$resource.yaml" 2>/dev/null || true
                fi
            done
        done
        
        echo "📋 Creating summary..."
        cat > "$TARGET_DIR/export-summary.md" << EOF
# K3s Manifests Export

**Date:** $(date)
**Cluster:** K3s Target
**Kubeconfig:** $KUBECONFIG_FILE

## Exported Namespaces

$(echo "$NAMESPACES" | sed 's/^/- /')

## Files Structure

\`\`\`
applied/
$(find "$TARGET_DIR/applied" -name "*.yaml" | sed "s|$TARGET_DIR/applied/||" | sort | sed 's/^/├── /')
\`\`\`

## Usage

\`\`\`bash
# Apply specific namespace
kubectl apply -f k8s-manifests/k3s-target/applied/vaultwarden/

# Apply all
kubectl apply -f k8s-manifests/k3s-target/applied/
\`\`\`
EOF
        
        echo "✅ Export completed!"
        echo "📁 Files saved to: $TARGET_DIR/applied/"
        echo "📋 Summary: $TARGET_DIR/export-summary.md"
        ;;
        
    "check")
        echo "🔍 Checking K3s cluster status..."
        
        echo "📊 Cluster info:"
        kubectl --kubeconfig="$KUBECONFIG_FILE" cluster-info
        
        echo ""
        echo "🏷️ Namespaces:"
        kubectl --kubeconfig="$KUBECONFIG_FILE" get namespaces
        
        echo ""
        echo "📦 Applications:"
        kubectl --kubeconfig="$KUBECONFIG_FILE" get pods --all-namespaces | grep -v "kube-system"
        ;;
        
    "help"|*)
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  export   - Export all manifests from K3s cluster (default)"
        echo "  check    - Check K3s cluster status"
        echo "  help     - Show this help"
        echo ""
        echo "Examples:"
        echo "  $0                  # Export manifests"
        echo "  $0 export          # Same as above"
        echo "  $0 check           # Check cluster status"
        ;;
esac
