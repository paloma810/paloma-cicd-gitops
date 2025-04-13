# VPC ID
output "vpc_id" {
  description = "ID of project VPC"
  value       = aws_vpc.paloma-dv-vpc01[0].id
}

# Public Route01 ID
output "pub_rt01_id" {
  description = "ID of public route01"
  value       = aws_route_table.paloma-dv-pub-rt01[0].id
}

# Private Route01 ID
output "pri_rt01_id" {
  description = "ID of private route01"
  value       = aws_route_table.paloma-dv-pri-rt01[0].id
}
