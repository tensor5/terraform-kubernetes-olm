#!/usr/bin/env bash

set -eo pipefail

version=$1

url="https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v$version/crds.yaml"

echo "Generating CRDs for OLM v$version..."

curl -L --no-progress-meter "$url" | tfk8s -o crds.tf --strip

echo "Formatting..."
terraform fmt -list=false

echo "locals {
  olm_version = \"$version\"
}" > olm-version.tf
