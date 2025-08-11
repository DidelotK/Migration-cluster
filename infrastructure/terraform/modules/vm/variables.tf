# Configuration de l'instance
variable "instance_name" {
  description = "Nom de l'instance Scaleway"
  type        = string
  default     = "k3s-cluster"
}

variable "instance_type" {
  description = "Type d'instance Scaleway"
  type        = string
  default     = "GP1-XS"
  
  validation {
    condition = contains([
      "GP1-XS", "GP1-S", "GP1-M", "GP1-L", "GP1-XL",
      "DEV1-S", "DEV1-M", "DEV1-L", "DEV1-XL",
      "PRO2-XXS", "PRO2-XS", "PRO2-S", "PRO2-M"
    ], var.instance_type)
    error_message = "Le type d'instance doit être un type Scaleway valide."
  }
}

variable "image_id" {
  description = "Image de base pour l'instance"
  type        = string
  default     = "ubuntu_jammy"  # Ubuntu 22.04 LTS
}

variable "zone" {
  description = "Zone Scaleway"
  type        = string
  default     = "fr-par-1"
  
  validation {
    condition = contains([
      "fr-par-1", "fr-par-2", "fr-par-3",
      "nl-ams-1", "nl-ams-2", "nl-ams-3",
      "pl-waw-1", "pl-waw-2", "pl-waw-3"
    ], var.zone)
    error_message = "La zone doit être une zone Scaleway valide."
  }
}

# Configuration réseau
variable "enable_ipv6" {
  description = "Activer IPv6 pour l'instance"
  type        = bool
  default     = true
}

variable "enable_dynamic_ip" {
  description = "Activer l'IP dynamique"
  type        = bool
  default     = false
}

variable "create_public_ip" {
  description = "Créer une IP publique statique"
  type        = bool
  default     = true
}

# Configuration du stockage
variable "root_volume_size" {
  description = "Taille du volume racine en GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.root_volume_size >= 10 && var.root_volume_size <= 1000
    error_message = "La taille du volume racine doit être entre 10 et 1000 GB."
  }
}

variable "root_volume_type" {
  description = "Type de volume racine"
  type        = string
  default     = "b_ssd"
  
  validation {
    condition = contains([
      "l_ssd", "b_ssd", "unified"
    ], var.root_volume_type)
    error_message = "Le type de volume doit être l_ssd, b_ssd ou unified."
  }
}

variable "additional_volumes" {
  description = "Volumes supplémentaires à créer"
  type = map(object({
    size = number
    type = string
  }))
  default = {}
}

# Configuration SSH
variable "ssh_key_name" {
  description = "Nom de la clé SSH"
  type        = string
  default     = "k3s-migration-key"
}

variable "ssh_private_key_path" {
  description = "Chemin vers la clé privée SSH"
  type        = string
  default     = "~/.ssh/k3s_migration"
}

variable "create_ssh_key" {
  description = "Créer automatiquement une nouvelle clé SSH"
  type        = bool
  default     = true
}

# Configuration de sécurité
variable "security_group_rules" {
  description = "Règles du groupe de sécurité"
  type = object({
    inbound = list(object({
      action   = string
      port     = number
      protocol = string
      ip_range = string
    }))
    outbound = list(object({
      action   = string
      port     = number
      protocol = string
      ip_range = string
    }))
  })
  
  default = {
    inbound = [
      {
        action   = "accept"
        port     = 22
        protocol = "TCP"
        ip_range = "0.0.0.0/0"
      },
      {
        action   = "accept"
        port     = 80
        protocol = "TCP"
        ip_range = "0.0.0.0/0"
      },
      {
        action   = "accept"
        port     = 443
        protocol = "TCP"
        ip_range = "0.0.0.0/0"
      },
      {
        action   = "accept"
        port     = 6443
        protocol = "TCP"
        ip_range = "0.0.0.0/0"
      }
    ]
    outbound = [
      {
        action   = "accept"
        port     = 0
        protocol = "TCP"
        ip_range = "0.0.0.0/0"
      },
      {
        action   = "accept"
        port     = 0
        protocol = "UDP"
        ip_range = "0.0.0.0/0"
      }
    ]
  }
}

# Configuration système
variable "timezone" {
  description = "Fuseau horaire du système"
  type        = string
  default     = "Europe/Paris"
}

variable "packages" {
  description = "Packages système à installer"
  type        = list(string)
  default = [
    "curl",
    "wget", 
    "git",
    "unzip",
    "htop",
    "tree",
    "jq"
  ]
}

# Tags
variable "tags" {
  description = "Tags à appliquer aux ressources"
  type        = list(string)
  default     = ["k3s", "migration", "terraform"]
}

# Variables d'environnement
variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition = contains([
      "dev", "staging", "prod"
    ], var.environment)
    error_message = "Environment must be dev, staging or prod."
  }
}

# Scaleway variables for External DNS
variable "scaleway_access_key" {
  description = "Scaleway access key for External DNS"
  type        = string
  sensitive   = true
}

variable "scaleway_secret_key" {
  description = "Scaleway secret key for External DNS"
  type        = string
  sensitive   = true
}

variable "scaleway_organization_id" {
  description = "Scaleway organization ID"
  type        = string
  sensitive   = true
}

variable "scaleway_project_id" {
  description = "Scaleway project ID"
  type        = string
  sensitive   = true
}
