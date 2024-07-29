# Cilium and Prefix Delegation on Amazon EKS

This guide demonstrates how to install Cilium with Prefix Delegation on Amazon EKS using bare clusters (bootstrap_self_managed_addons=false). The process is divided into several steps.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed (version 1.0.0 or later)
- kubectl installed and configured
- Cilium CLI installed (instructions below)

## Step-by-Step Guide

### Deploy VPC

Create the necessary VPC infrastructure:

```bash
cd 1_vpc
terraform init
terraform apply
```

### Deploy EKS Cluster

Set up the Amazon EKS cluster:

```bash
cd 2_eks
terraform init
terraform apply -var="remove_kube_proxy=false"
terraform apply
```

Kube proxy is required when cilium controller starts, but then when cilium is running can be removed.


### Verify Cilium

Check status
```bash
cilium status
```
Expected output:
```
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (using embedded mode)
 \__/¯¯\__/    Hubble Relay:       OK
    \__/       ClusterMesh:        disabled

Deployment             hubble-ui          Desired: 1, Ready: 1/1, Available: 1/1
Deployment             hubble-relay       Desired: 1, Ready: 1/1, Available: 1/1
DaemonSet              cilium             Desired: 2, Ready: 2/2, Available: 2/2
Deployment             cilium-operator    Desired: 1, Ready: 1/1, Available: 1/1
Containers:            cilium-operator    Running: 1
                       cilium             Running: 2
                       hubble-ui          Running: 1
                       hubble-relay       Running: 1
Cluster Pods:          8/8 managed by Cilium
Helm chart version:
Image versions         cilium             quay.io/cilium/cilium:v1.15.7@sha256:2e432bf6879feb8b891c497d6fd784b13e53456017d2b8e4ea734145f0282ef0: 2
                       hubble-ui          quay.io/cilium/hubble-ui:v0.13.1@sha256:e2e9313eb7caf64b0061d9da0efbdad59c6c461f6ca1752768942bfeda0796c6: 1
                       hubble-ui          quay.io/cilium/hubble-ui-backend:v0.13.1@sha256:0e0eed917653441fded4e7cdb096b7be6a3bddded5a2dd10812a27b1fc6ed95b: 1
                       hubble-relay       quay.io/cilium/hubble-relay:v1.15.7@sha256:12870e87ec6c105ca86885c4ee7c184ece6b706cc0f22f63d2a62a9a818fd68f: 1
                       cilium-operator    quay.io/cilium/operator-aws:v1.15.7@sha256:bb4085da666a5c7a7c6f8135f0de10f0b6895dbf561e9fccda0e272b51bb936e: 1
```

### Verify Node Configuration

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
  memory:             7291828Ki
  pods:               110
```

### Deploy Sample Application

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
kubectl delete deployment nginx
cd 2_eks && terraform destroy
cd 1_vpc && terraform destroy
```

## Additional Resources

- [Cilium Documentation](https://docs.cilium.io/)
- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Amazon EKS Blueprints for Terraform](https://aws-ia.github.io/terraform-aws-eks-blueprints/)

For more information or support, please open an issue in this repository.