terraform {

  backend "gcs" {
    bucket = "paloma-cicd-tfstate"
    prefix = "components/gc/k8s"
  }
  /*  
  backend "local" {
    path = "terraform.tfstate"
  }
  */
}
