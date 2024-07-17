locals {
  name            = "cilium-demo"
  cluster_version = "1.30"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.18"

  bootstrap_self_managed_addons = false

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  vpc_id     = data.aws_vpc.vpc.id
  subnet_ids = data.aws_subnets.private_subnets.ids

  # cluster_addons = {
  #   coredns = {}
  #   kube-proxy = {}
  # }

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

