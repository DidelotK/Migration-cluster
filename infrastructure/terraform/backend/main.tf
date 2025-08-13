terraform {
  required_version = ">= 1.0"
  
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.0"
    }
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

# S3 bucket for Terraform state
resource "scaleway_object_bucket" "terraform_state" {
  name   = var.bucket_name
  region = var.scw_region
  
  tags = merge(var.default_tags, {
    Name        = "Terraform State Bucket"
    Purpose     = "terraform-backend"
    Environment = "shared"
  })
}

# Bucket versioning
resource "scaleway_object_bucket_policy" "terraform_state_policy" {
  bucket = scaleway_object_bucket.terraform_state.name
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInsecureConnections"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          scaleway_object_bucket.terraform_state.name,
          "${scaleway_object_bucket.terraform_state.name}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Optional: Lock table for state locking (using tags for now)
resource "scaleway_object" "state_lock_info" {
  bucket = scaleway_object_bucket.terraform_state.name
  key    = ".terraform-lock-info"
  content = jsonencode({
    purpose = "terraform-state-locking-info"
    created = timestamp()
    project = var.project_name
  })
  
  metadata = {
    purpose = "terraform-lock-info"
    project = var.project_name
  }
}
