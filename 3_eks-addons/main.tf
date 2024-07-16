locals {
  name            = "cilium-demo"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = local.name
  addon_name   = "coredns"

  tags = local.tags
}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name = local.name
  addon_name   = "kube-proxy"

  tags = local.tags
}















locals {

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/gitops-bridge-dev/gitops-bridge"
  }
}