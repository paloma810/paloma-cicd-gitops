# GKE クラスタを作成する VPC
resource "google_compute_network" "gke_vpc" {
  project                 = var.project_id
  name                    = "${var.project_name}-tnvpc01"
  description             = "This is a VPC for GKE Cluster"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  mtu                     = 1460
  #delete_default_routes_on_create = true
}

# GKE クラスタを作成する VPCのサブネット（セカンダリ含む）
resource "google_compute_subnetwork" "gke_vpc_subnet" {
  project                  = var.project_id
  name                     = "${var.project_name}-tnvpc01-subnet01"
  description              = "This is a Subnet on VPC for GKE Cluster"
  network                  = google_compute_network.gke_vpc.self_link
  ip_cidr_range            = var.gke_master_ip_cidr
  private_ip_google_access = true
  secondary_ip_range = [
    {
      range_name    = "${var.project_name}-tnvpc01-subnet01-secipr-pod"
      ip_cidr_range = var.gke_pods_ip_cidr
    },
    {
      range_name    = "${var.project_name}-tnvpc01-subnet01-secipr-service"
      ip_cidr_range = var.gke_services_ip_cidr
    }
  ]
}

# Worker Node用のサービスアカウント
resource "google_service_account" "sa_gke_cluster" {
  account_id   = "sa-gke-cluster"
  display_name = "Service Account For Terraform To Make GKE Cluster"
}

# GKE クラスタ
resource "google_container_cluster" "gke_cluster" {
  project = var.project_id

  name = "${var.project_name}-gke-cluster01"
  # Autopilotは有効化しない
  #enable_autopilot = true
  location   = "asia-northeast1-a"
  network    = google_compute_network.gke_vpc.self_link
  subnetwork = google_compute_subnetwork.gke_vpc_subnet.self_link

  deletion_protection       = false
  remove_default_node_pool  = true
  initial_node_count        = 1 #これ必要ある？
  default_max_pods_per_node = 100
  addons_config {
    horizontal_pod_autoscaling {
      disabled = true
    }
    http_load_balancing {
      disabled = true
    }
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "${var.project_name}-tnvpc01-subnet01-secipr-pod"
    services_secondary_range_name = "${var.project_name}-tnvpc01-subnet01-secipr-service"
  }

  # 限定公開クラスタの設定
  /*
    private_cluster_config {
        enable_private_nodes    = true
        enable_private_endpoint = true
        master_ipv4_cidr_block  = local.gke_master_ip
    }
    */

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  master_authorized_networks_config {
    # コントロールプレーンへのアクセスを許可する IP 範囲
    cidr_blocks {
      cidr_block = google_compute_subnetwork.gke_vpc_subnet.ip_cidr_range # ノードと踏み台が作られるサブネットからのアクセスを許可
    }
  }
}
resource "google_container_node_pool" "gke_nodes" {
  name       = "${var.project_name}-gke-nodes01"
  location   = "asia-northeast1-a"
  cluster    = google_container_cluster.gke_cluster.name
  node_count = 1
  /*
  autoscaling {gcloud container clusters get-credentials
    min_node_count = 1
    max_node_count = 2
  }
  */

  node_config {
    preemptible  = true
    machine_type = "n2-standard-4"
    disk_size_gb = 30

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.sa_gke_cluster.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

}
