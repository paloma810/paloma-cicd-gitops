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

# GKE サービスアカウントへの権限付与
resource "google_project_iam_member" "sa_gke_cluster_iam_policy" {
  project = var.cicd_project_id
  role    = "roles/artifactregistry.reader" # 最小権限の法則のもと、一旦Artifact Registry の読み取り権限のみ付与
  member  = "serviceAccount:${module.gke.sa_gke_cluster_email}"
}

# gke用 Artifact Registryリポジトリ
resource "google_artifact_registry_repository" "image_repo" {
  project       = var.cicd_project_id
  location      = "asia-northeast1"
  repository_id = format("%s-%s", var.cicd_project_name, "repo-gke")
  description   = "Docker repository for GKE application images"
  format        = "DOCKER"
}

resource "google_artifact_registry_repository_iam_member" "terraform-image-iam" {
  project    = var.cicd_project_id
  location   = google_artifact_registry_repository.image_repo.location
  repository = google_artifact_registry_repository.image_repo.name
  role       = "roles/artifactregistry.admin"
  member     = "serviceAccount:181997179469@cloudbuild.gserviceaccount.com"
}

# Cloud Build
resource "google_cloudbuild_trigger" "gke_app_build_trigger" {
  project  = var.cicd_project_id
  name     = "${var.cicd_project_name}-trigger-k8s"
  location = "global"
  github {
    owner = "paoma810"
    name  = "paloma-cicd-gitops-k8s"
    push {
      branch       = ".*"
      invert_regex = false
    }
  }

  filename = ""
}
locals {
  // ref) default value of google cloud module "secure-ci"
  roles_sa_build = [
    "roles/artifactregistry.admin",
    "roles/binaryauthorization.attestorsVerifier",
    "roles/cloudbuild.builds.builder",
    "roles/clouddeploy.developer",
    "roles/clouddeploy.releaser",
    "roles/cloudkms.cryptoOperator",
    "roles/containeranalysis.notes.attacher",
    "roles/containeranalysis.notes.occurrences.viewer",
    "roles/source.writer",
    "roles/storage.admin",
    "roles/cloudbuild.workerPoolUser",
    "roles/ondemandscanning.admin",
    "roles/logging.logWriter"
  ]
}

resource "google_project_iam_member" "sa_build_project_iam" {
  for_each = toset(local.roles_sa_build)
  project  = var.cicd_project_id
  role     = each.value
  member   = "serviceAccount:181997179469@cloudbuild.gserviceaccount.com"
}