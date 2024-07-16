# Cilium and Prefix Delegation on Amazon EKS

This guide demonstrates how to install Cilium with Prefix Delegation on Amazon EKS using bare clusters. The process is divided into several steps, each managed by Terraform.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed (version 1.0.0 or later)
- kubectl installed and configured
- Cilium CLI installed (instructions below)

## Step-by-Step Guide

### 1. Deploy VPC

Create the necessary VPC infrastructure:

```bash
cd 1_vpc
terraform init
terraform apply
```

### 2. Deploy EKS Cluster

Set up the Amazon EKS cluster:

```bash
cd 2_eks
terraform init
terraform apply
```

### 3. Deploy EKS Addons

Install core DNS and kube-proxy:

```bash
cd 3_eks_addons
terraform init
terraform apply
```

### 4. Deploy Cilium

#### Install Cilium CLI

Download and install the Cilium CLI from the [official GitHub repository](https://github.com/cilium/cilium-cli).

#### Inspect Helm Values

View the non-default Helm values without performing the installation:

```bash
cilium install --dry-run-helm-values
```

Expected output:

```yaml
cluster:
  name: arn:aws:eks:us-west-2:015299085168:cluster/cilium-demo
egressMasqueradeInterfaces: eth0
eni:
  enabled: true
ipam:
  mode: eni
operator:
  replicas: 1
routingMode: native
```

#### Set Cluster Name

```bash
export CLUSTER_NAME=cilium-demo
```

Note: Using the full ARN as the cluster name doesn't work. Use the name without `:` characters.

#### Install Cilium

```bash
cilium install \
  --set cluster.name=${CLUSTER_NAME} \
  --set eni.awsEnablePrefixDelegation=true
```

### 5. Deploy Nodes

Create the EKS node group:

```bash
cd 4_eks_nodegroup
terraform init
terraform apply
```

### 6. Verify Node Configuration

Check that nodes can allocate more than 29 pods:

```bash
kubectl describe node | grep "node.kubernetes.io/instance-type"
kubectl describe node | grep "Allocatable:" -A 6
```

Expected output:

```
node.kubernetes.io/instance-type=m6i.large

Allocatable:
  cpu:                1930m
  ephemeral-storage:  18242267924
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             7291820Ki
  pods:               434
```

### 7. Deploy Sample Application

Deploy 100 nginx pods to test Prefix Delegation:

```bash
kubectl create deployment nginx --image nginx
kubectl scale deployment nginx --replicas=100
```

Verify that all pods are running:

```bash
kubectl get pods -o wide | grep Running | wc -l
```

Expected output: `100`

This confirms that Prefix Delegation is working correctly, as each node can now host more than the default 29 pods.

## Troubleshooting

If you encounter issues:

1. Check AWS credentials and permissions
2. Ensure all prerequisites are correctly installed
3. Verify VPC and subnet configurations
4. Check EKS cluster status in AWS console
5. Review Cilium logs: `cilium status` and `cilium connectivity test`

## Cleanup

To remove all created resources, run `terraform destroy` in each directory in reverse order:

```bash
cd 4_eks_nodegroup && terraform destroy
cd 3_eks_addons && terraform destroy
cd 2_eks && terraform destroy
cd 1_vpc && terraform destroy
```

## Additional Resources

- [Cilium Documentation](https://docs.cilium.io/)
- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform Documentation](https://www.terraform.io/docs/)

For more information or support, please open an issue in this repository.