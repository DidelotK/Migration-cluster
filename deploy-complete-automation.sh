#!/bin/bash

# 🚀 Script de déploiement COMPLET - Tout automatisé depuis zéro
# Auteur: Assistant IA
# Description: Déploie une infrastructure K3s complète de A à Z

set -e  # Arrêt en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fonction d'affichage avec couleurs
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${PURPLE} $1${NC}"
    echo -e "${PURPLE}================================================================${NC}"
}

print_step() {
    echo -e "${CYAN}➤ $1${NC}"
}

# Vérifications préalables
check_prerequisites() {
    print_header "🔍 VÉRIFICATION DES PRÉREQUIS"
    
    # Vérification des outils requis
    print_step "Vérification des outils requis..."
    
    local tools=("terraform" "ansible" "jq" "curl")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            print_error "Outil manquant: $tool"
            exit 1
        else
            print_success "✓ $tool installé"
        fi
    done
    
    # Vérification de la structure du projet
    print_step "Vérification de la structure du projet..."
    local required_dirs=("infrastructure/terraform/environments/dev" "ansible" "ssh-keys")
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            print_error "Répertoire manquant: $dir"
            exit 1
        else
            print_success "✓ $dir trouvé"
        fi
    done
    
    print_success "✅ Tous les prérequis sont satisfaits"
}

# Fonction de nettoyage
cleanup_existing() {
    print_header "🧹 NETTOYAGE DE L'INFRASTRUCTURE EXISTANTE"
    
    print_step "Destruction de l'infrastructure existante..."
    cd infrastructure/terraform/environments/dev
    
    if terraform state list &>/dev/null; then
        print_warning "Infrastructure existante détectée, destruction en cours..."
        terraform destroy -auto-approve || print_warning "Certaines ressources n'ont pas pu être détruites"
    else
        print_success "Aucune infrastructure existante"
    fi
    
    cd - > /dev/null
}

# Déploiement de l'infrastructure
deploy_infrastructure() {
    print_header "🏗️ DÉPLOIEMENT DE L'INFRASTRUCTURE TERRAFORM"
    
    cd infrastructure/terraform/environments/dev
    
    print_step "Initialisation de Terraform..."
    terraform init
    
    print_step "Validation de la configuration..."
    terraform validate
    
    print_step "Planification du déploiement..."
    terraform plan -out=tfplan
    
    print_step "Application du plan..."
    terraform apply tfplan
    
    print_success "✅ Infrastructure Terraform déployée"
    
    cd - > /dev/null
}

# Vérification post-déploiement
verify_deployment() {
    print_header "🔍 VÉRIFICATION DU DÉPLOIEMENT"
    
    print_step "Récupération de l'IP publique..."
    cd infrastructure/terraform/environments/dev
    VM_IP=$(terraform show | grep -A5 -B5 "address.*=" | grep "address" | head -1 | awk -F'"' '{print $4}')
    cd - > /dev/null
    
    if [ -z "$VM_IP" ]; then
        print_error "Impossible de récupérer l'IP de la VM"
        exit 1
    fi
    
    print_success "✓ IP de la VM: $VM_IP"
    
    print_step "Test de connectivité SSH..."
    timeout 30 bash -c "until ssh -i ssh-keys/k3s-migration -o StrictHostKeyChecking=no root@$VM_IP 'echo Connected' 2>/dev/null; do sleep 2; done"
    print_success "✓ Connectivité SSH établie"
    
    print_step "Vérification du statut K3s..."
    ssh -i ssh-keys/k3s-migration -o StrictHostKeyChecking=no root@$VM_IP 'systemctl is-active k3s' > /dev/null
    print_success "✓ K3s actif et en cours d'exécution"
    
    print_step "Vérification des composants déployés..."
    
    # Vérification Helm
    ssh -i ssh-keys/k3s-migration -o StrictHostKeyChecking=no root@$VM_IP 'helm version --short' > /dev/null
    print_success "✓ Helm installé"
    
    # Vérification Ingress Nginx
    ssh -i ssh-keys/k3s-migration -o StrictHostKeyChecking=no root@$VM_IP 'k3s kubectl get pods -n ingress-nginx | grep Running' > /dev/null
    print_success "✓ Ingress Nginx opérationnel"
    
    # Vérification Cert Manager
    ssh -i ssh-keys/k3s-migration -o StrictHostKeyChecking=no root@$VM_IP 'k3s kubectl get pods -n cert-manager | grep Running' > /dev/null
    print_success "✓ Cert Manager opérationnel"
    
    # Vérification External DNS
    ssh -i ssh-keys/k3s-migration -o StrictHostKeyChecking=no root@$VM_IP 'k3s kubectl get pods -n external-dns | grep Running' > /dev/null
    print_success "✓ External DNS opérationnel"
    
    # Vérification de l'application test
    print_step "Vérification de l'application Nginx test..."
    
    # Attendre que les pods soient prêts
    print_step "Attente des pods nginx-test..."
    timeout 120 bash -c "until ssh -i ssh-keys/k3s-migration -o StrictHostKeyChecking=no root@$VM_IP 'k3s kubectl get pods -n nginx-test | grep Running | wc -l | grep -q 2' 2>/dev/null; do sleep 5; done"
    print_success "✓ Pods Nginx test opérationnels"
    
    # Attendre le certificat SSL
    print_step "Attente du certificat SSL..."
    timeout 180 bash -c "until ssh -i ssh-keys/k3s-migration -o StrictHostKeyChecking=no root@$VM_IP 'k3s kubectl get certificate -n nginx-test nginx-test-tls -o jsonpath=\"{.status.conditions[0].status}\" 2>/dev/null | grep -q True' 2>/dev/null; do sleep 10; done"
    print_success "✓ Certificat SSL obtenu"
    
    # Test HTTPS
    print_step "Test de connectivité HTTPS..."
    timeout 30 bash -c "until curl -s -I https://nginx.keltio.fr | grep -q 'HTTP/2 200' 2>/dev/null; do sleep 5; done"
    print_success "✓ HTTPS opérationnel"
}

