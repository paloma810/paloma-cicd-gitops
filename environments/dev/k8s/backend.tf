terraform {

  backend "gcs" {
    bucket = "paloma-cicd-tfstate"
    prefix = "env/dev/k8s"
  }
  /*  
  backend "local" {
    path = "terraform.tfstate"
  }
  */
}
