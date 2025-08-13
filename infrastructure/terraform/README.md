# 🏗️ Terraform Infrastructure

## 📁 Structure

```
terraform/
├── backend/                    # S3 backend setup
│   ├── main.tf                # Backend bucket creation
│   ├── variables.tf           # Backend variables
│   ├── outputs.tf             # Backend outputs
│   └── terraform.tfvars.example
├── shared/                     # Shared configurations
│   ├── backend.tf             # Backend template
│   └── variables.tf           # Common variables
├── modules/                    # Reusable modules
│   └── vm/                    # VM module
├── environments/              # Environment-specific configs
│   ├── staging/               # Staging environment
│   ├── prod/                  # Production environment
│   └── backend-configs/       # Backend config files
└── README.md                  # This file
```

## 🚀 Quick Start

### 1. Setup Remote Backend

First time setup to create the S3 bucket for state storage:

```bash
# From project root, ensure environment is loaded
direnv allow

# Setup the backend manually
cd infrastructure/terraform/backend
terraform init
terraform apply
```

### 2. Initialize Environment

For staging or production:

```bash
cd environments/staging
terraform init -backend-config=../backend-configs/staging.hcl
```

### 3. Deploy Infrastructure

Deploy to staging or production:

```bash
# Staging
cd environments/staging
terraform plan
terraform apply

# Production (with caution)
cd environments/prod
terraform plan
terraform apply
```

## 🔧 Backend Configuration

The backend uses Scaleway Object Storage (S3-compatible) to store Terraform state:

- **Bucket**: `k3s-migration-terraform-state`
- **Region**: `fr-par`
- **Encryption**: HTTPS enforced
- **State locking**: Via Scaleway metadata

### Benefits:
- ✅ **Team collaboration**: Shared state
- ✅ **State safety**: Remote backup
- ✅ **Version control**: State versioning
- ✅ **Locking**: Prevents concurrent modifications

## 📋 Environment Management

### Staging
```bash
cd environments/staging
terraform init -backend-config=../backend-configs/staging.hcl
terraform plan
terraform apply
```

### Production
```bash
cd environments/prod
terraform init -backend-config=../backend-configs/prod.hcl
terraform plan
terraform apply
```

## 🔐 Security

- State stored in encrypted S3 bucket
- Access controlled via Scaleway IAM
- Environment variables for credentials
- No sensitive data in version control

## 🛠️ Maintenance

### Backend Management
```bash
# Check backend status
cd backend
terraform show

# Update backend configuration
terraform plan
terraform apply
```

### State Operations
```bash
# List state resources
terraform state list

# Show state details
terraform show

# Import existing resources
terraform import <resource_type>.<name> <resource_id>
```

## 🔄 Migration Guide

### From Local to Remote Backend

1. **Backup current state**:
   ```bash
   cp terraform.tfstate terraform.tfstate.backup
   ```

2. **Run migration script**:
   ```bash
   ./migrate-to-backend.sh
   ```

3. **Verify migration**:
   ```bash
   terraform state list
   ```

### Between Environments

1. **Export state from source**:
   ```bash
   terraform state pull > source-state.json
   ```

2. **Import to target environment**:
   ```bash
   terraform state push source-state.json
   ```

## 📚 Best Practices

1. **Always use backend** for shared environments
2. **Environment separation** via different state keys
3. **Regular state backups** via scripts
4. **Credential management** via environment variables
5. **Plan before apply** in production
6. **Use workspaces** for temporary environments

## 🆘 Troubleshooting

### Backend Access Issues
```bash
# Test S3 connectivity
aws s3 ls s3://k3s-migration-terraform-state --endpoint-url=https://s3.fr-par.scw.cloud

# Check credentials
echo $SCALEWAY_ACCESS_KEY
```

### State Lock Issues
```bash
# Force unlock (use carefully)
terraform force-unlock <lock-id>
```

### Migration Problems
```bash
# Restore from backup
cp terraform.tfstate.backup terraform.tfstate
```
