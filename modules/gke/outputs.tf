output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.gke_cluster.name
}