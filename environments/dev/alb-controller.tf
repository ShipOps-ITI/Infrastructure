############################################################
# AWS Load Balancer Controller - Terraform implementation
# - Creates IAM policy (fetched from upstream)
# - Creates IAM role for controller (IRSA via OIDC)
# - Creates a Kubernetes ServiceAccount annotated with the role ARN
# - Installs the controller via Helm
# This file assumes existing modules: module.eks and module.vpc are present in this environment.
############################################################

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# Fetch official IAM policy for AWS Load Balancer Controller from upstream (kubernetes-sigs repo)
data "http" "alb_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

# Create IAM policy
resource "aws_iam_policy" "alb_controller" {
  name        = "${var.project_name}-${var.environment}-alb-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller (managed via Terraform)"
  policy      = data.http.alb_iam_policy.response_body
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create IAM role for the controller (IRSA style trust to OIDC provider)
resource "aws_iam_role" "alb_controller" {
  name = "${var.project_name}-${var.environment}-alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = module.eks.cluster_oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller",
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

# Configure Kubernetes provider (uses the cluster data and auth token)
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# Create ServiceAccount in kube-system and annotate with role ARN (IRSA)
resource "kubernetes_service_account" "alb" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      # Annotate with the IAM role for IRSA
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
  }

  depends_on = [module.eks]
}

# Install the Helm chart for AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  create_namespace = false

  # Pin a reasonably recent stable version; you can adjust as needed
  version = "1.11.3"

  values = [yamlencode({
    clusterName = module.eks.cluster_name,
    region      = var.aws_region,
    vpcId       = module.vpc.vpc_id,
    serviceAccount = {
      create = false,
      name   = kubernetes_service_account.alb.metadata[0].name,
    }
  })]

  depends_on = [aws_iam_role_policy_attachment.alb_attach, kubernetes_service_account.alb]
}

output "alb_controller_iam_role_arn" {
  value = aws_iam_role.alb_controller.arn
}

output "alb_helm_release_status" {
  value = helm_release.aws_load_balancer_controller.status
}
