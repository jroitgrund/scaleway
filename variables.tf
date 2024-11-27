variable "scaleway_access_key" {
  type = string
}

variable "scaleway_secret_key" {
  type = string
}

variable "scw_organization_id" {
  type = string
}

variable "scw_project_id" {
  type = string
}


variable "scw_zone" {
  type    = string
  default = "fr-par-1"
}

variable "scw_region" {
  type    = string
  default = "fr-par"
}
