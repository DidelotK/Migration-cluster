terraform {
  required_version = ">= 1.0"
  
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Remote backend configuration
  backend "s3" {
    # Configuration loaded from backend-configs/prod.hcl
  }
}

# Scaleway provider configuration
provider "scaleway" {
  access_key      = var.scw_access_key
  secret_key      = var.scw_secret_key
  organization_id = var.scw_organization_id
  project_id      = var.scw_project_id
  region          = var.scw_region
  zone            = var.scw_zone
}

# K3s VM module
module "k3s_vm" {
  source = "../../modules/vm"
  
  # Instance configuration
  instance_name = var.instance_name
  instance_type = var.instance_type
  zone          = var.scw_zone
  environment   = "production"
  
  # Storage configuration
  root_volume_size = var.root_volume_size
  root_volume_type = var.root_volume_type
  
  # SSH configuration
  ssh_key_name         = var.ssh_key_name
  ssh_private_key_path = var.ssh_private_key_path
  create_ssh_key       = var.create_ssh_key
  
  # Network configuration
  create_public_ip = var.create_public_ip
  enable_ipv6      = var.enable_ipv6
  
  # System configuration
  packages = var.packages
  timezone = var.timezone
  
  # Scaleway variables for External DNS
  scaleway_access_key      = var.scw_access_key
  scaleway_secret_key      = var.scw_secret_key
  scaleway_organization_id = var.scw_organization_id
  scaleway_project_id      = var.scw_project_id

  # Tags
  tags = concat(var.default_tags, var.additional_tags)
}

# Ansible inventory generation
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.ini.tpl", {
    ansible_inventory = module.k3s_vm.ansible_inventory
  })
  filename = "${path.module}/../../ansible/inventories/prod.ini"
  
  depends_on = [module.k3s_vm]
}

# Ansible variables generation
resource "local_file" "ansible_vars" {
  content = templatefile("${path.module}/templates/group_vars.yml.tpl", {
    instance_name            = module.k3s_vm.instance_name
    instance_type            = module.k3s_vm.instance_type
    public_ip                = module.k3s_vm.public_ip
    environment              = "production"
    k3s_version              = var.k3s_version
    kubectl_version          = var.kubectl_version
    helm_version             = var.helm_version
    scaleway_access_key      = var.scw_access_key
    scaleway_secret_key      = var.scw_secret_key
    scaleway_organization_id = var.scw_organization_id
    scaleway_project_id      = var.scw_project_id
  })
  filename = "${path.module}/../../ansible/group_vars/k3s_servers_prod.yml"
  
  depends_on = [module.k3s_vm]
}

# SSH connection script
resource "local_file" "ssh_script" {
  content = templatefile("${path.module}/templates/connect.sh.tpl", {
    ssh_command = module.k3s_vm.ssh_command
    public_ip   = module.k3s_vm.public_ip
  })
  filename        = "${path.module}/../../scripts/connect-prod.sh"
  file_permission = "0755"
  
  depends_on = [module.k3s_vm]
}
