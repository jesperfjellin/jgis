terraform {
  required_version = ">= 1.10"

  # State location is supplied at init time (see bootstrap.sh).
  backend "local" {}

  required_providers {
    geoserver = {
      source  = "camptocamp/geoserver"
      version = "0.0.30"
    }
    # Covers GeoServer REST endpoints the geoserver provider does not handle well:
    # feature types (so GeoServer computes bounding boxes) and layer default styles.
    restapi = {
      source  = "Mastercard/restapi"
      version = "3.0.0"
    }
  }
}
