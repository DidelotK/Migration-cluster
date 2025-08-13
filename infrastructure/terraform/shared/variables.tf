# Shared variables for all environments

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
  description = "Scaleway region"
  type        = string
  default     = "fr-par"
}

variable "scw_zone" {
  description = "Scaleway zone"
  type        = string
  default     = "fr-par-1"
}

# Common tags
variable "default_tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default = {
    Project   = "k3s-migration"
    ManagedBy = "terraform"
  }
}

variable "additional_tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
