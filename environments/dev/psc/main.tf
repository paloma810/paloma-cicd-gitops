# VPCネットワーク設定
resource "google_compute_network" "vpc01_pscpoc" {
  provider                        = google
  name                            = "${var.project_name}-vpc01-pscpoc"
  description                     = "This is a VPC for PSC poc"
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  mtu                             = 1460
  delete_default_routes_on_create = true
}

# サブネット設定
resource "google_compute_subnetwork" "subnet01_pscpoc" {
  provider                 = google
  name                     = "${var.project_name}-subnet01-pscpoc"
  description              = "This is a Subnet for PSC poc"
  network                  = google_compute_network.vpc01_pscpoc.self_link
  ip_cidr_range            = "10.40.0.0/16"
  private_ip_google_access = true
}

# ファイアウォール設定
resource "google_compute_firewall" "firewall01_pscpoc_base" {
  provider = google

  name      = "${var.project_name}-firewall01-pscpoc-base"
  network   = google_compute_network.vpc01_pscpoc.self_link
  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["22", "3389", "8080", "3000"] # SSHとRDPとHTTPを許可
  }
  allow {
    protocol = "icmp" # ICMPを許可
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["pscpoc-base"]
}

# Nexus用ファイアウォール
resource "google_compute_firewall" "firewall01_pscpoc_nexus" {
  provider = google

  name      = "${var.project_name}-firewall01-pscpoc-nexus"
  network   = google_compute_network.vpc01_pscpoc.self_link
  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["8081"] # Nexuxを許可
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["pscpoc-nexus"]
}

# Spring Boot実行用のGCEインスタンス
/*
resource "google_compute_instance" "instance01-pscpoc-springboot" {
  provider                 = google

  name      = "${var.project_name}-instance01-spring-boot"
  machine_type = "e2-medium"
  zone         = "asia-northeast1-a"
  boot_disk {
    initialize_params {
      image = "rocky-linux-cloud/rocky-linux-9"
    }
  }
  tags = ["pscpoc-base", "pscpoc-springboot"]
  network_interface {
    network   = google_compute_network.vpc01_pscpoc.self_link
    subnetwork = google_compute_subnetwork.subnet01_pscpoc.self_link
    access_config {
    }
  }
  scheduling {
    # 料金を抑えるためにプリエンプティブルにしておく
    preemptible = true
    # プリエンプティブルの場合は下のオプションが必須
    automatic_restart = false
  }
  metadata_startup_script = file("./spring-boot-init.sh")
}
*/


# Nexusサーバ用のGCEインスタンス
resource "google_compute_instance" "instance01-pscpoc-nexus-proxy" {
  provider = google

  name         = "${var.project_name}-instance01-pscpoc-nexus-proxy"
  machine_type = "e2-medium"
  zone         = "asia-northeast1-a"
  boot_disk {
    initialize_params {
      image = "rocky-linux-cloud/rocky-linux-9"
    }
  }
  tags = ["pscpoc-base", "pscpoc-nexus-proxy"]
  network_interface {
    network    = google_compute_network.vpc01_pscpoc.self_link
    subnetwork = google_compute_subnetwork.subnet01_pscpoc.self_link
    access_config {
    }
  }
  scheduling {
    # 料金を抑えるためにプリエンプティブルにしておく
    preemptible = true
    # プリエンプティブルの場合は下のオプションが必須
    automatic_restart = false
  }
  metadata_startup_script = file("./nexus-init.sh")
}

/*
resource "google_compute_global_address" "private_ip01_pscpoc" {
  provider      = google
  name          = "private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = "10.39.0.0"
  prefix_length = 16
  network       = google_compute_network.vpc01_pscpoc.id
}
resource "google_service_networking_connection" "service_nw_conn01_pscpoc" {
  provider                = google
  network                 = google_compute_network.vpc01_pscpoc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip01_pscpoc.name]
}
*/
