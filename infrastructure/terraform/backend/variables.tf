# Scaleway credentials
variable "scw_access_key" {
  description = "Scaleway access key"
  type        = string
  sensitive   = true
}

variable "scw_secret_key" {
  description = "Scaleway secret key"
  type        = string
  sensitive   = true
}

variable "scw_organization_id" {
  description = "Scaleway organization ID"
  type        = string
}

variable "scw_project_id" {
  description = "Scaleway project ID"
  type        = string
}

variable "scw_region" {
  description = "Scaleway region for resources"
  type        = string
  default     = "fr-par"
}

variable "scw_zone" {
  description = "Scaleway zone for resources"
  type        = string
  default     = "fr-par-1"
}

# Backend configuration
variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "k3s-migration-terraform-state"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "k3s-migration"
}

# Tags
variable "default_tags" {
  description = "Default tags for all resources"
  type        = map(string)
  default = {
    Project     = "k3s-migration"
    ManagedBy   = "terraform"
    Environment = "shared"
  }
}
