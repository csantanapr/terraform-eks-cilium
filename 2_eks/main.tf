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

  cluster_addons = {
    kube-proxy = {}
  }

  tags = local.tags
}

# Do cilium and kube-proxy after eks
# Race coredns and nodes


resource "helm_release" "cilium" {
  name             = "cilium"
  description      = "A Helm chart to deploy cilium"
  namespace        = "kube-system"
  chart            = "cilium"
  version          = "1.15.7"
  repository       = "https://helm.cilium.io/"
  values           = [file("${path.module}/values/cilium.yaml")]

  depends_on = [module.eks]
}

resource "aws_eks_addon" "coredns" {
  cluster_name = local.name
  addon_name   = "coredns"

  tags = local.tags

  depends_on = [helm_release.cilium]
}


locals {
  ami_type = "AL2_x86_64"
}

module "eks_nodegroup" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "~> 20.18"

  name = local.name

  cluster_name    = local.name
  cluster_version = local.cluster_version
  # set the subnet_ids to the private subnets
  subnet_ids = data.aws_subnets.private_subnets.ids

  cluster_service_cidr = "172.20.0.0/16"

  ami_id                     = local.latest_ami_release_version
  ami_type                   = local.ami_type
  instance_types             = ["m6i.large"]
  min_size                   = 2
  max_size                   = 3
  desired_size               = 2
  enable_bootstrap_user_data = true

  # Using --show-max-allowed would print the maximum allowed by ENI IPs, not having this flag caps the Max to 110 or 250 (30 or more CPUs)
  post_bootstrap_user_data = <<-EOT
    KUBELET_CONFIG=/etc/kubernetes/kubelet/kubelet-config.json
    MAX_PODS=$(/etc/eks/max-pods-calculator.sh --instance-type-from-imds --cni-version 1.10.0 --cni-prefix-delegation-enabled)
    echo "$(jq ".maxPods=$MAX_PODS" $KUBELET_CONFIG)" > $KUBELET_CONFIG
    systemctl restart kubelet
  EOT

  taints = {
    # taint nodes so that application pods are
    # not scheduled/executed until Cilium is deployed.
    addons = {
      key    = "node.cilium.io/agent-not-ready"
      value  = "true"
      effect = "NO_EXECUTE"
    },
  }

  iam_role_additional_policies = {
    Cilium_Policy = aws_iam_policy.aws_cilium_policy.arn
  }

  tags = local.tags

  depends_on = [helm_release.cilium]
}

locals {
  # Just to ensure templating doesn't fail when values are not provided
  ssm_cluster_version = local.cluster_version
  # Map the AMI type to the respective SSM param path
  ssm_ami_type_to_ssm_param = {
    AL2_x86_64     = "/aws/service/eks/optimized-ami/${local.ssm_cluster_version}/amazon-linux-2/recommended/image_id"
    AL2_x86_64_GPU = "/aws/service/eks/optimized-ami/${local.ssm_cluster_version}/amazon-linux-2-gpu/recommended/image_id"
    AL2_ARM_64     = "/aws/service/eks/optimized-ami/${local.ssm_cluster_version}/amazon-linux-2-arm64/recommended/image_id"
  }
  # Based on the steps above, try to get an AMI release version - if not, `null` is returned
  latest_ami_release_version = try(nonsensitive(data.aws_ssm_parameter.ami.value), null)
}
data "aws_ssm_parameter" "ami" {
  name = local.ssm_ami_type_to_ssm_param[local.ami_type]
}
data "aws_iam_policy_document" "aws_cilium_policy" {
  # Adding extra permission according to docs https://docs.cilium.io/en/latest/network/concepts/ipam/eni/#required-privileges
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "ec2:CreateTags"
    ]
  }
}
resource "aws_iam_policy" "aws_cilium_policy" {
  name        = "${local.name}-add-cilium"
  description = "IAM Policy for Cilium"
  policy      = data.aws_iam_policy_document.aws_cilium_policy.json
  tags        = local.tags
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

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", local.name]
      command     = "aws"
    }
  }
}



output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = <<-EOT
    export KUBECONFIG="/tmp/${module.eks.cluster_name}"
    aws eks update-kubeconfig --name ${module.eks.cluster_name}
  EOT
}

