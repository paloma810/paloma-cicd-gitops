# VPC ID
output "hub_vpc_self_link" {
  description = "ID of project VPC"
  value       = google_compute_network.hub_vpc.self_link
}
