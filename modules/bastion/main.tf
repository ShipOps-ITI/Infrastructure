resource "aws_iam_role" "bastion" {
  name = "${var.name}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name}-bastion-profile"
  role = aws_iam_role.bastion.name
}

resource "aws_security_group" "bastion" {
  name        = "${var.name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-bastion-sg"
  }
}

resource "aws_instance" "bastion" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = false

  vpc_security_group_ids = [
    aws_security_group.bastion.id
  ]

  iam_instance_profile = aws_iam_instance_profile.bastion.name

  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "${var.name}-bastion"
  }
}

resource "aws_iam_role_policy" "bastion_eks" {
  name = "${var.name}-eks-access"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "eks:DescribeCluster"
        ]

        Resource = "*"
      }
    ]
  })
}

# Data for account and region to construct ARNs for backend resources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Inline policy granting access to the Terraform S3 backend and DynamoDB lock table
resource "aws_iam_role_policy" "bastion_terraform_state" {
  name = "${var.name}-terraform-state-access"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::ahmedyasser02-terraform-state",
          "arn:aws:s3:::ahmedyasser02-terraform-state/dev/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:UpdateItem",
          "dynamodb:DescribeTable",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/terraform-locks"
      }
    ]
  })
}

# Inline read-only policy to allow Terraform plan operations that query AWS resources
# (EC2 Describe*, IAM GetRole/GetRolePolicy and related read actions). This is
# intentionally read-only and scoped to the account where resource ARNs require it.
resource "aws_iam_role_policy" "bastion_terraform_readonly" {
  name = "${var.name}-bastion-readonly"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListRoles"
        ]

        Resource = "*"
      },
      {
        Effect = "Allow"

        Action = [
          "ec2:DescribeImages",
          "ec2:DescribeAddresses",
          "ec2:DescribeAddressesAttribute",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeRouteTables",
          "ec2:DescribeNatGateways"
        ]

        Resource = "*"
      }
    ]
  })
}

