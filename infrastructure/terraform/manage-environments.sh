#!/bin/bash
set -euo pipefail

# Multi-environment Terraform management script
# Manages dev, staging, and prod environments

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🌍 Multi-Environment Terraform Manager"
echo "====================================="

# Available environments
ENVIRONMENTS=("dev" "staging" "prod")
ACTIONS=("plan" "apply" "destroy" "init" "show" "output")

function show_usage() {
    echo "Usage: $0 <environment> <action> [options]"
    echo ""
    echo "Environments:"
    for env in "${ENVIRONMENTS[@]}"; do
        echo "  $env"
    done
    echo ""
    echo "Actions:"
    for action in "${ACTIONS[@]}"; do
        echo "  $action"
    done
    echo ""
    echo "Examples:"
    echo "  $0 dev plan              # Plan dev environment"
    echo "  $0 staging apply         # Apply staging environment"
    echo "  $0 prod init             # Initialize prod environment"
    echo "  $0 dev output            # Show dev outputs"
    echo ""
    echo "Options:"
    echo "  --auto-approve           # Auto-approve applies/destroys"
    echo "  --target=<resource>      # Target specific resource"
    echo "  --var-file=<file>        # Use specific tfvars file"
}

# Parse arguments
if [[ $# -lt 2 ]]; then
    show_usage
    exit 1
fi

ENVIRONMENT="$1"
ACTION="$2"
shift 2

# Validate environment
if [[ ! " ${ENVIRONMENTS[@]} " =~ " ${ENVIRONMENT} " ]]; then
    echo "❌ Invalid environment: $ENVIRONMENT"
    echo "Valid environments: ${ENVIRONMENTS[*]}"
    exit 1
fi

# Validate action
if [[ ! " ${ACTIONS[@]} " =~ " ${ACTION} " ]]; then
    echo "❌ Invalid action: $ACTION"
    echo "Valid actions: ${ACTIONS[*]}"
    exit 1
fi

ENV_DIR="$SCRIPT_DIR/environments/$ENVIRONMENT"
BACKEND_CONFIG="$SCRIPT_DIR/environments/backend-configs/$ENVIRONMENT.hcl"

# Check if environment directory exists
if [[ ! -d "$ENV_DIR" ]]; then
    echo "❌ Environment directory not found: $ENV_DIR"
    exit 1
fi

echo "🎯 Environment: $ENVIRONMENT"
echo "🔧 Action: $ACTION"

# Check if .envrc is loaded
if [[ -z "${SCALEWAY_ACCESS_KEY:-}" ]]; then
    echo "❌ Environment variables not loaded"
    echo "💡 Run: direnv allow (from project root)"
    exit 1
fi

echo "✅ Environment variables loaded"

cd "$ENV_DIR"

# Execute action
case "$ACTION" in
    "init")
        echo "🚀 Initializing $ENVIRONMENT environment..."
        if [[ -f "$BACKEND_CONFIG" ]]; then
            terraform init -backend-config="$BACKEND_CONFIG" "$@"
        else
            echo "⚠️  Backend config not found, initializing without backend"
            terraform init "$@"
        fi
        ;;
        
    "plan")
        echo "📋 Planning $ENVIRONMENT environment..."
        terraform plan "$@"
        ;;
        
    "apply")
        echo "🚀 Applying $ENVIRONMENT environment..."
        if [[ "$ENVIRONMENT" == "prod" ]] && [[ ! "$*" =~ "--auto-approve" ]]; then
            echo "🚨 PRODUCTION ENVIRONMENT DETECTED"
            echo "=================================="
            echo "⚠️  You are about to apply changes to PRODUCTION"
            echo "🔍 Running plan first..."
            terraform plan
            echo ""
            echo "🔐 Production Safety Checks:"
            echo "  ✅ Have you tested this in staging?"
            echo "  ✅ Is there a rollback plan?"
            echo "  ✅ Are backups current?"
            echo "  ✅ Is monitoring active?"
            echo ""
            read -p "Type 'APPLY-PRODUCTION' to confirm: " -r
            if [[ ! $REPLY == "APPLY-PRODUCTION" ]]; then
                echo "🚫 Production apply cancelled"
                exit 0
            fi
            echo ""
            read -p "Final confirmation - apply to production? (yes/no): " -r
            if [[ ! $REPLY == "yes" ]]; then
                echo "🚫 Production apply cancelled"
                exit 0
            fi
        fi
        terraform apply "$@"
        ;;
        
    "destroy")
        echo "💥 Destroying $ENVIRONMENT environment..."
        if [[ "$ENVIRONMENT" == "prod" ]]; then
            echo "🚨 DANGER: You are about to destroy PRODUCTION!"
            echo "🔍 Resources to be destroyed:"
            terraform plan -destroy
            echo ""
            read -p "Type 'destroy-production' to confirm: " -r
            if [[ ! $REPLY == "destroy-production" ]]; then
                echo "🚫 Destroy cancelled"
                exit 0
            fi
        else
            echo "⚠️  Resources to be destroyed:"
            terraform plan -destroy
            echo ""
            read -p "Do you want to proceed with destroy? (yes/no): " -r
            if [[ ! $REPLY == "yes" ]]; then
                echo "🚫 Destroy cancelled"
                exit 0
            fi
        fi
        terraform destroy "$@"
        ;;
        
    "show")
        echo "📊 Showing $ENVIRONMENT state..."
        terraform show "$@"
        ;;
        
    "output")
        echo "📤 Outputs for $ENVIRONMENT..."
        terraform output "$@"
        ;;
        
    *)
        echo "❌ Unknown action: $ACTION"
        show_usage
        exit 1
        ;;
esac

echo ""
echo "✅ Action '$ACTION' completed for environment '$ENVIRONMENT'"

# Show summary for apply actions
if [[ "$ACTION" == "apply" ]]; then
    echo ""
    echo "📊 Environment Summary:"
    echo "  Environment: $ENVIRONMENT"
    echo "  Instance: $(terraform output -raw instance_details 2>/dev/null | jq -r '.name' 2>/dev/null || echo 'N/A')"
    echo "  Public IP: $(terraform output -raw network_details 2>/dev/null | jq -r '.public_ip' 2>/dev/null || echo 'N/A')"
    echo ""
    echo "🔗 Next steps:"
    echo "  SSH: $(terraform output -raw ssh_access 2>/dev/null | jq -r '.command' 2>/dev/null || echo 'Check outputs')"
    echo "  Ansible: $(terraform output -raw ansible_config 2>/dev/null | jq -r '.playbook_cmd' 2>/dev/null || echo 'Check outputs')"
fi
