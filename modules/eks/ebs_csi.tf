/*
  Installs the AWS EBS CSI driver as an EKS add-on and ensures the
  node group role has the managed policy required for dynamic provisioning.

  Place alongside other EKS module resources. The addon requires the
  EKS cluster to be created first.
*/

resource "aws_eks_addon" "ebs_csi" {
  cluster_name      = aws_eks_cluster.this.name
  addon_name        = "aws-ebs-csi-driver"

  # optional: pin to a version
  # addon_version = "v1.11.0-eksbuild.1"

  depends_on = [aws_eks_cluster.this]
}

resource "aws_iam_role_policy_attachment" "node_ebs_csi" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
