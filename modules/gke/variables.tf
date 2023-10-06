variable "project_id" {
  description = "Project ID"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Project Name"
  type        = string
  default     = ""
}

variable "gke_master_ip_cidr" {
  description = "GKE Master IP CIDR"
  type        = string
  default     = "192.168.100.0/28"
}

variable "gke_pods_ip_cidr" {
  description = "GKE allocated IP CIDR for Pods"
  type        = string
  default     = "192.168.101.0/24"
}

variable "gke_services_ip_cidr" {
  description = "GKE allocated IP CIDR for Services"
  type        = string
  default     = "192.168.102.0/24"
}
