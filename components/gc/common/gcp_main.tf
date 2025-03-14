################################
## GCP Hub-spoke VPC構成の作成 ##
################################
# 1. VPCの作成
resource "google_compute_network" "hub_vpc" {
  provider = google

  name                            = "${var.gcp_project_hub}-hubvpc01"
  description                     = "This is a Hub VPC"
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  mtu                             = 1460
  delete_default_routes_on_create = true
}

resource "google_compute_network" "spoke_vpc" {
  provider = google.spoke

  name                            = "${var.gcp_project_spoke}-spokevpc01"
  description                     = "This is a Spoke VPC"
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  mtu                             = 1460
  delete_default_routes_on_create = true
}

# 2. Subnetの作成
resource "google_compute_subnetwork" "hub_vpc_subnet01" {
  provider = google

  name                     = "${var.gcp_project_hub}-hubvpc01-subnet01"
  description              = "This is a Subnet on Hub VPC"
  network                  = google_compute_network.hub_vpc.self_link
  ip_cidr_range            = "10.1.0.0/24"
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "spoke_vpc_subnet01" {
  provider = google.spoke

  name                     = "${var.gcp_project_spoke}-spokevpc01-subnet01"
  description              = "This is a Subnet on Spoke VPC"
  network                  = google_compute_network.spoke_vpc.self_link
  ip_cidr_range            = "10.2.0.0/24"
  private_ip_google_access = true
}

# 2. Routeの作成
resource "google_compute_route" "hub_vpc_internet_route" {
  provider         = google
  name             = "${var.gcp_project_spoke}-hubvpc01-rt-internet"
  network          = google_compute_network.hub_vpc.self_link
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

#3. Firewall Ruleの作成
resource "google_compute_firewall" "hub_firewall_ingress_ssh" {
  provider = google

  name      = "${var.gcp_project_hub}-hubvpc01-firewall01"
  network   = google_compute_network.hub_vpc.self_link
  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["22", "3389"] # SSHのみを許可
  }
  allow {
    protocol = "icmp" # ICMPを許可
  }
  source_ranges = ["10.11.0.0/24", "10.2.0.0/24", "60.138.39.189/32"] # AWS VPC / Spoke VPCからの通信を許可
  target_tags   = ["local-traffic"]
}

resource "google_compute_firewall" "spoke_firewall" {
  provider = google.spoke

  name      = "${var.gcp_project_spoke}-spokevpc01-firewall01"
  network   = google_compute_network.spoke_vpc.self_link
  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["22", "3389"] # SSHのみを許可
  }
  allow {
    protocol = "icmp" # ICMPを許可
  }
  source_ranges = ["10.1.0.0/24"] # Hub VPCからの通信を許可
  target_tags   = ["local-traffic"]
}

# GCEインスタンス用サービスアカウント作成
resource "google_service_account" "sa_gce" {
  project      = var.gcp_project_hub
  account_id   = "${var.gcp_project_hub}-sa-gce"
  display_name = "GCE Service Account"
}

# GCE用サービスアカウントにOpsAgent向けの権限を付与
resource "google_project_iam_member" "iam_policy_for_sa_gce01" {
  project = var.gcp_project_hub
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.sa_gce.email}"
}

resource "google_project_iam_member" "iam_policy_for_sa_gce02" {
  project = var.gcp_project_hub
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.sa_gce.email}"
}


# 4. （オプション）GCEインスタンスの作成
resource "google_compute_instance" "hub_vpc_instance01" {
  count    = var.is_create_gcp_instance
  provider = google

  name         = "${var.gcp_project_hub}-gce-instance01"
  machine_type = "e2-micro"
  boot_disk {
    auto_delete = false
    source      = google_compute_disk.hub_vpc_instance01_disk.self_link
  }
  metadata = {
    enable-oslogin : "TRUE",
    enable-osconfig : "TRUE",
    serial-port-enable : "TRUE"
  }
  tags = ["local-traffic"]
  network_interface {
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = google_compute_subnetwork.hub_vpc_subnet01.self_link
    # External IPの設定。Private IPのみにする場合、以下は省略する
    access_config {
    }
  }
  scheduling {
    # 料金を抑えるためにプリエンプティブルにしておく
    preemptible = true
    # プリエンプティブルの場合は下のオプションが必須
    automatic_restart = false
  }

  service_account {
    email  = google_service_account.sa_gce.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = <<EOF
#!/bin/bash
# allocate swap memory due to OOM during dnf update
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab

# dnf update
sudo dnf update

# install ops agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install
EOF

}

# HUB VPCインスタンス向けのディスクを定義 
resource "google_compute_disk" "hub_vpc_instance01_disk" {
  provider = google
  name     = "${var.gcp_project_hub}-gce-instance01-disk01"
  //image = "debian-cloud/debian-11"
  image = "rhel-cloud/rhel-8"
  size  = 20
}

# OS Policy
module "agent_policy" {
  source     = "terraform-google-modules/cloud-operations/google//modules/agent-policy"
  version    = "~> 0.2.3"
  project_id = var.gcp_project_hub
  policy_id  = "ops-agents-policy"
  agent_rules = [
    {
      type               = "logging"
      version            = "current-major"
      package_state      = "installed"
      enable_autoupgrade = true
    },
    {
      type               = "metrics"
      version            = "current-major"
      package_state      = "installed"
      enable_autoupgrade = true
    },
  ]
  group_labels = [
    {
      env = "dev"
    }
  ]
  os_types = [
    {
      short_name = "rhel"
      version    = "8"
    },
  ]
}


# Windows RDPテスト用サーバ
resource "google_compute_instance" "hub_vpc_win_instance01" {
  #count    = var.is_create_gcp_instance
  count    = 0
  provider = google

  name         = "${var.gcp_project_hub}-gce-win-instance01"
  machine_type = "e2-standard-2"
  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2022"
    }
  }
  tags = ["local-traffic"]
  network_interface {
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = google_compute_subnetwork.hub_vpc_subnet01.self_link
    # External IPの設定。Private IPのみにする場合、以下は省略する
    #access_config {
    #}
  }
  scheduling {
    # 料金を抑えるためにプリエンプティブルにしておく
    preemptible = true
    # プリエンプティブルの場合は下のオプションが必須
    automatic_restart = false
  }
}

