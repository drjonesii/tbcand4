output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

output "vpc_endpoint_ssm_id" {
  description = "The ID of the SSM VPC endpoint"
  value       = aws_vpc_endpoint.ssm.id
}

output "vpc_endpoint_ssmmessages_id" {
  description = "The ID of the SSM Messages VPC endpoint"
  value       = aws_vpc_endpoint.ssmmessages.id
}

output "vpc_endpoint_ec2messages_id" {
  description = "The ID of the EC2 Messages VPC endpoint"
  value       = aws_vpc_endpoint.ec2messages.id
}

output "sns_topic_arn" {
  description = "ARN of the infrastructure alerts SNS topic"
  value       = aws_sns_topic.infrastructure_alerts.arn
}

# Add missing outputs for tests
output "nat_gateway_id" {
  description = "ID of the first NAT Gateway"
  value       = aws_nat_gateway.main[0].id
}

output "s3_endpoint_id" {
  description = "ID of the S3 VPC endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "s3_endpoint_dns_entry" {
  description = "DNS entry for the S3 VPC endpoint"
  value       = "s3.${data.aws_region.current.name}.amazonaws.com"
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the first private route table"
  value       = aws_route_table.private[0].id
}

# Add VPC flow log outputs
output "vpc_flow_log_group_name" {
  description = "Name of the VPC Flow Log group"
  value       = aws_cloudwatch_log_group.vpc_flow_log.name
}

output "vpc_flow_log_stream_name" {
  description = "Name of the VPC Flow Log stream"
  value       = aws_cloudwatch_log_stream.vpc_flow_log_stream.name
}