# Affichage du résumé final
show_summary() {
    print_header "🎉 DÉPLOIEMENT TERMINÉ AVEC SUCCÈS"
    
    cd infrastructure/terraform/environments/dev
    VM_IP=$(terraform show | grep -A5 -B5 "address.*=" | grep "address" | head -1 | awk -F'"' '{print $4}')
    cd - > /dev/null
    
    echo -e "${GREEN}"
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│                   🚀 K3S MIGRATION RÉUSSIE                 │"
    echo "├─────────────────────────────────────────────────────────────┤"
    echo "│                                                             │"
    echo "│  🌐 URL Test:    https://nginx.keltio.fr                   │"
    echo "│  🖥️  IP VM:       $VM_IP                           │"
    echo "│  💰 Économie:    ~200€/mois (250€ → 50€)                   │"
    echo "│                                                             │"
    echo "│  ✅ Composants installés:                                   │"
    echo "│     • K3s (Kubernetes léger)                               │"
    echo "│     • Helm (Gestionnaire de packages)                      │"
    echo "│     • Ingress Nginx (Contrôleur HTTP/HTTPS)                │"
    echo "│     • Cert Manager (SSL automatique)                       │"
    echo "│     • External DNS (Gestion DNS automatique)               │"
    echo "│     • Application test avec HTTPS                          │"
    echo "│                                                             │"
    echo "│  🔧 Commandes utiles:                                       │"
    echo "│     • Se connecter: ssh -i ssh-keys/k3s-migration root@$VM_IP │"
    echo "│     • Détruire:     ./destroy-infrastructure.sh            │"
    echo "│     • Redéployer:   ./deploy-complete-automation.sh        │"
    echo "│                                                             │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo -e "${NC}"
    
    print_success "🎯 Prêt pour migrer tes vraies applications!"
}

# Script principal
main() {
    clear
    print_header "🚀 AUTOMATISATION COMPLÈTE K3S MIGRATION"
    echo
    echo "Ce script va déployer automatiquement:"
    echo "• Infrastructure Scaleway (VM + réseau)"
    echo "• Cluster K3s avec tous les composants"
    echo "• Application test nginx.keltio.fr avec HTTPS"
    echo
    
    read -p "Continuer? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Déploiement annulé"
        exit 0
    fi
    
    local start_time=$(date +%s)
    
    check_prerequisites
    cleanup_existing
    deploy_infrastructure
    verify_deployment
    show_summary
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    print_success "🕐 Déploiement terminé en ${minutes}m ${seconds}s"
}

# Gestion des erreurs
trap 'print_error "❌ Erreur durant le déploiement. Vérifiez les logs ci-dessus."' ERR

# Exécution
main "$@"
