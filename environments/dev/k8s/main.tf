# network

module "gke" {
  source = "../../../modules/gke"

  project_id   = var.project_id
  project_name = var.project_name

  /* GKEの書くサブネット範囲（CIDR）の制限は下記の通り */
  // 特にPod/ServiceのCIDRは、そのセカンダリIP範囲をGKEが管理するか、ユーザが管理するかによって
  // 最小範囲ののCIDRが変わるので注意
  // https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips?hl=ja#range_management

  gke_master_ip_cidr   = "192.168.16.0/28"
  gke_pods_ip_cidr     = "192.168.32.0/20"
  gke_services_ip_cidr = "192.168.48.0/20"

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

// google_project_iam_member.sa_build_project_iam にてPJレベルで
// artifact registryに対して管理者権限を付与済
/*
resource "google_artifact_registry_repository_iam_member" "terraform-image-iam" {
  project    = var.cicd_project_id
  location   = google_artifact_registry_repository.image_repo.location
  repository = google_artifact_registry_repository.image_repo.name
  role       = "roles/artifactregistry.admin"
  member     = "serviceAccount:181997179469@cloudbuild.gserviceaccount.com"
}
*/


// Create the GitHub connection
resource "google_cloudbuildv2_connection" "conn-github" {
  project  = var.cicd_project_id
  location = "asia-northeast1"
  name     = "${var.cicd_project_name}-conn-github"

  github_config {
    app_installation_id = 40467804
    authorizer_credential {
      oauth_token_secret_version = "projects/181997179469/secrets/paloma-cicd-secret-github/versions/2"
    }
  }
}

resource "google_cloudbuildv2_repository" "repo-github" {
  project           = var.cicd_project_id
  location          = "asia-northeast1"
  name              = "paloma-cicd-gitops-gke"
  parent_connection = google_cloudbuildv2_connection.conn-github.name
  remote_uri        = "https://github.com/paloma810/paloma-cicd-gitops-gke.git"
}

# Cloud Build
resource "google_cloudbuild_trigger" "gke_app_build_trigger" {
  project  = var.cicd_project_id
  name     = "${var.cicd_project_name}-trigger-k8s"
  location = "asia-northeast1"
  repository_event_config {
    repository = google_cloudbuildv2_repository.repo-github.id
    push {
      branch = ".*"
    }
  }

  filename = "cloudbuild.yaml"
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