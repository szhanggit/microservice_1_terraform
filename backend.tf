# Bucket/key/region are left blank - filled in at `terraform init` time via
# -backend-config=environments/<env>/backend.tfvars, one file per environment
# (develop/staging/production). Same pattern as microservice_0: one shared S3
# bucket ("steven-zhang-learning"), only the state `key` differs per
# environment (microservice1_dev|_stage|_prod/terraform.tfstate) - so develop/
# staging/production never share state despite living in the same bucket.
#
# use_lockfile enables Terraform's native S3 state locking (Terraform >= 1.10,
# no DynamoDB table needed) - same for every environment so it's hardcoded
# here rather than repeated in each backend.tfvars.
terraform {
  backend "s3" {
    bucket       = ""
    key          = ""
    region       = ""
    encrypt      = true
    use_lockfile = true
  }
}
