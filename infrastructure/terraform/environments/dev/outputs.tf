# Infrastructure outputs
output "instance_details" {
  description = "K3s instance details"
  value = {
    id   = module.k3s_vm.instance_id
    name = module.k3s_vm.instance_name
    type = module.k3s_vm.instance_type
    zone = module.k3s_vm.instance_zone
  }
}

output "network_details" {
  description = "Network details"
  value = {
    public_ip  = module.k3s_vm.public_ip
    private_ip = module.k3s_vm.private_ip
    ipv6       = module.k3s_vm.ipv6_address
  }
}

output "ssh_access" {
  description = "SSH access information"
  value = {
    host     = module.k3s_vm.ssh_host
    user     = module.k3s_vm.ssh_user
    command  = module.k3s_vm.ssh_command
    key_path = module.k3s_vm.ssh_private_key_path
  }
  sensitive = true
}

output "ansible_config" {
  description = "Configuration for Ansible"
  value = {
    inventory_file = "${path.module}/../../ansible/inventories/dev.ini"
    group_vars     = "${path.module}/../../ansible/group_vars/k3s_servers.yml"
    playbook_cmd   = "cd ${path.module}/../../ansible && ansible-playbook -i inventories/dev.ini site.yml"
  }
}

output "k3s_config" {
  description = "K3s configuration"
  value = {
    version        = var.k3s_version
    kubectl_version = var.kubectl_version
    helm_version   = var.helm_version
  }
}

output "next_steps" {
  description = "Next steps"
  value = {
    connect_ssh    = "bash scripts/connect-dev.sh"
    run_ansible    = "cd infrastructure/terraform/environments/dev && terraform output -raw ansible_config | jq -r '.playbook_cmd' | bash"
    get_kubeconfig = "scp -i ${module.k3s_vm.ssh_private_key_path} root@${module.k3s_vm.public_ip}:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-dev.yaml"
  }
  sensitive = true
}
