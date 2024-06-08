# VPCネットワーク設定
resource "google_compute_network" "vpc01_nwtest" {
  provider                        = google
  name                            = "${var.project_name}-vpc01-nwtest"
  description                     = "This is a VPC for NW Test"
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  mtu                             = 1460
  delete_default_routes_on_create = false
}

# サブネット設定
resource "google_compute_subnetwork" "subnet01_nwtest" {
  provider                 = google
  name                     = "${var.project_name}-subnet01-nwtest"
  description              = "This is a Subnet on Spoke VPC"
  network                  = google_compute_network.vpc01_nwtest.self_link
  ip_cidr_range            = "10.37.0.0/16"
  private_ip_google_access = true
}

# Serverless VPC Access Connector設定
resource "google_vpc_access_connector" "svac01_nwtest" {
  provider      = google
  name          = replace("${var.project_name}svac01nwtest", "-", "")
  ip_cidr_range = "10.38.0.0/28"
  network       = google_compute_network.vpc01_nwtest.id
}

# テスト用踏み台GCEインスタンスは手動で作成するため一旦対象外


# Cloud SQLインスタンス設定
resource "google_sql_database_instance" "db01_nwtest" {
  provider         = google
  name             = "${var.project_name}-db01-nwtest"
  region           = "asia-northeast1"
  database_version = "POSTGRES_14"

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      private_network = google_compute_network.vpc01_nwtest.id
      ipv4_enabled    = false
    }
  }
}

resource "google_sql_user" "db01_nwtest_user" {
  provider = google

  name     = "test"
  instance = google_sql_database_instance.db01_nwtest.name
  password = "testtest"
}

resource "google_sql_database" "db01_nwtest_db" {
  provider = google

  name     = "maindb"
  instance = google_sql_database_instance.db01_nwtest.name
}

resource "google_compute_global_address" "private_ip01_nwtest" {
  provider      = google
  name          = "private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = "10.39.0.0"
  prefix_length = 16
  network       = google_compute_network.vpc01_nwtest.id
}
resource "google_service_networking_connection" "service_nw_conn01_nwtest" {
  provider                = google
  network                 = google_compute_network.vpc01_nwtest.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip01_nwtest.name]
}
