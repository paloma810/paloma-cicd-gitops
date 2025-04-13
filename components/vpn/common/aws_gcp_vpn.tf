########################
## GCP AWSとのVPN構成 ##
########################

################
# AWS リソース #
################

# AWS VPC IDの参照
data "terraform_remote_state" "aws_common" {
  backend = "gcs"
  config = {
    bucket = "paloma-cicd-tfstate"      # 参照する GCS を指定
    prefix = var.remotestate_aws_prefix # 参照する Terraform が指定している prefix
  }
}

# 仮想プライベートゲートウェイの設定
resource "aws_vpn_gateway" "paloma-dv-vpc01-vgw01" {
  count           = var.is_create_vpn
  vpc_id          = data.terraform_remote_state.aws_common.outputs.vpc_id
  amazon_side_asn = 65512

  tags = {
    Name = "${var.aws_resname_prefix}-vpc01-vgw01"
  }
}

# 仮想プライベートゲートウェイのルート伝播の設定(publicルート)
resource "aws_vpn_gateway_route_propagation" "paloma-dv-pub-rt01-vpn-propagation" {
  count = var.is_create_vpn

  vpn_gateway_id = aws_vpn_gateway.paloma-dv-vpc01-vgw01[0].id
  route_table_id = data.terraform_remote_state.aws_common.outputs.pub_rt01_id
}


# 仮想プライベートゲートウェイのルート伝播の設定(privateルート)
resource "aws_vpn_gateway_route_propagation" "paloma-dv-pri-rt01-vpn-propagation" {
  count = var.is_create_vpn

  vpn_gateway_id = aws_vpn_gateway.paloma-dv-vpc01-vgw01[0].id
  route_table_id = data.terraform_remote_state.aws_common.outputs.pri_rt01_id
}

# 1つ目のカスタマーゲートウェイの設定
resource "aws_customer_gateway" "paloma-dv-vpc01-cgw01" {
  count = var.is_create_vpn

  bgp_asn    = 65513
  ip_address = google_compute_ha_vpn_gateway.hub_vpc_havpn_gw[0].vpn_interfaces[0].ip_address
  type       = "ipsec.1"

  tags = {
    Name = "${var.aws_resname_prefix}-vpc01-cgw01"
  }
}

# 1つ目のSite-to-Site VPN接続の設定
resource "aws_vpn_connection" "paloma-dv-vpc01-vpn01" {
  count = var.is_create_vpn

  vpn_gateway_id      = aws_vpn_gateway.paloma-dv-vpc01-vgw01[0].id
  customer_gateway_id = aws_customer_gateway.paloma-dv-vpc01-cgw01[0].id
  type                = "ipsec.1"

  tags = {
    Name = "${var.aws_resname_prefix}-vpc01-vpn01"
  }
}

################
# GCP リソース #
################

# GCP VPC IDの参照
data "terraform_remote_state" "gc_common" {
  backend = "gcs"
  config = {
    bucket = "paloma-cicd-tfstate"     # 参照する GCS を指定
    prefix = var.remotestate_gc_prefix # 参照する Terraform が指定している prefix
  }
}

# HA VPNの設定
resource "google_compute_ha_vpn_gateway" "hub_vpc_havpn_gw" {
  count    = var.is_create_vpn
  provider = google

  name    = "${var.gcp_project_hub}-havpn-gw01"
  network = data.terraform_remote_state.gc_common.outputs.hub_vpc_self_link
}

# Cloud Routerの設定
resource "google_compute_router" "cmk_cloud_router" {
  count    = var.is_create_vpn
  provider = google

  name    = "${var.gcp_project_hub}-router01"
  network = data.terraform_remote_state.gc_common.outputs.hub_vpc_self_link
  bgp {
    asn = 65513
  }
}

# External VPN GWの設定
resource "google_compute_external_vpn_gateway" "hub_vpc_extvpn_gw" {
  count    = var.is_create_vpn
  provider = google

  name            = "${var.gcp_project_hub}-externalvpn-gw01"
  redundancy_type = "SINGLE_IP_INTERNALLY_REDUNDANT"
  description     = "Single IP for AWS VPN"

  interface {
    id         = 0
    ip_address = aws_vpn_connection.paloma-dv-vpc01-vpn01[0].tunnel1_address
  }
}

# VPNトンネル1の設定
## VPNトンネルの接続設定(トンネル1用)
resource "google_compute_vpn_tunnel" "hub_vpc_havpn_tunnel01" {
  count    = var.is_create_vpn
  provider = google

  name                            = "${var.gcp_project_hub}-havpn-tunnel01"
  shared_secret                   = aws_vpn_connection.paloma-dv-vpc01-vpn01[0].tunnel1_preshared_key
  vpn_gateway                     = google_compute_ha_vpn_gateway.hub_vpc_havpn_gw[0].self_link
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.hub_vpc_extvpn_gw[0].self_link
  peer_external_gateway_interface = 0
  router                          = google_compute_router.cmk_cloud_router[0].name
  ike_version                     = 1
}

# Cloud Routerインターフェースの設定(トンネル1用)
resource "google_compute_router_interface" "hub_vpc_router_interface01" {
  count    = var.is_create_vpn
  provider = google

  name       = "${var.gcp_project_hub}-router01-interface01"
  router     = google_compute_router.cmk_cloud_router[0].name
  ip_range   = "${aws_vpn_connection.paloma-dv-vpc01-vpn01[0].tunnel1_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.hub_vpc_havpn_tunnel01[0].name
}

# BGPピアリング用のBGP情報の設定(トンネル1用)
resource "google_compute_router_peer" "hub_vpc_router_peer01" {
  count    = var.is_create_vpn
  provider = google

  name            = "${var.gcp_project_hub}-router01-peer01"
  router          = google_compute_router.cmk_cloud_router[0].name
  peer_ip_address = aws_vpn_connection.paloma-dv-vpc01-vpn01[0].tunnel1_vgw_inside_address
  peer_asn        = aws_vpn_connection.paloma-dv-vpc01-vpn01[0].tunnel1_bgp_asn
  interface       = google_compute_router_interface.hub_vpc_router_interface01[0].name
}
