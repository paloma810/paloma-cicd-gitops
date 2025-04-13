terraform {

  backend "gcs" {
    bucket = "paloma-cicd-tfstate"
    prefix = "components/gc/psc"
  }
  /*  
  backend "local" {
    path = "terraform.tfstate"
  }
  */
}