resource "google_compute_instance" "spoke_vpc_instance01" {
  #count    = var.is_create_gcp_instance
  count    = 0
  provider = google.spoke

  name         = "${var.gcp_project_spoke}-gce-instance01"
  machine_type = "e2-micro"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }
  tags = ["local-traffic"]
  network_interface {
    network    = google_compute_network.spoke_vpc.self_link
    subnetwork = google_compute_subnetwork.spoke_vpc_subnet01.self_link
    # External IPの設定。Private IPのみにする場合、以下は省略する
    #access_config {
    #}
  }
  scheduling {
    # 料金を抑えるためにプリエンプティブルにしておく
    preemptible = true
    # プリエンプティブルの場合は下のオプションが必須
    automatic_restart = false
  }
}

# 5. VPC Peeringの作成
resource "google_compute_network_peering" "hub_vpc_peering_to_spoke" {
  provider = google

  name         = "${var.gcp_project_hub}-vpcpeering-to-${var.gcp_project_spoke}"
  network      = google_compute_network.hub_vpc.self_link
  peer_network = google_compute_network.spoke_vpc.self_link
}

resource "google_compute_network_peering" "spoke_vpc_peering_to_hub" {
  provider = google.spoke

  name         = "${var.gcp_project_spoke}-vpcpeering-to-${var.gcp_project_hub}"
  network      = google_compute_network.spoke_vpc.self_link
  peer_network = google_compute_network.hub_vpc.self_link
}

# 6. Routeの作成
/*
locals {
  hub_vpc_route_to_spoke_name = "${var.gcp_project_hub}-vpcpeering-to-${var.gcp_project_spoke}"
  spoke_vpc_route_to_hub_name = "${var.gcp_project_spoke}-vpcpeering-to-${var.gcp_project_hub}"
}

resource "google_compute_route" "hub_vpc_route_to_hub" {
  provider = google

  name               = "${local.hub_vpc_route_to_spoke_name}"
  network            = google_compute_network.hub_vpc.self_link
  dest_range         = google_compute_network.spoke_vpc.self_link
  next_hop_peering   = google_compute_network_peering.hub_spoke_peering.name
  priority           = 1000
}

resource "google_compute_route" "spoke_vpc_route_to_hub" {
  provider = google.spoke

  name               = "${local.spoke_vpc_route_to_hub_name}"
  network            = google_compute_network.spoke_vpc.self_link
  dest_range         = google_compute_network.hub_vpc.self_link
  next_hop_peering   = google_compute_network_peering.hub_spoke_peering.name
  priority           = 1000
}
*/

# 7. IPアドレスとPSC Endpointの作成
# 　 ※ 現時点のTerraform仕様だと、ServiceDirectoryのリージョン指定ができず、us-centralでの作成となる
resource "google_compute_global_address" "hub_vpc_private_ip_alloc" {
  count    = var.is_create_gcp_instance
  provider = google

  name         = "${var.gcp_project_hub}siip01"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  address_type = "INTERNAL"
  network      = google_compute_network.hub_vpc.id
  address      = "100.100.111.111"
}

/*
resource "google_service_networking_connection" "hub_vpc_psc_endpoint" {
  network                 = google_compute_network.hub_vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.hub_vpc_private_ip_alloc.name]
}
*/

resource "google_compute_global_forwarding_rule" "forwarding_rule_private_service_connect" {
  count    = var.is_create_gcp_instance
  provider = google

  name                  = replace("${var.gcp_project_hub}fwd01", "-", "")
  target                = "vpc-sc"
  network               = google_compute_network.hub_vpc.self_link
  ip_address            = google_compute_global_address.hub_vpc_private_ip_alloc[0].id
  load_balancing_scheme = ""
}

