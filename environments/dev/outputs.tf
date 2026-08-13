output "eks_cluster_id" {
  value = module.eks.cluster_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  value = module.eks.cluster_oidc_provider_arn
}

output "eks_node_group_role_arn" {
  value = module.eks.node_group_role_arn
}

output "eks_irsa_role_arns" {
  value = module.eks.irsa_role_arns
}
