# Informations sur l'instance
output "instance_id" {
  description = "ID de l'instance Scaleway"
  value       = scaleway_instance_server.k3s_vm.id
}

output "instance_name" {
  description = "Nom de l'instance"
  value       = scaleway_instance_server.k3s_vm.name
}

output "instance_type" {
  description = "Type de l'instance"
  value       = scaleway_instance_server.k3s_vm.type
}

output "instance_zone" {
  description = "Zone de l'instance"
  value       = scaleway_instance_server.k3s_vm.zone
}

# Informations réseau
output "public_ip" {
  description = "Adresse IP publique de l'instance"
  value       = var.create_public_ip ? scaleway_instance_ip.public_ip[0].address : scaleway_instance_server.k3s_vm.public_ip
}

output "private_ip" {
  description = "Adresse IP privée de l'instance"
  value       = scaleway_instance_server.k3s_vm.private_ip
}

output "ipv6_address" {
  description = "Adresse IPv6 de l'instance"
  value       = scaleway_instance_server.k3s_vm.ipv6_address
}

# Informations SSH
output "ssh_host" {
  description = "Host SSH pour la connexion"
  value       = var.create_public_ip ? scaleway_instance_ip.public_ip[0].address : scaleway_instance_server.k3s_vm.public_ip
}

output "ssh_user" {
  description = "Utilisateur SSH par défaut"
  value       = "root"
}

output "ssh_private_key_path" {
  description = "Path to SSH private key"
  value       = var.create_ssh_key ? "${path.root}/../../ssh-keys/${var.ssh_key_name}" : var.ssh_private_key_path
  sensitive   = true
}

output "ssh_command" {
  description = "Complete SSH command to connect"
  value       = "ssh -i ${var.create_ssh_key ? "${path.root}/../../ssh-keys/${var.ssh_key_name}" : var.ssh_private_key_path} root@${var.create_public_ip ? scaleway_instance_ip.public_ip[0].address : scaleway_instance_server.k3s_vm.public_ip}"
  sensitive   = true
}

# Informations sur le stockage
output "root_volume_id" {
  description = "ID du volume racine"
  value       = scaleway_instance_server.k3s_vm.root_volume.0.volume_id
}

output "additional_volume_ids" {
  description = "IDs des volumes supplémentaires"
  value       = { for k, v in scaleway_instance_volume.additional : k => v.id }
}

# Informations sur la sécurité
output "security_group_id" {
  description = "ID du groupe de sécurité"
  value       = scaleway_instance_security_group.k3s_sg.id
}

output "ssh_key_id" {
  description = "ID de la clé SSH Scaleway"
  value       = scaleway_iam_ssh_key.k3s_key.id
}

# Informations pour Ansible
output "ansible_inventory" {
  description = "Configuration for Ansible inventory"
  value = {
    hosts = {
      k3s_master = {
        ansible_host = var.create_public_ip ? scaleway_instance_ip.public_ip[0].address : scaleway_instance_server.k3s_vm.public_ip
        ansible_user = "root"
        ansible_ssh_private_key_file = var.create_ssh_key ? "${path.root}/../../ssh-keys/${var.ssh_key_name}" : var.ssh_private_key_path
        ansible_ssh_common_args = "-o StrictHostKeyChecking=no"
      }
    }
    vars = {
      instance_name = scaleway_instance_server.k3s_vm.name
      instance_id   = scaleway_instance_server.k3s_vm.id
      environment   = var.environment
    }
  }
}

# Informations pour le monitoring
output "monitoring_labels" {
  description = "Labels pour le monitoring"
  value = {
    instance_name = scaleway_instance_server.k3s_vm.name
    instance_type = scaleway_instance_server.k3s_vm.type
    zone         = scaleway_instance_server.k3s_vm.zone
    environment  = var.environment
    tags         = var.tags
  }
}
