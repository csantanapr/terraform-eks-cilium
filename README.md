# Example on how to install Cilium and Prefix Delegation on Amazon EKS on bare clusters

## Deploy VPC
```bash
cd 1_vpc
terraform init
terraform apply
```

## Deploy EKS Cluster
```bash
cd 2_eks
terraform init
terraform apply
```

## Deploy EKS Addons (coredns, kube-proxy)
```bash
cd 3_eks_addons
terraform init
terraform apply
```

## Deploy Cilium
Install Cilium CLI from https://github.com/cilium/cilium-cli

Inspect non-default Helm values to stdout without performing the actual installation
```bash
cilium install --dry-run-helm-values
```
Expected output
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

Set the Cluster Name explicitly
```bash
export CLUSTER_NAME=cilium-demo
```

> Using cluster name arn:aws:eks:us-west-2:015299085168:cluster/cilium-demo doesn't work need to use name with out `:`
Install cilium
```bash
cilium install \
  --set cluster.name=${CLUSTER_NAME} \
  --set eni.awsEnablePrefixDelegation=true
```

## Deploy Nodes
```bash
cd 4_eks_nodegroup
terraform init
terraform apply
```

Check that Nodes can allocate more than 29 pods
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
--
```

## Deploy sample app
Deploy 100 pods
```bash
kubectl create deployment nginx --image nginx
kubectl scale deployment nginx --replicas=100
```

Without prefix delegation each node can only do 29 pods, we have 2 nodes, deploying 100 would mean prefix delegation is working
```bash
kubectl get pods -o wide | grep Running | wc -l
```
Expected output
```
100
```