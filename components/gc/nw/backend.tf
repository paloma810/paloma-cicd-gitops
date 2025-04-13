terraform {

  backend "gcs" {
    bucket = "paloma-cicd-tfstate"
    prefix = "components/gc/nw"
  }
  /*  
  backend "local" {
    path = "terraform.tfstate"
  }
  */
}
