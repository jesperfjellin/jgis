# GeoWebCache tile layers. GeoServer auto-creates a tile layer with default
# settings for each new layer; these resources replace those defaults so the
# cache configuration is explicit.
resource "geoserver_gwc_gs_layer" "layer" {
  for_each = local.layers

  name = "${geoserver_workspace.osm.name}:${each.key}"
  # Sorted alphabetically: GeoWebCache returns them sorted, and the provider
  # compares the list in order.
  mime_formats    = ["application/vnd.mapbox-vector-tile", "image/png"]
  metatile_width  = 4
  metatile_height = 4
  gutter_size     = 0

  # Lets browsers cache tiles for an hour. With 0, GeoWebCache sends
  # "Cache-Control: no-cache, no-store" and clients re-fetch every tile.
  expire_duration_clients = 3600

  grid_subset {
    name = "WebMercatorQuad"
  }

  lifecycle {
    # Internal GeoServer ID, read back from the server.
    ignore_changes = [layer_id]
  }

  depends_on = [restapi_object.layer_style]
}
