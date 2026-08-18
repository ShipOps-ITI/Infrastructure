# Infrastructure: Recover & Install Guide

This document describes step-by-step commands to recreate and configure the environment if the bastion, EKS cluster, or other resources are destroyed and you need to reapply everything. It also covers installing Helm apps (Jenkins, ArgoCD, Argo Image Updater, External Secrets, cert-manager), StorageClass, and how to access the cluster from your laptop via SSM and port-forwarding.

Prerequisites
- AWS CLI configured with a profile that has required permissions (example profile: `dev`).
- `terraform` (>=1.8), `kubectl`, `helm`, and `aws-session-manager-plugin` available locally.
- If you use the bastion instance role for AWS access, ensure the instance profile includes `eks:DescribeCluster`, `s3`, and other required permissions.

Quick overview
1. Terraform: provision VPC, bastion, EKS, node groups, and addons.
2. Wait for nodes and addons (EBS CSI) to be healthy.
3. Configure kubeconfig on a machine with network access to the EKS endpoint (bastion via SSM).
4. Apply StorageClass and Helm charts in the correct order.
5. Use SSM to access bastion and run kubectl/helm inside VPC (recommended for private clusters).

Commands

1) Recreate infrastructure with Terraform

From the `environments/dev` folder:
```bash
cd environments/dev
terraform init
terraform apply -auto-approve
```

Notes:
- If you only need to recreate a node group or addon, use `-target` to scope the apply (example below).

2) If node group creation fails (capacity/instance type) — adjust `environments/dev/terraform.tfvars`:
```hcl
node_instance_types = ["t3.small"]
node_group_min_size = 2
node_group_desired_size = 3
node_group_max_size = 5
```
Then re-run `terraform plan`/`apply` targeting the node group:
```bash
terraform plan -target=module.eks.aws_eks_node_group.this -out=nodegroup.plan
terraform apply -auto-approve nodegroup.plan
```

3) Wait for nodes Ready, then install EBS CSI addon (if not using Terraform addon):
```bash
# check addon status
aws eks describe-addon --cluster-name <cluster-name> --addon-name aws-ebs-csi-driver --region <region> --profile <profile> --output json

# If using TF addon: terraform apply -target=module.eks.aws_eks_addon.ebs_csi
```

4) Accessing a private EKS cluster via bastion (SSM)

- Start an SSM session to the bastion instance (from laptop):
```bash
# find bastion instance-id (from terraform output or AWS console)
aws ssm start-session --target <instance-id> --profile dev
```

- Inside the bastion shell (SSM session), configure kubeconfig:
```bash
aws eks update-kubeconfig --name <cluster-name> --region <region> --profile dev
kubectl get nodes
```

5) Apply StorageClass (must exist before installing apps that create PVCs):
```bash
kubectl apply -f modules/eks/storageclass-ebs.yaml
kubectl get sc
```

6) Install Jenkins (inside bastion)

- Ensure `modules/jenkins/jenkins-values.yaml` has `persistence.storageClass: ebs-sc` or `persistence.existingClaim` set.
- Install with Helm:
```bash
helm repo add jenkins https://charts.jenkins.io
helm repo update
helm upgrade --install jenkins jenkins/jenkins -n jenkins --create-namespace -f modules/jenkins/jenkins-values.yaml
kubectl get pvc -n jenkins
kubectl get pods -n jenkins -o wide
```

If a PVC already exists with a different `storageClass`, you must either migrate data or delete the PVC/PV before Helm can create a new PVC with `ebs-sc` (see notes below).

7) Install ArgoCD and Argo Image Updater (inside bastion)

- ArgoCD (recommended via Helm):
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace
```

- Argo Image Updater (use the official chart or manifests):
```bash
helm upgrade --install argocd-image-updater argo/argo-cd-image-updater -n argocd -f modules/argo/argocd-image-updater-values.yaml
```

8) External Secrets Operator

```bash
helm repo add external-secrets https://external-secrets.github.io/kubernetes-external-secrets/
helm repo update
helm upgrade --install external-secrets external-secrets/kubernetes-external-secrets -n external-secrets --create-namespace
```

Then configure External Secrets to use AWS Secrets Manager via IRSA (create IAM role for service account with SecretsManager read permissions).

9) cert-manager and Ingress controller (optional)

```bash
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.10.0/cert-manager.yaml
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
```

10) Access ArgoCD UI from your laptop (via bastion port-forward)

- Option A — port-forward from bastion (recommended for private clusters):
  - Start SSM session to bastion:
    ```bash
    aws ssm start-session --target <bastion-instance-id> --profile dev
    ```
  - On bastion run:
    ```bash
    kubectl port-forward -n argocd svc/argocd-server 8080:443
    ```
  - On your laptop, open `https://localhost:8080` (will be forwarded through SSM session).

- Option B — start SSM port forwarding session directly (bastion must have SSM agent):
```bash
aws ssm start-session --target <bastion-instance-id> --document-name AWS-StartPortForwardingSession --parameters '{"portNumber":["8080"],"localPortNumber":["8080"]}' --profile dev
# then on bastion (in session) run kubectl port-forward as above or forward directly to argocd service port
```

11) Port-forward Jenkins UI (after install)

Start SSM session to bastion and run:
```bash
kubectl port-forward -n jenkins svc/jenkins 8080:8080
# open http://localhost:8080
```

12) If PVC/PV stuck in Terminating after delete
- Remove finalizers to force deletion (inside bastion):
```bash
kubectl patch pvc <pvc-name> -n <ns> -p '{"metadata":{"finalizers":null}}' --type=merge
kubectl patch pv <pv-name> -p '{"metadata":{"finalizers":null}}' --type=merge
```

13) Recommended post-install tasks
- Secure Jenkins: change admin password, enable HTTPS via ingress + cert-manager.
- Configure IRSA roles and attach policies for External Secrets (SecretsManager) and Argo Image Updater (ECR read/list), then patch Helm charts to use serviceAccount with IRSA annotation.

StorageClass/PVC migration note
- You cannot change `storageClassName` on an existing bound PVC. Either migrate data to a new PVC (mount both PVCs in a temporary pod and copy files), or delete the PVC/PV and let Helm recreate it (data loss).

Troubleshooting
- If EBS CSI addon is `DEGRADED`, check `kubectl get pods -n kube-system` and `kubectl describe pod <csi-pod>` for scheduling issues. Ensure node capacity and IAM policy `AmazonEBSCSIDriverPolicy` is attached to node role.
- If Helm fails with plugin manager errors for Jenkins, avoid auto-installing plugins from Helm values — install safe plugin versions manually via `jenkins-plugin-cli` or Jenkins UI.

If you want, I can also:
- Add Terraform `helm_release` resources to automate Helm installs in the repo, or
- Create a small `scripts/restore.sh` that runs the essential commands in order (you'll still need to confirm/enter AWS profile and instance-id interactively).
# Infrastructure