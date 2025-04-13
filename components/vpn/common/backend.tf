terraform {

  backend "gcs" {
    bucket = "paloma-cicd-tfstate"
    prefix = "components/vpn/common"
  }
  /*  
  backend "local" {
    path = "terraform.tfstate"
  }
  */
}
