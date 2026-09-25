provider "geoserver" {
  url      = "${var.geoserver_url}/rest"
  gwc_url  = "${var.geoserver_url}/gwc/rest"
  username = "admin"
  password = var.geoserver_admin_password
}

provider "restapi" {
  uri                  = "${var.geoserver_url}/rest"
  username             = "admin"
  password             = var.geoserver_admin_password
  write_returns_object = false
  headers = {
    Content-Type = "application/json"
    Accept       = "application/json"
  }
}
