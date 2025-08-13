# 🏭 Production Environment

## ⚠️ CRITICAL - Production Environment

This directory contains the **PRODUCTION** infrastructure configuration. Exercise extreme caution when making changes.

## 🔐 Security Requirements

### Access Control
- ✅ **MFA Required**: Multi-factor authentication mandatory
- ✅ **VPN Access**: Production access only via VPN
- ✅ **Audit Logging**: All actions logged and monitored
- ✅ **Approval Process**: Changes require peer review

### Deployment Safety
- ✅ **Plan Review**: Always review terraform plan before apply
- ✅ **Backup Verification**: Ensure backups exist before changes
- ✅ **Rollback Plan**: Have rollback procedure ready
- ✅ **Monitoring**: Verify monitoring is active

## 🏗️ Infrastructure Specifications

### VM Configuration
- **Instance Type**: GP1-XS (4 vCPU, 16GB RAM)
- **Storage**: 100GB SSD (l_ssd)
- **Network**: Public IP with security groups
- **Region**: fr-par (France - Paris)
- **Estimated Cost**: ~50€/month

### Security Features
- **Firewall**: UFW configured
- **Intrusion Detection**: fail2ban installed
- **SSH**: Key-based authentication only
- **Updates**: Automatic security updates enabled

## 🚀 Deployment Process

### Prerequisites
1. **Backend Setup**: Run `../../setup-backend.sh`
2. **Environment Variables**: Load production credentials
3. **Configuration**: Copy and configure `terraform.tfvars.example`
4. **Review**: Peer review of configuration

### Standard Deployment
```bash
# Using the production deployment script (RECOMMENDED)
cd infrastructure/terraform
./deploy-production.sh
```

### Manual Deployment (Advanced)
```bash
# Only for experienced operators
cd environments/prod

# Initialize with backend
terraform init -backend-config=../backend-configs/prod.hcl

# Plan and review carefully
terraform plan -out=prod.tfplan

# Apply only after thorough review
terraform apply prod.tfplan
```

## 📊 Monitoring & Maintenance

### Health Checks
- **Instance Health**: Monitor VM metrics
- **K3s Status**: Verify cluster health
- **Application Status**: Monitor deployed services
- **DNS Resolution**: Verify external access

### Backup Schedule
- **State Backup**: Terraform state backed up to S3
- **Data Backup**: Application data backup (separate process)
- **Configuration Backup**: Infrastructure as code in Git

### Update Process
1. **Staging First**: Test all changes in staging
2. **Maintenance Window**: Schedule production updates
3. **Gradual Rollout**: Apply changes incrementally
4. **Verification**: Verify each step before proceeding

## 🆘 Emergency Procedures

### Incident Response
1. **Assess Impact**: Determine scope and severity
2. **Immediate Action**: Take action to minimize damage
3. **Communication**: Notify stakeholders
4. **Resolution**: Implement fix or rollback
5. **Post-Mortem**: Document lessons learned

### Rollback Procedure
```bash
# Emergency rollback (if needed)
cd environments/prod

# Restore from backup state
terraform state pull > current-state.backup
terraform state push terraform.tfstate.backup

# Or restore to last known good configuration
git checkout <last-good-commit>
terraform plan
terraform apply
```

### Emergency Contacts
- **Platform Team**: platform-team@company.com
- **DevOps Lead**: devops-lead@company.com
- **On-Call**: +33-x-xx-xx-xx-xx

## 📋 Compliance & Governance

### Change Management
- **Change Request**: Required for all production changes
- **Approval Process**: Technical and business approval
- **Documentation**: All changes documented
- **Testing**: Changes tested in staging first

### Audit Requirements
- **Access Logging**: All access logged
- **Change Tracking**: All changes tracked in Git
- **Regular Review**: Monthly infrastructure review
- **Compliance Check**: Quarterly compliance audit

## 🔧 Troubleshooting

### Common Issues

#### Terraform State Lock
```bash
# Check lock status
terraform force-unlock <lock-id>
```

#### SSH Access Issues
```bash
# Verify SSH key
ssh -i ../../ssh-keys/k3s-migration-prod root@<ip>
```

#### Backend Access Issues
```bash
# Test S3 connectivity
aws s3 ls s3://k3s-migration-terraform-state/environments/prod/ \
  --endpoint-url=https://s3.fr-par.scw.cloud
```

### Escalation Path
1. **Check Documentation**: Review this README
2. **Check Logs**: Review Terraform and system logs
3. **Team Consultation**: Consult with team members
4. **Escalate**: Contact platform team if unresolved

## 📚 References

- [Terraform Best Practices](../../../docs/)
- [Security Guidelines](../../../docs/security.md)
- [Incident Response Playbook](../../../docs/incident-response.md)
- [Production Runbook](../../../docs/production-runbook.md)
