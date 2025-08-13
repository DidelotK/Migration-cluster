#!/bin/bash

# Script de connexion SSH généré automatiquement par Terraform
# Instance: ${public_ip}

set -e

echo "🔗 Connexion à l'instance K3s..."
echo "📍 IP: ${public_ip}"
echo "🔑 Commande: ${ssh_command}"
echo ""

# Vérification de la clé SSH
SSH_KEY=$(echo "${ssh_command}" | grep -o '\-i [^ ]*' | cut -d' ' -f2)
if [[ ! -f "$SSH_KEY" ]]; then
    echo "❌ Erreur: Clé SSH introuvable: $SSH_KEY"
    echo "💡 Exécutez 'terraform apply' pour générer les clés"
    exit 1
fi

# Vérification des permissions
if [[ $(stat -f "%A" "$SSH_KEY" 2>/dev/null || stat -c "%a" "$SSH_KEY" 2>/dev/null) != "600" ]]; then
    echo "🔧 Correction des permissions de la clé SSH..."
    chmod 600 "$SSH_KEY"
fi

# Test de connectivité
echo "🧪 Test de connectivité..."
if ! ping -c 1 -W 3 ${public_ip} >/dev/null 2>&1; then
    echo "⚠️  Attention: L'instance ne répond pas au ping"
    echo "   Cela peut être normal si ICMP est bloqué"
fi

# Connexion SSH
echo "🚀 Connexion en cours..."
${ssh_command}
