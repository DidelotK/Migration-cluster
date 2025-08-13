#!/bin/bash
set -euo pipefail

# Script simple pour récupérer le kubeconfig K3s
# Simple script to get K3s kubeconfig

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "🚀 Récupération du kubeconfig K3s"
echo "=================================="

cd "$PROJECT_ROOT"

# 1. Récupérer l'IP depuis Terraform
echo "🔍 Récupération de l'IP VM..."
cd infrastructure/terraform/environments/dev
VM_IP=$(terraform show -json 2>/dev/null | jq -r '.values.root_module.child_modules[0].resources[] | select(.address == "module.k3s_vm.scaleway_instance_server.k3s_vm") | .values.public_ip' 2>/dev/null || echo "")

if [[ -z "$VM_IP" || "$VM_IP" == "null" ]]; then
    echo "❌ Impossible de récupérer l'IP VM"
    exit 1
fi

echo "✅ IP VM: $VM_IP"
cd "$PROJECT_ROOT"

# 2. Vérifier la clé SSH
SSH_KEY="infrastructure/ssh-keys/k3s-migration-dev"
if [[ ! -f "$SSH_KEY" ]]; then
    echo "❌ Clé SSH introuvable: $SSH_KEY"
    exit 1
fi

chmod 600 "$SSH_KEY" 2>/dev/null || true
echo "✅ Clé SSH: $SSH_KEY"

# 3. Test SSH
echo "🔗 Test SSH..."
if ! ssh -i "$SSH_KEY" ubuntu@"$VM_IP" -o ConnectTimeout=5 "echo 'SSH test OK'" >/dev/null 2>&1; then
    echo "❌ SSH non accessible"
    echo "Vérifiez que la VM est démarrée"
    exit 1
fi
echo "✅ SSH accessible"

# 4. Récupération kubeconfig
echo "📥 Récupération kubeconfig..."
KUBECONFIG_FILE="kubeconfig-target.yaml"

if ssh -i "$SSH_KEY" ubuntu@"$VM_IP" 'sudo cat /etc/rancher/k3s/k3s.yaml' > "$KUBECONFIG_FILE.tmp" 2>/dev/null; then
    sed "s/127.0.0.1/$VM_IP/g" "$KUBECONFIG_FILE.tmp" > "$KUBECONFIG_FILE"
    rm -f "$KUBECONFIG_FILE.tmp"
    echo "✅ Kubeconfig sauvegardé: $KUBECONFIG_FILE"
else
    echo "❌ Échec récupération kubeconfig"
    exit 1
fi

# 5. Test kubeconfig
echo "🧪 Test kubeconfig..."
if kubectl --kubeconfig="$KUBECONFIG_FILE" get nodes >/dev/null 2>&1; then
    echo "✅ Kubeconfig fonctionnel"
    echo ""
    echo "📊 Informations cluster:"
    kubectl --kubeconfig="$KUBECONFIG_FILE" get nodes
    echo ""
    echo "📦 Namespaces:"
    kubectl --kubeconfig="$KUBECONFIG_FILE" get namespaces
else
    echo "❌ Kubeconfig non fonctionnel"
    exit 1
fi

echo ""
echo "🎉 Kubeconfig K3s récupéré avec succès !"
echo "📁 Fichier: $KUBECONFIG_FILE"
echo ""
echo "💡 Utilisation:"
echo "kubectl --kubeconfig=$KUBECONFIG_FILE get nodes"
echo ""
echo "💡 Alias pratique:"
echo "alias k3s='kubectl --kubeconfig=$KUBECONFIG_FILE'"
