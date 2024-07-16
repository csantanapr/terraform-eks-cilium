locals {
  name            = "cilium-demo"
  cluster_version = "1.30"
}

module "eks" {

  source = "github.com/csantanapr/terraform-aws-eks?ref=bootstrap_self_managed_addons"

  # From my private fork
  bootstrap_self_managed_addons = false

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  # set vpc_id to the vpc with name local.name
  vpc_id = data.aws_vpc.vpc.id
  # set the subnet_ids to the private subnets
  subnet_ids = data.aws_subnets.private_subnets.ids

  tags = local.tags
}











locals {

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/gitops-bridge-dev/gitops-bridge"
  }
}

# get data source for vpc with name local.name
data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = [local.name]
  }
}
# get data source for private subnets from vpc with tag Name = local.name
data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}




output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = <<-EOT
    export KUBECONFIG="/tmp/${module.eks.cluster_name}"
    aws eks update-kubeconfig --name ${module.eks.cluster_name}
  EOT
}


locals {
  # Just to ensure templating doesn't fail when values are not provided
  ssm_cluster_version = local.cluster_version
  # Map the AMI type to the respective SSM param path
  ssm_ami_type_to_ssm_param = {
    AL2_x86_64                 = "/aws/service/eks/optimized-ami/${local.ssm_cluster_version}/amazon-linux-2/recommended/image_id"
    AL2_x86_64_GPU             = "/aws/service/eks/optimized-ami/${local.ssm_cluster_version}/amazon-linux-2-gpu/recommended/image_id"
    AL2_ARM_64                 = "/aws/service/eks/optimized-ami/${local.ssm_cluster_version}/amazon-linux-2-arm64/recommended/image_id"
  }
  # Based on the steps above, try to get an AMI release version - if not, `null` is returned
  latest_ami_release_version = try(nonsensitive(data.aws_ssm_parameter.ami.value), null)
}

data "aws_ssm_parameter" "ami" {
  name = local.ssm_ami_type_to_ssm_param["AL2_x86_64"]
}