provider "scaleway" {
  access_key      = var.scaleway_access_key
  secret_key      = var.scaleway_secret_key
  region          = var.scw_region
  zone            = var.scw_zone
  organization_id = var.scw_organization_id
  project_id      = var.scw_project_id
}

terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
  required_version = ">= 0.13"

  backend "s3" {
    region = "fr-par"
    bucket = "jr-tf-state"
    key    = "terraform.tfstate"
    endpoints = {
      s3 = "https://s3.fr-par.scw.cloud"
    }
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_credentials_validation = true
    skip_region_validation      = true
  }
}

resource "random_password" "postgres_password" {
  length           = 128
  special          = true
  override_special = "-"
}

resource "scaleway_rdb_instance" "postgres" {
  engine        = "PostgreSQL-15"
  node_type     = "DB-DEV-S"
  user_name     = "admin"
  name          = "postgres"
  password      = random_password.postgres_password.result
  is_ha_cluster = false
}

resource "scaleway_container_namespace" "mattermost" {
  name = "mattermost-namespace"
}

resource "scaleway_object_bucket" "mattermost_bucket" {
  name = "jr-mattermost-bucket"

  region = var.scw_region
}

resource "scaleway_object_bucket_acl" "mattermost_bucket_acl" {
  bucket = scaleway_object_bucket.mattermost_bucket.id
  acl    = "private"
}

resource "scaleway_tem_domain" "tem" {
  accept_tos = true
  name       = "mail.loopcollectif.info"
}

resource "scaleway_tem_domain_validation" "tem_validation" {
  domain_id = scaleway_tem_domain.tem.id
  timeout   = 300
}

output "domain_validated" {
  value = scaleway_tem_domain_validation.tem_validation.validated
}

resource "scaleway_container" "mattermost" {
  namespace_id   = scaleway_container_namespace.mattermost.id
  name           = "mattermost"
  min_scale      = 1
  max_scale      = 1
  memory_limit   = 1024
  cpu_limit      = 256
  registry_image = "mattermost/mattermost-team-edition:latest"
  http_option    = "redirected"
  port           = 8065
  deploy         = true
  environment_variables = {
    "MM_SERVICESETTINGS_LISTENADDRESS"        = ":8065"
    "MM_SQLSETTINGS_DRIVERNAME"               = "postgres"
    "MM_SQLSETTINGS_DATASOURCE"               = "postgres://${scaleway_rdb_instance.postgres.user_name}:${scaleway_rdb_instance.postgres.password}@${scaleway_rdb_instance.postgres.load_balancer[0].ip}:${scaleway_rdb_instance.postgres.load_balancer[0].port}/rdb"
    "MM_FILESETTINGS_DRIVERNAME"              = "amazons3"
    "MM_FILESETTINGS_AMAZONS3BUCKET"          = scaleway_object_bucket.mattermost_bucket.name
    "MM_FILESETTINGS_AMAZONS3ENDPOINT"        = "s3.fr-par.scw.cloud"
    "MM_FILESETTINGS_AMAZONS3PATHPREFIX"      = "mattermost"
    "MM_FILESETTINGS_AMAZONS3REGION"          = var.scw_region
    "MM_FILESETTINGS_AMAZONS3ACCESSKEYID"     = var.scaleway_access_key
    "MM_FILESETTINGS_AMAZONS3SECRETACCESSKEY" = var.scaleway_secret_key
    "MM_SERVICESETTINGS_SITEURL"              = "https://chat.loopcollectif.info"
    "MM_EMAILSETTINGS_SMTPSERVER"             = scaleway_tem_domain.tem.smtp_host
    "MM_EMAILSETTINGS_SMTPPORT"               = scaleway_tem_domain.tem.smtp_port
    "MM_EMAILSETTINGS_CONNECTIONSECURITY"     = "STARTTLS"
    "MM_EMAILSETTINGS_ENABLESMTPAUTH"         = true
    "MM_EMAILSETTINGS_SMTPUSERNAME"           = scaleway_tem_domain.tem.smtps_auth_user
    "MM_EMAILSETTINGS_SMTPPASSWORD"           = var.scaleway_secret_key
  }
}

resource "scaleway_container_domain" "mattermost_domain" {
  container_id = scaleway_container.mattermost.id
  hostname     = "chat.loopcollectif.info"
}
