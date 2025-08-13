#!/bin/bash
set -euo pipefail

# Script to migrate existing Terraform state to remote backend
# This script helps migrate from local state to S3 backend

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$SCRIPT_DIR/environments/dev"
BACKEND_CONFIG="$SCRIPT_DIR/environments/backend-configs/dev.hcl"

echo "🔄 Terraform State Migration"
echo "============================"

# Check if backend is setup
if [[ ! -f "$BACKEND_CONFIG" ]]; then
    echo "❌ Backend configuration not found: $BACKEND_CONFIG"
    echo "💡 Run: ./setup-backend.sh first"
    exit 1
fi

echo "✅ Backend configuration found"

# Check if .envrc is loaded
if [[ -z "${SCALEWAY_ACCESS_KEY:-}" ]]; then
    echo "❌ Environment variables not loaded"
    echo "💡 Run: direnv allow (from project root)"
    exit 1
fi

echo "✅ Environment variables loaded"

cd "$ENV_DIR"

# Check if there's existing state
if [[ ! -f "terraform.tfstate" ]]; then
    echo "⚠️  No local state file found"
    echo "💡 This seems to be a fresh setup"
    
    # Uncomment backend and init directly
    echo "🔧 Enabling backend configuration..."
    
    # Backup current main.tf
    cp main.tf main.tf.backup
    
    # Uncomment backend configuration
    sed -i.bak 's/^  # backend "s3"/  backend "s3"/' main.tf
    sed -i.bak 's/^  #   /    /' main.tf
    
    echo "✅ Backend configuration enabled"
    
    # Initialize with backend
    echo "🚀 Initializing with remote backend..."
    terraform init -backend-config="$BACKEND_CONFIG"
    
    echo "✅ Fresh initialization with remote backend completed"
    exit 0
fi

echo "📊 Existing local state found"

# Show current state
echo "🔍 Current state resources:"
terraform state list | head -10

echo ""
read -p "Do you want to migrate this state to remote backend? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "🚫 Migration cancelled"
    exit 0
fi

# Backup current state
echo "💾 Backing up current state..."
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)
cp main.tf main.tf.backup.$(date +%Y%m%d_%H%M%S)

echo "✅ Backups created"

# Uncomment backend configuration
echo "🔧 Enabling backend configuration..."
sed -i.bak 's/^  # backend "s3"/  backend "s3"/' main.tf
sed -i.bak 's/^  #   /    /' main.tf

echo "✅ Backend configuration enabled"

# Initialize with migration
echo "🔄 Migrating state to remote backend..."
echo "When prompted, answer 'yes' to migrate the state"
echo ""

terraform init -backend-config="$BACKEND_CONFIG" -migrate-state

if [[ $? -eq 0 ]]; then
    echo ""
    echo "✅ State migration completed successfully!"
    
    # Verify remote state
    echo "🔍 Verifying remote state..."
    terraform state list | head -5
    
    echo ""
    echo "🎯 Migration summary:"
    echo "  ✅ Local state backed up"
    echo "  ✅ Backend configuration enabled"
    echo "  ✅ State migrated to S3"
    echo "  ✅ Remote backend active"
    
    echo ""
    echo "📚 Next steps:"
    echo "1. Test with: terraform plan"
    echo "2. Remove backup files when confident: rm *.backup*"
    echo "3. Update team about backend usage"
    
else
    echo ""
    echo "❌ Migration failed!"
    echo "🔧 Restoring backup..."
    
    # Restore backups
    mv main.tf.backup main.tf
    
    echo "✅ Configuration restored"
    echo "💡 Check the error and try again"
fi
