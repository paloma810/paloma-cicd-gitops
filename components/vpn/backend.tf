terraform {

  backend "gcs" {
    bucket = "paloma-cicd-tfstate"
    prefix = "components/vpn"
  }
  /*  
  backend "local" {
    path = "terraform.tfstate"
  }
  */
}
