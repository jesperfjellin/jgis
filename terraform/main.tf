resource "geoserver_workspace" "osm" {
  name = "osm"
}

resource "geoserver_datastore" "osm" {
  workspace_name = geoserver_workspace.osm.name
  name           = "osm"
  enabled        = true

  connection_params = {
    dbtype   = "postgis"
    host     = var.db_host
    port     = "5432"
    database = "gis"
    schema   = "osm"
    user     = "geoserver"
    passwd   = var.db_password

    "min connections"                            = "4"
    "max connections"                            = "20"
    "validate connections"                       = "true"
    "fetch size"                                 = "1000"
    "preparedStatements"                         = "true"
    "Max open prepared statements"               = "50"
    "Expose primary keys"                        = "false"
    "Estimated extends"                          = "true"
    "Loose bbox"                                 = "true"
    "encode functions"                           = "true"
    "Support on the fly geometry simplification" = "true"
  }

  lifecycle {
    # GeoServer returns the password encrypted, so it always differs from the
    # configured value. To change it, taint or recreate the datastore.
    ignore_changes = [connection_params["passwd"]]
  }
}
