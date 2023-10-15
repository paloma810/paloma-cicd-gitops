# network
module "gke" {
  source = "../../../modules/gke"

  project_id   = var.project_id
  project_name = var.project_name

  /* GKEの書くサブネット範囲（CIDR）の制限は下記の通り */
  // 特にPod/ServiceのCIDRは、そのセカンダリIP範囲をGKEが管理するか、ユーザが管理するかによって
  // 最小範囲ののCIDRが変わるので注意
  // https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips?hl=ja#range_management

  gke_master_ip_cidr   = "192.168.100.0/28"
  gke_pods_ip_cidr     = "192.168.101.0/24"
  gke_services_ip_cidr = "192.168.102.0/24"

}
