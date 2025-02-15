terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
  }
  required_version = ">= 1.3.0"
}

/* Googleの認証はサービスアカウントキーではなく
   gcloud auth application-default loginで実施する */
provider "google" {
  #credentials   = file(var.gcp_credential_filename)
  project = var.project_id
  region  = "asia-northeast1"
  zone    = "asia-northeast1-a"
}

