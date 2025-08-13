#!/bin/bash
set -euo pipefail

# Script to setup Terraform backend for K3s migration project
# This script creates the S3 bucket for storing Terraform state

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"

echo "🚀 Terraform Backend Setup"
echo "=========================="

# Check if .envrc is loaded
if [[ -z "${SCALEWAY_ACCESS_KEY:-}" ]]; then
    echo "❌ Environment variables not loaded"
    echo "💡 Run: direnv allow (from project root)"
    exit 1
fi

echo "✅ Environment variables loaded"

# Check if terraform is installed
if ! command -v terraform >/dev/null 2>&1; then
    echo "❌ Terraform not installed"
    echo "💡 Install from: https://www.terraform.io/downloads.html"
    exit 1
fi

echo "✅ Terraform installed: $(terraform version -json | jq -r '.terraform_version')"

cd "$BACKEND_DIR"

# Check if backend is already created
if [[ -f "terraform.tfstate" ]] && terraform show >/dev/null 2>&1; then
    echo "⚠️  Backend already exists"
    echo "🔍 Current state:"
    terraform show -json | jq -r '.values.root_module.resources[] | select(.type == "scaleway_object_bucket") | .values.name'
    echo ""
    read -p "Do you want to recreate the backend? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "🚫 Skipping backend creation"
        exit 0
    fi
fi

# Create terraform.tfvars from environment variables
echo "📝 Creating terraform.tfvars..."
cat > terraform.tfvars <<EOF
# Generated from environment variables
scw_access_key      = "$SCALEWAY_ACCESS_KEY"
scw_secret_key      = "$SCALEWAY_SECRET_KEY"
scw_organization_id = "$SCALEWAY_ORGANIZATION_ID"
scw_project_id      = "$SCALEWAY_PROJECT_ID"
scw_region          = "fr-par"
scw_zone            = "fr-par-1"

# Backend configuration
bucket_name  = "k3s-migration-terraform-state"
project_name = "k3s-migration"
EOF

echo "✅ terraform.tfvars created"

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Plan and apply
echo "📋 Planning backend infrastructure..."
terraform plan -out=backend.tfplan

echo ""
echo "🚀 Creating backend infrastructure..."
terraform apply backend.tfplan

# Get backend configuration
echo ""
echo "📊 Backend created successfully!"
BUCKET_NAME=$(terraform output -raw bucket_name)
BUCKET_ENDPOINT=$(terraform output -raw bucket_endpoint)

echo "✅ Backend information:"
echo "  Bucket: $BUCKET_NAME"
echo "  Endpoint: $BUCKET_ENDPOINT"
echo "  Region: fr-par"

# Create backend configuration for environments
echo ""
echo "📝 Creating backend configuration template..."
mkdir -p ../environments/backend-configs

cat > ../environments/backend-configs/dev.hcl <<EOF
# Backend configuration for dev environment
bucket                      = "$BUCKET_NAME"
key                         = "environments/dev/terraform.tfstate"
region                      = "fr-par"
endpoint                    = "$BUCKET_ENDPOINT"
skip_credentials_validation = true
skip_metadata_api_check     = true
skip_region_validation      = true
force_path_style            = true
EOF

cat > ../environments/backend-configs/staging.hcl <<EOF
# Backend configuration for staging environment
bucket                      = "$BUCKET_NAME"
key                         = "environments/staging/terraform.tfstate"
region                      = "fr-par"
endpoint                    = "$BUCKET_ENDPOINT"
skip_credentials_validation = true
skip_metadata_api_check     = true
skip_region_validation      = true
force_path_style            = true
EOF

cat > ../environments/backend-configs/prod.hcl <<EOF
# Backend configuration for prod environment
bucket                      = "$BUCKET_NAME"
key                         = "environments/prod/terraform.tfstate"
region                      = "fr-par"
endpoint                    = "$BUCKET_ENDPOINT"
skip_credentials_validation = true
skip_metadata_api_check     = true
skip_region_validation      = true
force_path_style            = true
EOF

echo "✅ Backend configuration files created"

echo ""
echo "🎯 Next steps:"
echo "1. Uncomment the backend block in environments/dev/main.tf"
echo "2. Run: cd environments/dev && terraform init -backend-config=../backend-configs/dev.hcl"
echo "3. Migrate existing state: terraform init -migrate-state"

echo ""
echo "📚 Backend configuration files:"
echo "  - environments/backend-configs/dev.hcl"
echo "  - environments/backend-configs/staging.hcl"
echo "  - environments/backend-configs/prod.hcl"

# Clean up
rm -f backend.tfplan
