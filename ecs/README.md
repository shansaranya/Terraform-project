# Terraform to setup ECS Cluster

### Prerequisite 
* Install the following command line tools
1. Terraform

* Create the following file to store secrets for ECS cluster
```secrets-<env>.tfvars```

* Update the terraform vars file based on the env
```terraform-<env>.tfvars```

### Terraform commands
```bash
# Initialize terraform
$ terraform init

# Create Plan for the environment
$ terraform plan -var-file="secrets-dev.tfvars" -var-file="terraform-dev.tfvars" -out="out.plan"

# Apply the plan to provision the resources in cloud
$ terraform apply "out.plan"

# View the list of resources created in cloud
$ terraform state list

# To delete the resources created in cloud
$ terraform destroy -var-file="secrets-dev.tfvars" -var-file="terraform-dev.tfvars" -auto-approve

# To refresh the terraform state
$ terraform refresh -var-file="secrets-dev.tfvars" -var-file="terraform-dev.tfvars"
```