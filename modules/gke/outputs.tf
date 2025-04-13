output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.gke_cluster.name
}

output "sa_gke_cluster_email" {
  description = "Service Account using by GKE Cluster"
  value       = google_service_account.sa_gke_cluster.email
}