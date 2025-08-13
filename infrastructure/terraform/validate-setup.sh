#!/bin/bash
set -euo pipefail

# Terraform Setup Validation Script
# Validates the complete Terraform configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔍 Terraform Setup Validation"
echo "============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
}

function check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

function check_fail() {
    echo -e "${RED}❌ $1${NC}"
}

# Check environment variables
function check_environment() {
    echo ""
    echo "🔐 Environment Variables:"
    
    if [[ -n "${SCALEWAY_ACCESS_KEY:-}" ]]; then
        check_pass "SCALEWAY_ACCESS_KEY loaded"
    else
        check_fail "SCALEWAY_ACCESS_KEY missing"
        echo "   💡 Run: direnv allow (from project root)"
    fi
    
    if [[ -n "${SCALEWAY_SECRET_KEY:-}" ]]; then
        check_pass "SCALEWAY_SECRET_KEY loaded"
    else
        check_fail "SCALEWAY_SECRET_KEY missing"
    fi
    
    if [[ -n "${SCALEWAY_ORGANIZATION_ID:-}" ]]; then
        check_pass "SCALEWAY_ORGANIZATION_ID loaded"
    else
        check_fail "SCALEWAY_ORGANIZATION_ID missing"
    fi
    
    if [[ -n "${SCALEWAY_PROJECT_ID:-}" ]]; then
        check_pass "SCALEWAY_PROJECT_ID loaded"
    else
        check_fail "SCALEWAY_PROJECT_ID missing"
    fi
}

# Check required tools
function check_tools() {
    echo ""
    echo "🛠️  Required Tools:"
    
    if command -v terraform >/dev/null 2>&1; then
        local tf_version=$(terraform version -json | jq -r '.terraform_version')
        check_pass "Terraform $tf_version installed"
    else
        check_fail "Terraform not installed"
        echo "   💡 Install from: https://www.terraform.io/downloads.html"
    fi
    
    if command -v jq >/dev/null 2>&1; then
        check_pass "jq installed"
    else
        check_warn "jq not installed (optional but recommended)"
        echo "   💡 Install with: brew install jq"
    fi
    
    if command -v direnv >/dev/null 2>&1; then
        check_pass "direnv installed"
    else
        check_warn "direnv not installed (recommended for env management)"
        echo "   💡 Install with: brew install direnv"
    fi
}

# Check directory structure
function check_structure() {
    echo ""
    echo "📁 Directory Structure:"
    
    local dirs=(
        "backend"
        "shared"
        "modules/vm"
        "environments/dev"
        "environments/staging"
        "environments/prod"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ -d "$SCRIPT_DIR/$dir" ]]; then
            check_pass "$dir exists"
        else
            check_fail "$dir missing"
        fi
    done
}

# Check configuration files
function check_config_files() {
    echo ""
    echo "📄 Configuration Files:"
    
    # Backend files
    local backend_files=(
        "backend/main.tf"
        "backend/variables.tf"
        "backend/outputs.tf"
        "backend/terraform.tfvars.example"
    )
    
    for file in "${backend_files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$file" ]]; then
            check_pass "$file exists"
        else
            check_fail "$file missing"
        fi
    done
    
    # Environment files
    local environments=("dev" "staging" "prod")
    for env in "${environments[@]}"; do
        local env_files=(
            "environments/$env/main.tf"
            "environments/$env/variables.tf"
            "environments/$env/outputs.tf"
            "environments/$env/terraform.tfvars.example"
        )
        
        for file in "${env_files[@]}"; do
            if [[ -f "$SCRIPT_DIR/$file" ]]; then
                check_pass "$file exists"
            else
                check_fail "$file missing"
            fi
        done
    done
}

# Check scripts
function check_scripts() {
    echo ""
    echo "🔧 Management Scripts:"
    
    local scripts=(
        "setup-backend.sh"
        "migrate-to-backend.sh"
        "manage-environments.sh"
        "deploy-production.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" ]] && [[ -x "$SCRIPT_DIR/$script" ]]; then
            check_pass "$script exists and executable"
        elif [[ -f "$SCRIPT_DIR/$script" ]]; then
            check_warn "$script exists but not executable"
            echo "   💡 Run: chmod +x $script"
        else
            check_fail "$script missing"
        fi
    done
}

# Validate Terraform syntax
function validate_terraform() {
    echo ""
    echo "🔍 Terraform Validation:"
    
    local environments=("dev" "staging" "prod")
    for env in "${environments[@]}"; do
        echo "  Validating $env environment..."
        cd "$SCRIPT_DIR/environments/$env"
        
        if terraform validate >/dev/null 2>&1; then
            check_pass "$env configuration valid"
        else
            check_fail "$env configuration invalid"
            echo "   💡 Run: cd environments/$env && terraform validate"
        fi
    done
    
    cd "$SCRIPT_DIR"
}

# Check backend status
function check_backend() {
    echo ""
    echo "🗄️  Backend Status:"
    
    if [[ -f "$SCRIPT_DIR/environments/backend-configs/dev.hcl" ]]; then
        check_pass "Backend configurations exist"
    else
        check_warn "Backend not configured"
        echo "   💡 Run: ./setup-backend.sh"
    fi
    
    # Check if backend is actually created
    if [[ -f "$SCRIPT_DIR/backend/terraform.tfstate" ]]; then
        cd "$SCRIPT_DIR/backend"
        if terraform show >/dev/null 2>&1; then
            check_pass "Backend infrastructure exists"
        else
            check_warn "Backend state exists but may be corrupted"
        fi
        cd "$SCRIPT_DIR"
    else
        check_warn "Backend infrastructure not created"
        echo "   💡 Run: ./setup-backend.sh"
    fi
}

# Generate summary report
function generate_summary() {
    echo ""
    echo "📋 Validation Summary"
    echo "===================="
    
    echo ""
    echo "🚀 Next Steps:"
    
    if [[ ! -f "$SCRIPT_DIR/backend/terraform.tfstate" ]]; then
        echo "1. Setup backend: ./setup-backend.sh"
    fi
    
    local environments=("dev" "staging" "prod")
    for env in "${environments[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/environments/$env/terraform.tfvars" ]]; then
            echo "2. Configure $env: cp environments/$env/terraform.tfvars.example environments/$env/terraform.tfvars"
        fi
    done
    
    echo "3. Deploy dev: ./manage-environments.sh dev apply"
    echo "4. Test staging: ./manage-environments.sh staging apply"  
    echo "5. Deploy production: ./deploy-production.sh"
    
    echo ""
    echo "📚 Documentation:"
    echo "  - Setup Guide: README.md"
    echo "  - Environment Docs: environments/*/README.md"
    echo "  - Production Guide: environments/prod/README.md"
}

# Main execution
function main() {
    check_environment
    check_tools
    check_structure
    check_config_files
    check_scripts
    validate_terraform
    check_backend
    generate_summary
    
    echo ""
    echo "✅ Validation completed!"
    echo "🔗 Review any warnings above before proceeding"
}

main "$@"
