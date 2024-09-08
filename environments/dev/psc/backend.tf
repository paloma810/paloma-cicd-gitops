terraform {

  backend "gcs" {
    bucket = "paloma-cicd-tfstate"
    prefix = "env/dev/psc"
  }
  /*  
  backend "local" {
    path = "terraform.tfstate"
  }
  */
}
