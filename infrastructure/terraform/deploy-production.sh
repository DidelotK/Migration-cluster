#!/bin/bash
set -euo pipefail

# Production Deployment Script with Enhanced Security
# This script includes additional safety checks for production deployment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROD_DIR="$SCRIPT_DIR/environments/prod"
BACKEND_CONFIG="$SCRIPT_DIR/environments/backend-configs/prod.hcl"

echo "🏭 PRODUCTION DEPLOYMENT"
echo "======================="
echo "⚠️  WARNING: You are deploying to PRODUCTION environment"
echo ""

# Enhanced security checks
function security_checks() {
    echo "🔐 Running security checks..."
    
    # Check if this is really production
    if [[ ! -f "$PROD_DIR/terraform.tfvars" ]]; then
        echo "❌ Production tfvars file missing"
        echo "💡 Copy and configure: $PROD_DIR/terraform.tfvars.example"
        exit 1
    fi
    
    # Check environment variables
    if [[ -z "${SCALEWAY_ACCESS_KEY:-}" ]]; then
        echo "❌ Production environment variables not loaded"
        echo "💡 Run: direnv allow (from project root)"
        exit 1
    fi
    
    # Check if backend is configured
    if [[ ! -f "$BACKEND_CONFIG" ]]; then
        echo "❌ Production backend configuration missing"
        echo "💡 Run: ./setup-backend.sh first"
        exit 1
    fi
    
    echo "✅ Security checks passed"
}

# Production confirmation
function production_confirmation() {
    echo ""
    echo "🚨 PRODUCTION DEPLOYMENT CONFIRMATION"
    echo "====================================="
    echo ""
    echo "You are about to deploy to PRODUCTION environment:"
    echo "  - Instance: k3s-migration-prod"
    echo "  - Type: GP1-XS (4 vCPU, 16GB RAM)"
    echo "  - Storage: 100GB SSD"
    echo "  - Environment: Production"
    echo ""
    echo "This will:"
    echo "  ✅ Create production infrastructure"
    echo "  ✅ Deploy K3s cluster"
    echo "  ✅ Configure Ansible automation"
    echo "  ⚠️  Incur production costs (~50€/month)"
    echo ""
    
    read -p "Type 'DEPLOY-PRODUCTION' to confirm: " -r
    if [[ ! $REPLY == "DEPLOY-PRODUCTION" ]]; then
        echo "🚫 Production deployment cancelled"
        exit 0
    fi
    
    echo ""
    read -p "Final confirmation - Deploy to production? (yes/no): " -r
    if [[ ! $REPLY == "yes" ]]; then
        echo "🚫 Production deployment cancelled"
        exit 0
    fi
}

# Main deployment function
function deploy_production() {
    cd "$PROD_DIR"
    
    echo ""
    echo "🚀 Starting production deployment..."
    
    # Initialize with backend
    echo "🔧 Initializing Terraform with production backend..."
    terraform init -backend-config="$BACKEND_CONFIG"
    
    # Plan with detailed output
    echo ""
    echo "📋 Creating production plan..."
    terraform plan -detailed-exitcode -out=prod.tfplan
    
    local plan_exit_code=$?
    if [[ $plan_exit_code -eq 1 ]]; then
        echo "❌ Planning failed"
        exit 1
    elif [[ $plan_exit_code -eq 2 ]]; then
        echo "📊 Changes detected, proceeding with apply..."
    else
        echo "✅ No changes needed"
        exit 0
    fi
    
    # Apply with confirmation
    echo ""
    echo "🎯 Applying production infrastructure..."
    terraform apply prod.tfplan
    
    # Clean up plan file
    rm -f prod.tfplan
    
    echo ""
    echo "✅ Production deployment completed!"
    
    # Show important outputs
    echo ""
    echo "📊 Production Environment Summary:"
    echo "=================================="
    terraform output -json | jq -r '
    "Instance: " + .instance_details.value.name + 
    "\nPublic IP: " + .network_details.value.public_ip +
    "\nSSH Command: " + .ssh_access.value.command'
    
    echo ""
    echo "🔗 Next Steps:"
    echo "1. Configure DNS records for the production IP"
    echo "2. Run Ansible playbook for K3s setup"
    echo "3. Deploy production applications"
    echo "4. Configure monitoring and backups"
    echo "5. Update team documentation"
}

# Backup check
function backup_check() {
    echo ""
    echo "💾 Backup verification..."
    
    if [[ -f "$PROD_DIR/terraform.tfstate.backup" ]]; then
        echo "✅ State backup exists"
    else
        echo "⚠️  No state backup found (normal for first deployment)"
    fi
}

# Main execution
function main() {
    security_checks
    backup_check
    production_confirmation
    deploy_production
    
    echo ""
    echo "🎉 PRODUCTION DEPLOYMENT SUCCESSFUL!"
    echo "🔗 Remember to:"
    echo "  - Update DNS records"
    echo "  - Configure monitoring"
    echo "  - Set up backup schedules"
    echo "  - Document production access procedures"
}

# Handle interrupts gracefully
trap 'echo ""; echo "🚫 Production deployment interrupted"; exit 1' INT TERM

# Check if running from correct directory
if [[ ! -f "$SCRIPT_DIR/setup-backend.sh" ]]; then
    echo "❌ Please run this script from the terraform directory"
    exit 1
fi

main "$@"
