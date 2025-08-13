# Backend bucket information
output "bucket_name" {
  description = "Name of the Terraform state bucket"
  value       = scaleway_object_bucket.terraform_state.name
}

output "bucket_endpoint" {
  description = "Endpoint URL of the bucket"
  value       = scaleway_object_bucket.terraform_state.endpoint
}

output "bucket_region" {
  description = "Region of the bucket"
  value       = scaleway_object_bucket.terraform_state.region
}

# Backend configuration for other environments
output "backend_config" {
  description = "Backend configuration for Terraform"
  value = {
    bucket     = scaleway_object_bucket.terraform_state.name
    key        = "environments/${var.project_name}"
    region     = scaleway_object_bucket.terraform_state.region
    endpoint   = scaleway_object_bucket.terraform_state.endpoint
    access_key = var.scw_access_key
    secret_key = var.scw_secret_key
  }
  sensitive = true
}

# Information for manual backend configuration
output "backend_config_hcl" {
  description = "Backend configuration in HCL format"
  value = <<-EOT
terraform {
  backend "s3" {
    bucket                      = "${scaleway_object_bucket.terraform_state.name}"
    key                         = "environments/dev/terraform.tfstate"
    region                      = "${scaleway_object_bucket.terraform_state.region}"
    endpoint                    = "${scaleway_object_bucket.terraform_state.endpoint}"
    access_key                  = "$${var.scw_access_key}"
    secret_key                  = "$${var.scw_secret_key}"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
EOT
}
