# 🚀 Quick Start Guide

This guide will allow you to deploy your K3s cluster in less than 10 minutes.

## ⏱️ Estimated time: 8-10 minutes

## 📋 Prerequisites (2 min)

### Tool installation

**Sur macOS:**
```bash
brew install terraform ansible kubectl jq
```

**Sur Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y terraform ansible kubectl jq curl
```

### Scaleway Credentials
You must have:
- ✅ Scaleway access key
- ✅ Scaleway secret key  
- ✅ Organization ID
- ✅ Project ID

## 🏗️ Step 1: Configuration (1 min)

```bash
# Clone the project
git clone <your-repo>
cd migrationcluster

# Copy environment configuration
cp .envrc.example .envrc
```

Edit the `.envrc` file:
```bash
nano .envrc
```

Fill in with your credentials:
```bash
export SCW_ACCESS_KEY="SCWXXXXXXXXXXXXXXXXX"
export SCW_SECRET_KEY="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export SCW_ORGANIZATION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export SCW_PROJECT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

export TF_VAR_instance_name="k3s-prod"  # Change according to your needs
```

Activate direnv:
```bash
direnv allow
```

## 🚀 Step 2: Automatic deployment (5-7 min)

### Option A: All-in-one script (Recommended)

```bash
./deploy-complete-automation.sh
```

### Option B: Step by step

```bash
# 1. Infrastructure (2-3 min)
cd infrastructure/terraform/environments/dev
terraform init
terraform apply -auto-approve

# 2. K3s installation (3-4 min)
cd ../../../../ansible
ansible-playbook -i inventories/dev.ini site.yml
```

## ✅ Step 3: Verification (1 min)

```bash
# Configure kubectl
export KUBECONFIG=~/.kube/k3s.yaml

# Test the cluster
kubectl get nodes
kubectl get pods --all-namespaces

# Test an application
IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
curl -k https://$IP
```

## 🎯 Expected result

After these steps, you should have:

✅ **Scaleway VM** deployed and configured  
✅ **K3s cluster** operational  
✅ **Helm** installed and configured  
✅ **kubectl** configured locally  
✅ **Ready** to deploy applications  

## 📊 Important information

Once completed, note this information:

```bash
# Your cluster IP
terraform output -raw network_details | jq -r '.public_ip'

# SSH command
terraform output -raw ssh_access | jq -r '.command'

# Local kubeconfig
echo $KUBECONFIG
```

## 🚀 Next steps

Now that your cluster is ready:

1. **Install essential components** (Ingress, Cert Manager, etc.)
2. **Deploy your applications**
3. **Configure DNS domains**

See the [Applications Guide](applications.md) for next steps.

## 🐛 Common issues

### Terraform: "Invalid credentials"
```bash
# Check your credentials in .envrc
cat .envrc
# Make sure direnv is activated
direnv allow
```

### SSH: "Permission denied"
```bash
# SSH keys are generated automatically in ssh-keys/
# Check permissions:
chmod 600 ssh-keys/k3s-migration-dev
# Or use the built-in function:
k3s-ssh
```

### Ansible: "Unreachable host"
```bash
# Wait 1-2 minutes for the VM to finish initialization
# Then retry:
ansible-playbook -i inventories/dev.ini site.yml
```

## 💡 Tips

- **First time?** Use the `dev` environment
- **Production?** Use the `prod` environment with a more powerful VM
- **Quick commands?** Use built-in functions: `deploy`, `destroy`, `k3s-ssh`, `status`
- **Problem?** Check logs with `kubectl logs`
- **Backup?** Configurations are in Git, your data in PVCs

## 📞 Help

If you encounter problems:

1. Check the [logs](#🐛-common-issues)
2. Review the [troubleshooting](../README.md#🐛-troubleshooting)
3. Open an issue on the project

---

**🎉 Congratulations! Your K3s cluster is now operational!**
