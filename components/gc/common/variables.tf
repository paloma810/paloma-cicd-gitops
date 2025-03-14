/* GCP用変数 */
/*
variable "gcp_credential_filename" {
  type    = string
  default = "./gcp_credentioal.json"
}
*/
variable "gcp_project_hub" {
  type    = string
  default = "kh-paloma-m01-01"
}
variable "gcp_project_spoke" {
  type    = string
  default = "kh-paloma-m01-02"
}
variable "is_create_gcp_instance" {
  type    = number
  default = 0
}
