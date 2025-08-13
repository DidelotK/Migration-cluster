terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.0"
    }
  }
}

# Génération automatique de la clé SSH si elle n'existe pas
resource "tls_private_key" "k3s_key" {
  count     = var.create_ssh_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Sauvegarde de la clé privée dans le projet (format OpenSSH)
resource "local_file" "private_key" {
  count    = var.create_ssh_key ? 1 : 0
  content  = tls_private_key.k3s_key[0].private_key_openssh
  filename = "${path.root}/../../ssh-keys/${var.ssh_key_name}"
  
  provisioner "local-exec" {
    command = "chmod 600 ${path.root}/../../ssh-keys/${var.ssh_key_name}"
  }
}

# Sauvegarde de la clé publique dans le projet
resource "local_file" "public_key" {
  count    = var.create_ssh_key ? 1 : 0
  content  = tls_private_key.k3s_key[0].public_key_openssh
  filename = "${path.root}/../../ssh-keys/${var.ssh_key_name}.pub"
  
  provisioner "local-exec" {
    command = "chmod 644 ${path.root}/../../ssh-keys/${var.ssh_key_name}.pub"
  }
}

# Clé SSH Scaleway
resource "scaleway_iam_ssh_key" "k3s_key" {
  name       = var.ssh_key_name
  public_key = var.create_ssh_key ? tls_private_key.k3s_key[0].public_key_openssh : file("${path.root}/../../ssh-keys/${var.ssh_key_name}.pub")
}

# IP publique
resource "scaleway_instance_ip" "public_ip" {
  count = var.create_public_ip ? 1 : 0
  zone  = var.zone
}

# Instance Scaleway
resource "scaleway_instance_server" "k3s_vm" {
  name              = var.instance_name
  type              = var.instance_type
  image             = var.image_id
  zone              = var.zone
  enable_dynamic_ip = var.enable_dynamic_ip
  security_group_id = scaleway_instance_security_group.k3s_sg.id
  
  # Attacher l'IP publique si créée
  ip_ids = var.create_public_ip ? [scaleway_instance_ip.public_ip[0].id] : []
  
  # S'assurer que la clé SSH est créée avant la VM
  depends_on = [
    scaleway_iam_ssh_key.k3s_key
  ]
  
  # Configuration du stockage
  root_volume {
    size_in_gb = var.root_volume_size
    volume_type = var.root_volume_type
  }

  # Script d'initialisation
  cloud_init = base64encode(templatefile("${path.module}/cloud-init.yml", {
    ssh_public_key = var.create_ssh_key ? tls_private_key.k3s_key[0].public_key_openssh : file("${path.root}/../../ssh-keys/${var.ssh_key_name}.pub")
    hostname       = var.instance_name
    timezone       = var.timezone
    packages       = var.packages
  }))

  # Attendre que la VM soit prête avant de lancer Ansible
  provisioner "remote-exec" {
    inline = [
      "echo 'VM prête pour Ansible'",
      "cloud-init status --wait || true",
      "systemctl is-active ssh || systemctl start ssh"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = var.create_ssh_key ? tls_private_key.k3s_key[0].private_key_openssh : file("${path.root}/../../ssh-keys/${var.ssh_key_name}")
      host        = var.create_public_ip ? scaleway_instance_ip.public_ip[0].address : self.public_ip
      timeout     = "5m"
    }
  }

  # Launch Ansible automatically
  provisioner "local-exec" {
    command = <<-EOF
      # Go to project root
      cd ${path.root}/../../../..
      
      # Wait a bit for VM to be fully ready
      sleep 30
      
      # Check that ansible directory exists
      if [ ! -d "ansible" ]; then
        echo "❌ Error: Ansible directory not found in $(pwd)"
        exit 1
      fi
      
      # Launch complete K3s + Applications installation via Ansible with Scaleway credentials
      cd ansible && ansible-playbook -i inventories/${var.environment}.ini site.yml \
        --extra-vars "scaleway_access_key=${var.scaleway_access_key}" \
        --extra-vars "scaleway_secret_key=${var.scaleway_secret_key}" \
        --extra-vars "scaleway_organization_id=${var.scaleway_organization_id}" \
        --extra-vars "scaleway_project_id=${var.scaleway_project_id}" \
        -v
    EOF
    
    # Environment variables for Ansible
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
      ANSIBLE_SSH_RETRIES = "3"
    }
  }
}

# Volumes supplémentaires
resource "scaleway_instance_volume" "additional" {
  for_each = var.additional_volumes
  
  name       = "${var.instance_name}-${each.key}"
  type       = each.value.type
  size_in_gb = each.value.size
  zone       = var.zone
}

# Security Group pour K3s
resource "scaleway_instance_security_group" "k3s_sg" {
  name        = "${var.instance_name}-sg"
  description = "Security group for K3s cluster"
}

# Règles de sécurité
resource "scaleway_instance_security_group_rules" "k3s_rules" {
  security_group_id = scaleway_instance_security_group.k3s_sg.id

  dynamic "inbound_rule" {
    for_each = var.security_group_rules.inbound
    content {
      action   = inbound_rule.value.action
      port     = inbound_rule.value.port
      protocol = inbound_rule.value.protocol
      ip_range = inbound_rule.value.ip_range
    }
  }

  dynamic "outbound_rule" {
    for_each = var.security_group_rules.outbound
    content {
      action   = outbound_rule.value.action
      port     = outbound_rule.value.port
      protocol = outbound_rule.value.protocol
      ip_range = outbound_rule.value.ip_range
    }
  }
}