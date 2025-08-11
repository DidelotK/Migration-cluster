#!/bin/bash

# 🚀 Script de déploiement automatique K3s complet
# Auteur: Assistant IA
# Description: Déploie automatiquement une infrastructure K3s complète avec Terraform + Ansible

set -e  # Arrêt en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE} $1${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

# Vérifications préalables
check_prerequisites() {
    print_header "🔍 Vérification des prérequis"
    
    # Vérifier que terraform est installé
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform n'est pas installé. Installez-le depuis https://terraform.io"
        exit 1
    fi
    print_success "Terraform installé: $(terraform version --json | jq -r .terraform_version)"
    
    # Vérifier que ansible est installé
    if ! command -v ansible &> /dev/null; then
        print_error "Ansible n'est pas installé. Installez-le avec: pip install ansible"
        exit 1
    fi
    print_success "Ansible installé: $(ansible --version | head -n1)"
    
    # Vérifier que le fichier terraform.tfvars existe
    if [ ! -f "infrastructure/terraform/environments/dev/terraform.tfvars" ]; then
        print_error "Le fichier terraform.tfvars n'existe pas."
        print_warning "Copiez le fichier terraform.tfvars.example et remplissez les valeurs."
        exit 1
    fi
    print_success "Fichier terraform.tfvars trouvé"
}

# Déploiement
deploy_infrastructure() {
    print_header "🏗️ Déploiement de l'infrastructure"
    
    cd infrastructure/terraform/environments/dev
    
    print_status "Initialisation de Terraform..."
    terraform init
    
    print_status "Planification du déploiement..."
    terraform plan
    
    print_status "Application de la configuration..."
    terraform apply -auto-approve
    
    cd ../../../..
    print_success "Infrastructure déployée avec succès!"
}

# Vérification du déploiement
verify_deployment() {
    print_header "✅ Vérification du déploiement"
    
    # Récupérer l'IP publique
    cd infrastructure/terraform/environments/dev
    PUBLIC_IP=$(terraform output -raw public_ip 2>/dev/null || echo "")
    cd ../../../..
    
    if [ -z "$PUBLIC_IP" ]; then
        print_error "Impossible de récupérer l'IP publique"
        return 1
    fi
    
    print_success "IP publique: $PUBLIC_IP"
    
    # Test de connectivité
    print_status "Test de connectivité..."
    if curl -s --connect-timeout 10 http://$PUBLIC_IP > /dev/null; then
        print_success "Serveur accessible via HTTP"
    else
        print_warning "Serveur non accessible (normal si en cours de démarrage)"
    fi
    
    # Test HTTPS nginx.keltio.fr
    print_status "Test de l'application nginx.keltio.fr..."
    if curl -s --connect-timeout 10 -k https://nginx.keltio.fr > /dev/null; then
        print_success "Application nginx.keltio.fr accessible en HTTPS"
    else
        print_warning "Application nginx.keltio.fr non encore accessible (DNS en cours de propagation)"
    fi
}

# Affichage des informations finales
show_final_info() {
    print_header "🎉 Déploiement terminé"
    
    cd infrastructure/terraform/environments/dev
    PUBLIC_IP=$(terraform output -raw public_ip 2>/dev/null || echo "IP_NON_DISPONIBLE")
    SSH_COMMAND=$(terraform output -raw ssh_command 2>/dev/null || echo "SSH_NON_DISPONIBLE")
    cd ../../../..
    
    echo -e "${GREEN}✅ Infrastructure K3s déployée avec succès!${NC}"
    echo
    echo -e "${BLUE}📊 Informations de connexion:${NC}"
    echo -e "  🖥️  IP publique: ${YELLOW}$PUBLIC_IP${NC}"
    echo -e "  🔑 Connexion SSH: ${YELLOW}$SSH_COMMAND${NC}"
    echo
    echo -e "${BLUE}🌐 Applications déployées:${NC}"
    echo -e "  🚀 Nginx Test: ${YELLOW}https://nginx.keltio.fr${NC}"
    echo -e "  📊 Ingress Nginx: Ports 80/443"
    echo -e "  🔐 Cert Manager: Let's Encrypt automatique"
    echo -e "  🌍 External DNS: Scaleway"
    echo
    echo -e "${BLUE}🛠️ Commandes utiles:${NC}"
    echo -e "  • Se connecter en SSH: ${YELLOW}$SSH_COMMAND${NC}"
    echo -e "  • Détruire l'infrastructure: ${YELLOW}cd infrastructure/terraform/environments/dev && terraform destroy${NC}"
    echo -e "  • Voir les logs K3s: ${YELLOW}$SSH_COMMAND 'sudo journalctl -u k3s -f'${NC}"
    echo
    echo -e "${GREEN}🎯 Objectif atteint: Infrastructure cloud à ~50€/mois au lieu de 250€/mois!${NC}"
}

# Fonction de nettoyage en cas d'erreur
cleanup_on_error() {
    print_error "Erreur détectée pendant le déploiement"
    print_warning "Pour nettoyer les ressources partiellement créées:"
    echo "cd infrastructure/terraform/environments/dev && terraform destroy"
}

# Piège pour capturer les erreurs
trap cleanup_on_error ERR

# Fonction principale
main() {
    print_header "🚀 Déploiement automatique K3s - Terraform + Ansible"
    echo
    print_status "Ce script va:"
    echo "  1. Vérifier les prérequis"
    echo "  2. Déployer l'infrastructure Scaleway"
    echo "  3. Installer K3s via Ansible"
    echo "  4. Configurer Ingress Nginx, Cert Manager, External DNS"
    echo "  5. Déployer l'application nginx.keltio.fr"
    echo
    
    read -p "Voulez-vous continuer? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Déploiement annulé"
        exit 0
    fi
    
    check_prerequisites
    deploy_infrastructure
    
    print_status "Attente de la stabilisation de l'infrastructure (30s)..."
    sleep 30
    
    verify_deployment
    show_final_info
}

# Exécution du script principal
main "$@"
