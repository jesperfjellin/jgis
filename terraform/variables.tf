variable "geoserver_url" {
  type        = string
  description = "GeoServer base URL, without a trailing slash."
  default     = "http://geoserver:8080/geoserver"
}

variable "geoserver_admin_password" {
  type      = string
  sensitive = true
}

variable "db_host" {
  type    = string
  default = "postgis"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Password for the read-only 'geoserver' database role."
}
