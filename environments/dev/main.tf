data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames
  single_nat_gateway   = var.single_nat_gateway
}

module "bastion" {
  source = "../../modules/bastion"

  name          = "${var.project_name}-${var.environment}-bastion"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.private_subnet_ids[0]
  ami_id        = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"
}

module "eks" {
  source = "../../modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  cluster_name       = var.cluster_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  cluster_version         = var.cluster_version
  endpoint_private_access = var.endpoint_private_access
  endpoint_public_access  = var.endpoint_public_access

  node_group_desired_size = var.node_group_desired_size
  node_group_min_size     = var.node_group_min_size
  node_group_max_size     = var.node_group_max_size
  node_instance_types     = var.node_instance_types
  node_ami_type           = var.node_ami_type
  node_disk_size          = var.node_disk_size
  node_labels             = var.node_labels

  tags = {
    Name = "${var.project_name}-${var.environment}-eks"
  }

  irsa_service_accounts = var.irsa_service_accounts
}

module "ecr" {
  source = "../../modules/ecr"

  project_name     = var.project_name
  environment      = var.environment
  repository_names = var.ecr_repository_names
  scan_on_push     = true
  max_image_count  = var.ecr_max_image_count
}

resource "aws_vpc_security_group_ingress_rule" "eks_from_bastion" {
  security_group_id            = module.eks.cluster_security_group_id
  referenced_security_group_id = module.bastion.security_group_id

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

resource "aws_eks_access_entry" "bastion" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.bastion.role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.bastion.role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion]
}
