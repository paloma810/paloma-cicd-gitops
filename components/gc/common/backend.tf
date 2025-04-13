terraform {

  backend "gcs" {
    bucket = "paloma-cicd-tfstate"
    prefix = "components/gc/common"
  }
  /*  
  backend "local" {
    path = "terraform.tfstate"
  }
  */
}
