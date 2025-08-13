# Shared backend configuration template
# This file should be copied and customized for each environment

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

  # Backend configuration - uncomment and configure after backend setup
  # backend "s3" {
  #   bucket                      = "k3s-migration-terraform-state"
  #   key                         = "environments/ENVIRONMENT/terraform.tfstate"
  #   region                      = "fr-par"
  #   endpoint                    = "https://s3.fr-par.scw.cloud"
  #   access_key                  = var.scw_access_key
  #   secret_key                  = var.scw_secret_key
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  #   force_path_style            = true
  # }
}
