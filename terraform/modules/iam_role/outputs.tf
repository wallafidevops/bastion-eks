output "iam_instance_profile_name" {
  description = "Nome do Instance Profile para associar na EC2"
  value       = aws_iam_instance_profile.ssm_instance_profile.name
}

output "iam_role_name" {
  value = aws_iam_role.ssm_role.name
}

output "iam_role_arn" {
  value = aws_iam_role.ssm_role.arn
}