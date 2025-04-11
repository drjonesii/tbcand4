output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.main.id
}

output "instance_private_ip" {
  description = "The private IP of the EC2 instance"
  value       = aws_instance.main.private_ip
}

output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.instance.id
}

output "instance_public_ip" {
  description = "The public IP of the EC2 instance"
  value       = aws_instance.main.public_ip
}

output "instance_profile_name" {
  description = "The name of the IAM instance profile"
  value       = aws_iam_instance_profile.instance_profile.name
}

output "s3_policy_name" {
  description = "The name of the S3 access policy"
  value       = aws_iam_policy.s3_access.name
}

# Add CloudWatch log outputs
output "instance_log_group_name" {
  description = "Name of the EC2 instance log group"
  value       = aws_cloudwatch_log_group.instance_logs.name
}

output "instance_log_stream_name" {
  description = "Name of the EC2 instance log stream"
  value       = aws_cloudwatch_log_stream.instance_log_stream.name
}
