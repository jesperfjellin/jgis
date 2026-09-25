#!/bin/sh
# Applies the GeoServer catalog. Run by the "bootstrap" Compose service.
set -eu
cd /terraform
# The committed .terraform.lock.hcl pins provider checksums; never rewrite it here.
terraform init -input=false -lockfile=readonly -backend-config="path=/state/terraform.tfstate"
terraform apply -input=false -auto-approve
