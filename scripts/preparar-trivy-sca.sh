#!/usr/bin/env bash
set -euo pipefail
source_dir="devops-tp12/app/backend"
output_dir=".trivy-sca"
test -s "$source_dir/requirements.txt"
test -s "$source_dir/requirements-dev.txt"
mkdir -p "$output_dir"
{
  cat "$source_dir/requirements.txt"
  sed -E '/^[[:space:]]*(-r|--requirement)[[:space:]]/d; /^[[:space:]]*#/d; /^[[:space:]]*$/d' "$source_dir/requirements-dev.txt"
} > "$output_dir/requirements.txt"
echo "Inventario SCA combinado: requirements.txt + requirements-dev.txt -> $output_dir/requirements.txt"
