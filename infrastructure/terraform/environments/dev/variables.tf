# Variables Scaleway
variable "scw_access_key" {
  description = "Clé d'accès Scaleway"
  type        = string
  sensitive   = true
}

variable "scw_secret_key" {
  description = "Clé secrète Scaleway"
  type        = string
  sensitive   = true
}

variable "scw_organization_id" {
  description = "ID de l'organisation Scaleway"
  type        = string
}

variable "scw_project_id" {
  description = "ID du projet Scaleway"
  type        = string
}

variable "scw_region" {
  description = "Région Scaleway"
  type        = string
  default     = "fr-par"
}

variable "scw_zone" {
  description = "Zone Scaleway"
  type        = string
  default     = "fr-par-1"
}

# Variables de l'instance
variable "instance_name" {
  description = "Nom de l'instance K3s"
  type        = string
  default     = "k3s-dev"
}

variable "instance_type" {
  description = "Type d'instance Scaleway"
  type        = string
  default     = "GP1-XS"
}

# Variables de stockage
variable "root_volume_size" {
  description = "Taille du volume racine en GB"
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "Type de volume racine"
  type        = string
  default     = "b_ssd"
}

# Variables SSH
variable "ssh_key_name" {
  description = "Nom de la clé SSH"
  type        = string
  default     = "k3s-dev-key"
}

variable "ssh_private_key_path" {
  description = "Chemin vers la clé privée SSH"
  type        = string
  default     = "~/.ssh/k3s_dev"
}

variable "create_ssh_key" {
  description = "Créer automatiquement une nouvelle clé SSH"
  type        = bool
  default     = true
}

# Variables réseau
variable "create_public_ip" {
  description = "Créer une IP publique statique"
  type        = bool
  default     = true
}

variable "enable_ipv6" {
  description = "Activer IPv6"
  type        = bool
  default     = true
}

# Variables système
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
    "jq",
    "vim",
    "python3",
    "python3-pip",
    "python3-kubernetes"
  ]
}

variable "timezone" {
  description = "Fuseau horaire du système"
  type        = string
  default     = "Europe/Paris"
}

# Variables K3s
variable "k3s_version" {
  description = "Version de K3s à installer"
  type        = string
  default     = "v1.28.5+k3s1"
}

variable "kubectl_version" {
  description = "Version de kubectl à installer"
  type        = string
  default     = "v1.28.5"
}

variable "helm_version" {
  description = "Version de Helm à installer"
  type        = string
  default     = "v3.13.3"
}

# Variables de tags
variable "default_tags" {
  description = "Tags par défaut"
  type        = list(string)
  default     = ["k3s", "dev", "terraform", "migration"]
}

variable "additional_tags" {
  description = "Tags supplémentaires"
  type        = list(string)
  default     = []
}
