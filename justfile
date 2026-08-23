set shell := ["bash", "-uc"]

# Bootstrap the shared S3 remote-state bucket (safe to re-run, one-time in
# practice). Shared across develop/staging/production - only each
# environment's backend.tfvars `key` differs. State locking is via S3's
# native use_lockfile (see backend.tf), no DynamoDB table needed.
bootstrap-backend:
    ./scripts/bootstrap-backend.sh

# terraform init against one environment's backend config. -reconfigure is
# required whenever switching between environments in this same working
# directory, since each points at a different backend "key".
init env="develop":
    terraform init -reconfigure -backend-config=environments/{{env}}/backend.tfvars

plan env="develop": (init env)
    terraform validate
    terraform plan -var-file=environments/{{env}}/{{env}}.tfvars -var-file=environments/{{env}}/secrets.tfvars

apply env="develop": (init env)
    terraform validate
    terraform apply -var-file=environments/{{env}}/{{env}}.tfvars -var-file=environments/{{env}}/secrets.tfvars -auto-approve

# Tear down infrastructure. Run `just destroy-app <env>` in
# ../microservice_1/kubernetes FIRST - the ALB the AWS Load Balancer
# Controller creates for transaction-gateway's Ingress isn't a Terraform
# resource, and its security groups/ENIs can block this from deleting the VPC
# if it's still around.
destroy env="develop": (init env)
    terraform destroy -var-file=environments/{{env}}/{{env}}.tfvars -var-file=environments/{{env}}/secrets.tfvars -auto-approve

# The github-actions-oidc/ singleton is a separate root module/state - apply
# it once, independent of any environment.
init-github-oidc:
    cd github-actions-oidc && terraform init -backend-config=backend.tfvars

apply-github-oidc: init-github-oidc
    cd github-actions-oidc && terraform validate && terraform apply -auto-approve
