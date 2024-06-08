terraform {

  backend "gcs" {
    bucket = "paloma-cicd-tfstate"
    prefix = "env/dev/nw"
  }
  /*  
  backend "local" {
    path = "terraform.tfstate"
  }
  */
}
