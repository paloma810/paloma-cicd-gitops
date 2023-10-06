# network
module "gke" {
  source = "../../../modules/gke"

  project_id           = var.project_id
  project_name         = var.project_name
  gke_master_ip_cidr   = "192.168.100.0/28"
  gke_pods_ip_cidr     = "192.168.101.0/24"
  gke_services_ip_cidr = "192.168.102.0/24"

}
