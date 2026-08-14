output "instance_id" {
  value = aws_instance.bastion.id
}

output "private_ip" {
  value = aws_instance.bastion.private_ip
}

output "security_group_id" {
  value = aws_security_group.bastion.id
}

output "role_arn" {
  value = aws_iam_role.bastion.arn
}