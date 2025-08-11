#!/bin/bash

# 🧨 Script de destruction de l'infrastructure K3s
# Auteur: Assistant IA

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[DANGER]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

main() {
    echo -e "${RED}🧨 DESTRUCTION DE L'INFRASTRUCTURE K3s${NC}"
    echo
    print_error "Cette action va DÉTRUIRE complètement:"
    echo "  • La VM Scaleway"
    echo "  • L'IP publique"
    echo "  • Les clés SSH"
    echo "  • Tous les certificats SSL"
    echo "  • Toutes les données K3s"
    echo
    print_warning "Cette action est IRRÉVERSIBLE!"
    echo
    
    read -p "Êtes-vous ABSOLUMENT sûr de vouloir détruire l'infrastructure? (tapez 'DESTROY'): " -r
    echo
    
    if [[ $REPLY != "DESTROY" ]]; then
        print_success "Destruction annulée - Infrastructure préservée"
        exit 0
    fi
    
    echo -e "${RED}🧨 Destruction en cours...${NC}"
    
    cd infrastructure/terraform/environments/dev
    
    terraform destroy -auto-approve
    
    cd ../../../..
    
    print_success "Infrastructure détruite avec succès"
    print_warning "Pour redéployer: ./deploy-full-k3s.sh"
}

main "$@"
