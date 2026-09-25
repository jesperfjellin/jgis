locals {
  # Published layers: name => title. The name is also the table name in the
  # "osm" schema and the style file name in ./styles.
  layers = {
    landcover  = "Land cover"
    water      = "Water areas"
    waterways  = "Waterways"
    roads      = "Roads"
    railways   = "Railways"
    buildings  = "Buildings"
    boundaries = "Administrative boundaries"
    places     = "Places"
    pois       = "Points of interest"
  }

  featuretypes_path = "/workspaces/${geoserver_workspace.osm.name}/datastores/${geoserver_datastore.osm.name}/featuretypes"
}

resource "geoserver_style" "layer" {
  for_each = local.layers

  workspace_name   = geoserver_workspace.osm.name
  name             = each.key
  filename         = "${each.key}.sld"
  format           = "sld"
  version          = "1.0.0"
  style_definition = file("${path.module}/styles/${each.key}.sld")
}

# Created through the REST API directly so GeoServer computes the bounding boxes
# from the data (the geoserver provider always sends explicit ones).
resource "restapi_object" "featuretype" {
  for_each = local.layers

  path                    = local.featuretypes_path
  object_id               = each.key
  destroy_path            = "${local.featuretypes_path}/{id}?recurse=true"
  ignore_server_additions = true

  data = jsonencode({
    featureType = {
      name             = each.key
      nativeName       = each.key
      title            = each.value
      srs              = "EPSG:3857"
      projectionPolicy = "FORCE_DECLARED"
      enabled          = true
    }
  })
}

# The layer object is created by GeoServer together with the feature type;
# this only sets its default style. Destroying resets it to the generic style.
resource "restapi_object" "layer_style" {
  for_each = local.layers

  path                    = "/layers"
  object_id               = "${geoserver_workspace.osm.name}:${each.key}"
  create_method           = "PUT"
  create_path             = "/layers/{id}"
  destroy_method          = "PUT"
  ignore_server_additions = true

  data = jsonencode({
    layer = {
      defaultStyle = { name = "${geoserver_workspace.osm.name}:${geoserver_style.layer[each.key].name}" }
    }
  })
  destroy_data = jsonencode({
    layer = { defaultStyle = { name = "generic" } }
  })

  depends_on = [restapi_object.featuretype]
}
