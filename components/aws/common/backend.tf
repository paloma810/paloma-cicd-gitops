terraform {

  backend "gcs" {
    bucket = "paloma-cicd-tfstate"
    prefix = "components/aws/common"
  }
  /*  
  backend "local" {
    path = "terraform.tfstate"
  }
  */
}
